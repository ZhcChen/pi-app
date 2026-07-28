import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pi_desktop/pi_core_rpc_client.dart';

const List<String> _codingTools = <String>[
  'read',
  'grep',
  'find',
  'ls',
  'bash',
  'edit',
  'write',
];

Future<void> main(List<String> arguments) async {
  final executable = _parseExecutable(arguments);
  final temporaryProject = await Directory.systemTemp.createTemp(
    'pi-app-direct-rpc-smoke-',
  );
  final client = PiCoreRpcClient(
    environment: executable == null
        ? null
        : <String, String>{'PI_CORE_EXECUTABLE': executable},
  );
  final normalSettled = Completer<void>();
  final toolStarted = Completer<void>();
  final aborted = Completer<void>();
  final textDeltas = <String>[];
  String? normalSessionId;
  String? abortSessionId;
  final subscription = client.events.listen((event) {
    if (event.sessionId == normalSessionId &&
        event.type == PiHostEventType.messageDelta) {
      textDeltas.add(event.delta ?? '');
    }
    if (event.sessionId == normalSessionId &&
        event.type == PiHostEventType.runSettled &&
        !normalSettled.isCompleted) {
      normalSettled.complete();
    }
    if (event.sessionId == abortSessionId &&
        event.type == PiHostEventType.toolStarted &&
        !toolStarted.isCompleted) {
      toolStarted.complete();
    }
    if (event.sessionId == abortSessionId &&
        event.type == PiHostEventType.runAborted &&
        !aborted.isCompleted) {
      aborted.complete();
    }
  });

  try {
    final health = await client.ensureStarted();
    final normalSession = await client.createSession(
      cwd: temporaryProject.path,
      tools: _codingTools,
    );
    normalSessionId = normalSession.id;
    final models = await client.listModels(sessionId: normalSession.id);
    final currentModel = normalSession.model;
    if (currentModel == null ||
        !models.any(
          (model) =>
              model.provider == currentModel.provider &&
              model.id == currentModel.id,
        )) {
      throw StateError('Pi core did not expose the current model.');
    }
    final selectedModel = await client.setModel(
      sessionId: normalSession.id,
      provider: currentModel.provider,
      modelId: currentModel.id,
    );
    final selectedThinking = await client.setThinkingLevel(
      sessionId: normalSession.id,
      level: normalSession.thinkingLevel,
    );
    if (selectedModel.model?.id != currentModel.id ||
        selectedThinking.thinkingLevel != normalSession.thinkingLevel) {
      throw StateError(
        'Pi core did not retain the current model or thinking level.',
      );
    }
    final normalAccepted = await client.prompt(
      sessionId: normalSession.id,
      text:
          'Reply with one short sentence containing the exact token PI_APP_DIRECT_RPC_OK. Do not use tools.',
    );
    if (!normalAccepted) {
      throw StateError('The normal direct RPC prompt was rejected.');
    }
    await normalSettled.future.timeout(const Duration(seconds: 90));
    if (textDeltas.join().isEmpty) {
      throw StateError('The normal direct RPC prompt produced no text delta.');
    }

    final abortSession = await client.createSession(
      cwd: temporaryProject.path,
      tools: _codingTools,
    );
    abortSessionId = abortSession.id;
    final abortAccepted = await client.prompt(
      sessionId: abortSession.id,
      text:
          'Use the bash tool to run exactly `sleep 20`, then wait for the command result before replying.',
    );
    if (!abortAccepted) {
      throw StateError('The abort direct RPC prompt was rejected.');
    }
    await toolStarted.future.timeout(const Duration(seconds: 60));
    await client.abort(sessionId: abortSession.id);
    await aborted.future.timeout(const Duration(seconds: 30));

    stdout.writeln(
      jsonEncode(<String, dynamic>{
        'ok': true,
        'piVersion': health.sdkVersion,
        'normalTextDeltaCount': textDeltas.length,
        'availableModelCount': models.length,
      }),
    );
  } finally {
    await subscription.cancel();
    await client.dispose();
    if (await temporaryProject.exists()) {
      await temporaryProject.delete(recursive: true);
    }
  }
}

String? _parseExecutable(List<String> arguments) {
  if (arguments.isEmpty) {
    return null;
  }
  if (arguments.length == 2 && arguments.first == '--pi') {
    return arguments.last;
  }
  throw ArgumentError(
    'Usage: dart run tool/verify_pi_core_rpc.dart [--pi PATH]',
  );
}
