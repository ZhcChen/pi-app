import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/main.dart';

void main() {
  Future<Process> startNodeRpc(PiCoreRpcLaunchCommand command, String script) {
    return Process.start('node', <String>[
      '--input-type=module',
      '--eval',
      script,
    ], workingDirectory: command.workingDirectory);
  }

  Future<void> expectStartupFailure({
    required String script,
    required Matcher failureMessage,
  }) async {
    final events = <PiHostEvent>[];
    final workingDirectory = await Directory.systemTemp.createTemp(
      'pi-core-rpc-invalid-',
    );
    final client = PiCoreRpcClient(
      readVersion: (_) async => '0.82.0-test',
      startProcess: (command) => startNodeRpc(command, script),
    );
    final subscription = client.events.listen(events.add);

    try {
      await expectLater(
        client.createSession(cwd: workingDirectory.path),
        throwsA(isA<PiHostClientException>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final failure = events.singleWhere(
        (event) => event.type == PiHostEventType.hostError,
      );
      expect(failure.message, failureMessage);
    } finally {
      await subscription.cancel();
      await client.dispose();
      await workingDirectory.delete(recursive: true);
    }
  }

  test(
    'direct Pi RPC maps product events and preserves launch boundaries',
    () async {
      final launches = <PiCoreRpcLaunchCommand>[];
      final events = <PiHostEvent>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-client-',
      );
      final client = PiCoreRpcClient(
        environment: const <String, String>{'PI_CORE_EXECUTABLE': '/mock/pi'},
        extensionCompletionDelay: const Duration(milliseconds: 40),
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) {
          launches.add(command);
          return startNodeRpc(command, _rpcScript());
        },
      );
      final subscription = client.events.listen(events.add);

      try {
        final health = await client.ensureStarted();
        final session = await client.createSession(
          cwd: workingDirectory.path,
          tools: const <String>['read', 'bash'],
        );
        final accepted = await client.prompt(
          sessionId: session.id,
          text: 'Run the direct RPC test.',
        );
        await Future<void>.delayed(const Duration(milliseconds: 80));
        final updated = await client.setThinkingLevel(
          sessionId: session.id,
          level: 'high',
        );
        await client.abort(sessionId: session.id);

        expect(health.sdkVersion, '0.82.0-test');
        expect(accepted, true);
        expect(updated.thinkingLevel, 'medium');
        expect(launches, hasLength(1));
        expect(launches.single.executable, '/mock/pi');
        expect(launches.single.arguments, <String>[
          '--mode',
          'rpc',
          '--no-approve',
          '--tools',
          'read,bash',
        ]);
        expect(
          events.map((event) => event.type),
          containsAll(<PiHostEventType>[
            PiHostEventType.sessionCreated,
            PiHostEventType.runStarted,
            PiHostEventType.messageDelta,
            PiHostEventType.thinkingDelta,
            PiHostEventType.toolStarted,
            PiHostEventType.toolUpdated,
            PiHostEventType.toolCompleted,
            PiHostEventType.runSettled,
            PiHostEventType.runAborted,
          ]),
        );
        expect(
          events
              .where((event) => event.type == PiHostEventType.messageDelta)
              .single
              .delta,
          'RPC text\u2028separator',
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'direct Pi RPC gates and rechecks health for a changed executable',
    () async {
      final launches = <PiCoreRpcLaunchCommand>[];
      final versionRequests = <String>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-runtime-gate-',
      );
      var executable = '/mock/first-pi';
      var gateCount = 0;
      final client = PiCoreRpcClient(
        executableResolver: () => executable,
        runtimeGate: () async {
          gateCount += 1;
        },
        readVersion: (value) async {
          versionRequests.add(value);
          return '0.82.0-test';
        },
        startProcess: (command) {
          launches.add(command);
          return startNodeRpc(command, _rpcScript());
        },
      );

      try {
        await client.ensureStarted();
        executable = '/mock/second-pi';
        await client.createSession(cwd: workingDirectory.path);

        expect(gateCount, 2);
        expect(versionRequests, <String>['/mock/first-pi', '/mock/second-pi']);
        expect(launches.single.executable, '/mock/second-pi');
      } finally {
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test('direct Pi RPC accepts CRLF-delimited responses', () async {
    final workingDirectory = await Directory.systemTemp.createTemp(
      'pi-core-rpc-crlf-',
    );
    final client = PiCoreRpcClient(
      readVersion: (_) async => '0.82.0-test',
      startProcess: (command) => startNodeRpc(command, _rpcScript(crlf: true)),
    );

    try {
      final session = await client.createSession(cwd: workingDirectory.path);
      expect(session.piSessionId, 'pi-direct-session');
    } finally {
      await client.dispose();
      await workingDirectory.delete(recursive: true);
    }
  });

  test(
    'direct Pi RPC ignores an unrelated response before the matching id',
    () async {
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-correlation-',
      );
      final client = PiCoreRpcClient(
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) =>
            startNodeRpc(command, _rpcScript(mismatchedStateResponse: true)),
      );

      try {
        final session = await client.createSession(cwd: workingDirectory.path);
        expect(session.piSessionId, 'pi-direct-session');
      } finally {
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test('direct Pi RPC rejects malformed stdout JSONL', () async {
    await expectStartupFailure(
      script: _rpcScript(malformedOnState: true),
      failureMessage: contains('Invalid Pi core RPC output'),
    );
  });

  test('direct Pi RPC rejects stdout records over 1 MiB', () async {
    await expectStartupFailure(
      script: _rpcScript(oversizedOnState: true),
      failureMessage: contains('larger than 1 MiB'),
    );
  });

  test(
    'direct Pi RPC settles an extension-local prompt without agent events',
    () async {
      final events = <PiHostEvent>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-local-',
      );
      final client = PiCoreRpcClient(
        extensionCompletionDelay: const Duration(milliseconds: 5),
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) =>
            startNodeRpc(command, _rpcScript(localOnly: true)),
      );
      final subscription = client.events.listen(events.add);

      try {
        final session = await client.createSession(cwd: workingDirectory.path);
        final accepted = await client.prompt(
          sessionId: session.id,
          text: '/pi-app-rpc-project-probe',
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(accepted, true);
        expect(
          events.where((event) => event.type == PiHostEventType.runStarted),
          isEmpty,
        );
        final settled = events.singleWhere(
          (event) => event.type == PiHostEventType.runSettled,
        );
        expect(settled.data['handledWithoutRun'], true);
        expect(settled.data['sawExtensionUiRequest'], true);
        expect(
          events.where(
            (event) => event.type == PiHostEventType.extensionUiRequest,
          ),
          hasLength(1),
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'direct Pi RPC cancels unsupported extension dialogs instead of hanging',
    () async {
      final events = <PiHostEvent>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-dialog-',
      );
      final client = PiCoreRpcClient(
        extensionCompletionDelay: const Duration(milliseconds: 5),
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) =>
            startNodeRpc(command, _rpcScript(dialogOnly: true)),
      );
      final subscription = client.events.listen(events.add);

      try {
        final session = await client.createSession(cwd: workingDirectory.path);
        await expectLater(
          client.prompt(sessionId: session.id, text: '/dialog-extension'),
          throwsA(isA<PiHostClientException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          events.where(
            (event) => event.type == PiHostEventType.extensionUiRequest,
          ),
          isNotEmpty,
        );
        expect(
          events.where(
            (event) => event.type == PiHostEventType.runtimeDiagnostic,
          ),
          hasLength(1),
        );
        final failure = events.singleWhere(
          (event) => event.type == PiHostEventType.runFailed,
        );
        expect(failure.message, contains('not supported'));
        expect(
          events.where((event) => event.type == PiHostEventType.runSettled),
          isEmpty,
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test('a dialog failure cannot shorten the next ordinary prompt', () async {
    final events = <PiHostEvent>[];
    final workingDirectory = await Directory.systemTemp.createTemp(
      'pi-core-rpc-dialog-sequence-',
    );
    final client = PiCoreRpcClient(
      extensionCompletionDelay: const Duration(milliseconds: 5),
      readVersion: (_) async => '0.82.0-test',
      startProcess: (command) =>
          startNodeRpc(command, _rpcScript(dialogThenNormal: true)),
    );
    final subscription = client.events.listen(events.add);

    try {
      final session = await client.createSession(cwd: workingDirectory.path);
      await expectLater(
        client.prompt(sessionId: session.id, text: 'Dialog prompt.'),
        throwsA(isA<PiHostClientException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        events.where((event) => event.type == PiHostEventType.runFailed),
        hasLength(1),
      );

      expect(
        await client.prompt(sessionId: session.id, text: 'Normal prompt.'),
        true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        events.where((event) => event.type == PiHostEventType.runSettled),
        isEmpty,
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        events.where((event) => event.type == PiHostEventType.runSettled),
        hasLength(1),
      );
    } finally {
      await subscription.cancel();
      await client.dispose();
      await workingDirectory.delete(recursive: true);
    }
  });

  test('an extension marker cannot shorten the next ordinary prompt', () async {
    final events = <PiHostEvent>[];
    final workingDirectory = await Directory.systemTemp.createTemp(
      'pi-core-rpc-extension-sequence-',
    );
    final client = PiCoreRpcClient(
      extensionCompletionDelay: const Duration(milliseconds: 5),
      readVersion: (_) async => '0.82.0-test',
      startProcess: (command) =>
          startNodeRpc(command, _rpcScript(extensionThenAgent: true)),
    );
    final subscription = client.events.listen(events.add);

    try {
      final session = await client.createSession(cwd: workingDirectory.path);
      expect(
        await client.prompt(sessionId: session.id, text: 'First prompt.'),
        true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        events.where((event) => event.type == PiHostEventType.runSettled),
        hasLength(1),
      );

      expect(
        await client.prompt(sessionId: session.id, text: 'Second prompt.'),
        true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        events.where((event) => event.type == PiHostEventType.runSettled),
        hasLength(1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        events.where((event) => event.type == PiHostEventType.runSettled),
        hasLength(2),
      );
    } finally {
      await subscription.cancel();
      await client.dispose();
      await workingDirectory.delete(recursive: true);
    }
  });

  test(
    'a failed process cannot poison a different direct RPC session',
    () async {
      final events = <PiHostEvent>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-isolation-',
      );
      var processCount = 0;
      final client = PiCoreRpcClient(
        extensionCompletionDelay: const Duration(milliseconds: 30),
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) {
          final script = processCount++ == 0
              ? _rpcScript(exitOnPrompt: true)
              : _rpcScript();
          return startNodeRpc(command, script);
        },
      );
      final subscription = client.events.listen(events.add);

      try {
        final first = await client.createSession(cwd: workingDirectory.path);
        final second = await client.createSession(cwd: workingDirectory.path);
        expect(
          await client.prompt(sessionId: first.id, text: 'Exit first.'),
          true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        final failure = events.singleWhere(
          (event) => event.type == PiHostEventType.hostError,
        );
        expect(failure.sessionId, first.id);
        expect(
          (await client.getSessionState(sessionId: second.id)).piSessionId,
          'pi-direct-session',
        );
        expect(
          await client.prompt(sessionId: second.id, text: 'Keep running.'),
          true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(
          events.where(
            (event) =>
                event.sessionId == second.id &&
                event.type == PiHostEventType.runSettled,
          ),
          hasLength(1),
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'direct Pi RPC reports only the exited session as a host error',
    () async {
      final events = <PiHostEvent>[];
      final workingDirectory = await Directory.systemTemp.createTemp(
        'pi-core-rpc-exit-',
      );
      final client = PiCoreRpcClient(
        extensionCompletionDelay: const Duration(milliseconds: 50),
        readVersion: (_) async => '0.82.0-test',
        startProcess: (command) =>
            startNodeRpc(command, _rpcScript(exitOnPrompt: true)),
      );
      final subscription = client.events.listen(events.add);

      try {
        final session = await client.createSession(cwd: workingDirectory.path);
        expect(
          await client.prompt(
            sessionId: session.id,
            text: 'Trigger process exit.',
          ),
          true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 60));

        final failure = events.singleWhere(
          (event) => event.type == PiHostEventType.hostError,
        );
        expect(failure.sessionId, session.id);
        expect(failure.message, contains('exited with code 17'));
        await expectLater(
          client.getSessionState(sessionId: session.id),
          throwsA(isA<PiHostClientException>()),
        );
      } finally {
        await subscription.cancel();
        await client.dispose();
        await workingDirectory.delete(recursive: true);
      }
    },
  );
}

String _rpcScript({
  bool localOnly = false,
  bool dialogOnly = false,
  bool dialogThenNormal = false,
  bool exitOnPrompt = false,
  bool extensionThenAgent = false,
  bool crlf = false,
  bool malformedOnState = false,
  bool oversizedOnState = false,
  bool mismatchedStateResponse = false,
}) {
  return '''
let buffer = '';
let promptCount = 0;
function send(value) {
  process.stdout.write(JSON.stringify(value) + '${crlf ? '\\r\\n' : '\\n'}');
}
function state() {
  return {
    model: { provider: 'test', id: 'test-model', name: 'Test model', reasoning: true },
    thinkingLevel: 'medium',
    isStreaming: false,
    sessionFile: '/tmp/direct-pi-session.jsonl',
    sessionId: 'pi-direct-session',
  };
}
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  while (true) {
    const newline = buffer.indexOf('\\n');
    if (newline < 0) break;
    const line = buffer.slice(0, newline);
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    const request = JSON.parse(line);
    if (request.type === 'extension_ui_response') {
      send({ type: 'extension_ui_request', id: 'extension-cancelled', method: 'notify', message: 'dialog cancelled' });
    } else if (request.type === 'get_state') {
      if (${malformedOnState ? 'true' : 'false'}) {
        process.stdout.write('not-json\\n');
      } else if (${oversizedOnState ? 'true' : 'false'}) {
        process.stdout.write('x'.repeat(1048577));
      } else if (${mismatchedStateResponse ? 'true' : 'false'}) {
        send({ id: 'unrelated-response', type: 'response', command: request.type, success: true, data: {} });
        setTimeout(() => send({ id: request.id, type: 'response', command: request.type, success: true, data: state() }), 0);
      } else {
        send({ id: request.id, type: 'response', command: request.type, success: true, data: state() });
      }
    } else if (request.type === 'get_available_thinking_levels') {
      send({ id: request.id, type: 'response', command: request.type, success: true, data: { levels: ['off', 'medium', 'high'] } });
    } else if (request.type === 'get_available_models') {
      send({ id: request.id, type: 'response', command: request.type, success: true, data: { models: [state().model] } });
    } else if (request.type === 'set_model') {
      send({ id: request.id, type: 'response', command: request.type, success: true, data: state().model });
    } else if (request.type === 'set_thinking_level') {
      send({ id: request.id, type: 'response', command: request.type, success: true });
    } else if (request.type === 'prompt') {
      promptCount += 1;
      if (${extensionThenAgent ? 'true' : 'false'}) {
        if (promptCount === 1) {
          send({ type: 'extension_ui_request', id: 'extension-before-agent', method: 'notify', message: 'continue normally' });
          send({ id: request.id, type: 'response', command: request.type, success: true });
          setTimeout(() => {
            send({ type: 'agent_start' });
            send({ type: 'agent_settled' });
          }, 0);
        } else {
          send({ id: request.id, type: 'response', command: request.type, success: true });
          setTimeout(() => {
            send({ type: 'agent_start' });
            send({ type: 'agent_settled' });
          }, 60);
        }
      } else if (${localOnly ? 'true' : 'false'}) {
        send({ type: 'extension_ui_request', id: 'extension-1', method: 'notify', message: 'handled locally' });
        send({ id: request.id, type: 'response', command: request.type, success: true });
      } else if (${dialogThenNormal ? 'true' : 'false'}) {
        if (promptCount === 1) {
          send({ type: 'extension_ui_request', id: 'extension-dialog', method: 'confirm', title: 'Continue?' });
          send({ id: request.id, type: 'response', command: request.type, success: true });
        } else {
          send({ id: request.id, type: 'response', command: request.type, success: true });
          setTimeout(() => {
            send({ type: 'agent_start' });
            send({ type: 'agent_settled' });
          }, 60);
        }
      } else if (${dialogOnly ? 'true' : 'false'}) {
        send({ type: 'extension_ui_request', id: 'extension-dialog', method: 'confirm', title: 'Continue?' });
        send({ id: request.id, type: 'response', command: request.type, success: true });
      } else if (${exitOnPrompt ? 'true' : 'false'}) {
        send({ id: request.id, type: 'response', command: request.type, success: true });
        setTimeout(() => process.exit(17), 0);
      } else {
        send({ id: request.id, type: 'response', command: request.type, success: true });
        setTimeout(() => {
          send({ type: 'agent_start' });
          send({ type: 'message_update', assistantMessageEvent: { type: 'text_delta', delta: 'RPC text\\u2028separator' } });
          send({ type: 'message_update', assistantMessageEvent: { type: 'thinking_delta', delta: 'thinking' } });
          send({ type: 'tool_execution_start', toolCallId: 'tool-1', toolName: 'bash', args: { command: 'printf test' } });
          send({ type: 'tool_execution_update', toolCallId: 'tool-1', toolName: 'bash', partialResult: { content: [] } });
          send({ type: 'tool_execution_end', toolCallId: 'tool-1', toolName: 'bash', result: { content: [] }, isError: false });
          send({ type: 'agent_end', messages: [] });
          send({ type: 'agent_settled' });
        }, 0);
      }
    } else if (request.type === 'abort') {
      send({ type: 'agent_end', messages: [{ role: 'assistant', stopReason: 'aborted' }] });
      send({ type: 'agent_settled' });
      send({ id: request.id, type: 'response', command: request.type, success: true });
    }
  }
});
''';
}
