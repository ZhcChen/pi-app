import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int _maxRecordBytes = 1024 * 1024;
const String _defaultPrompt =
    'Reply with exactly PI_APP_C1_PROMPT_OK and no extra words.';

Future<void> main(List<String> arguments) async {
  final options = _parseOptions(arguments);
  final fixture = await _ProbeFixture.create();
  final report = <String, dynamic>{};

  try {
    report.addAll(await _runProbe(options, fixture));
  } catch (error, stackTrace) {
    report.addAll(<String, dynamic>{
      'probeStatus': 'error',
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    });
  } finally {
    report['fixture'] = fixture.toJson();
    if (options.keepFixture) {
      stderr.writeln('Kept isolated fixture: ${fixture.root.path}');
    } else {
      await fixture.dispose();
    }
  }

  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  if (options.reportPath != null) {
    final reportFile = File(options.reportPath!);
    await reportFile.parent.create(recursive: true);
    await reportFile.writeAsString('$encoded\n', flush: true);
  }
  stdout.writeln(encoded);

  final status = report['probeStatus']?.toString();
  if (status == 'error') {
    exitCode = 1;
  }
}

Future<Map<String, dynamic>> _runProbe(
  _ProbeOptions options,
  _ProbeFixture fixture,
) async {
  final report = <String, dynamic>{
    'probeStatus': 'completed',
    'piExecutable': options.piExecutable,
    'startedAt': DateTime.now().toUtc().toIso8601String(),
  };
  final version = await _readPiVersion(
    options.piExecutable,
    fixture.environment,
  );
  report['piVersion'] = version;

  final steps = <String, dynamic>{};
  final notes = <String>[];
  final warnings = <String>[];

  String? targetSessionPath;
  String? targetSessionName;
  int? targetEntriesCount;
  String? targetLeafId;
  String? targetLastAssistantText;
  Map<String, dynamic>? promptStep;

  bool bootstrappedSessionFile = false;

  final control = await _RpcProbeProcess.start(
    executable: options.piExecutable,
    workingDirectory: fixture.project.path,
    environment: fixture.environment,
  );
  try {
    final startupState = await control.getState();
    final startupEntries = await control.getEntries();
    final startupSessionPath = _nonEmptyString(startupState['sessionFile']);
    targetSessionPath = startupSessionPath;
    steps['startup'] = <String, dynamic>{
      'status': startupSessionPath == null ? 'missing-session-file' : 'ok',
      'sessionId': _nonEmptyString(startupState['sessionId']),
      'sessionFile': startupSessionPath,
      'sessionName': _nonEmptyString(startupState['sessionName']),
      'entriesCount': _entriesCount(startupEntries),
      'leafId': _nonEmptyString(startupEntries['leafId']),
      'entryPreview': _entryPreview(startupEntries),
      'rawState': startupState,
      'stderrTail': control.stderrTail,
    };

    if (startupSessionPath == null) {
      warnings.add(
        'Initial get_state did not return sessionFile; probing whether new_session materializes a persistent session binding.',
      );
      final bootstrapNewSessionStep = await _exerciseNewSession(control);
      steps['bootstrapNewSession'] = bootstrapNewSessionStep;
      final bootstrapState = await control.getState();
      final bootstrapEntries = await control.getEntries();
      targetSessionPath = _nonEmptyString(bootstrapState['sessionFile']);
      steps['postBootstrapState'] = <String, dynamic>{
        'status': targetSessionPath == null ? 'missing-session-file' : 'ok',
        'sessionId': _nonEmptyString(bootstrapState['sessionId']),
        'sessionFile': targetSessionPath,
        'sessionName': _nonEmptyString(bootstrapState['sessionName']),
        'entriesCount': _entriesCount(bootstrapEntries),
        'leafId': _nonEmptyString(bootstrapEntries['leafId']),
        'entryPreview': _entryPreview(bootstrapEntries),
        'rawState': bootstrapState,
        'stderrTail': control.stderrTail,
      };
      bootstrappedSessionFile = targetSessionPath != null;
      if (!bootstrappedSessionFile) {
        report['probeStatus'] = 'completed_with_blockers';
        report['steps'] = steps;
        report['notes'] = notes;
        report['warnings'] = warnings;
        report['summary'] = <String, dynamic>{
          'freshControllerStartsWithSession': false,
          'newSessionCreatesDistinctSession': null,
          'sessionFlagSupport': 'not-tested',
          'crossProcessSwitchBehavior': 'not-tested',
          'recommendedKnownSessionOpenPath': 'blocked-missing-session-file',
          'promptPersistenceEvidence': 'not-tested',
        };
        return report;
      }
      notes.add(
        'Fresh controller did not expose sessionFile at startup; new_session was required before a persistent session reference became observable.',
      );
    }

    final desiredSessionName =
        'pi-app-c1-target-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    await control.setSessionName(desiredSessionName);
    final renamedState = await control.getState();
    targetSessionName = _nonEmptyString(renamedState['sessionName']);
    steps['rename'] = <String, dynamic>{
      'status': targetSessionName == desiredSessionName ? 'ok' : 'mismatch',
      'requestedName': desiredSessionName,
      'observedName': targetSessionName,
      'sessionFile': _nonEmptyString(renamedState['sessionFile']),
      'rawState': renamedState,
      'stderrTail': control.stderrTail,
    };

    promptStep = await _exercisePrompt(control, options.prompt);
    steps['prompt'] = promptStep;
    if (promptStep['status'] == 'blocked') {
      report['probeStatus'] = 'completed_with_blockers';
      warnings.add(
        'Prompt-dependent lifecycle evidence is blocked in the isolated environment.',
      );
    }

    final preparedState = await control.getState();
    final preparedEntries = await control.getEntries();
    final preparedLastAssistantText = await control.getLastAssistantText();
    targetEntriesCount = _entriesCount(preparedEntries);
    targetLeafId = _nonEmptyString(preparedEntries['leafId']);
    targetLastAssistantText = _nonEmptyString(
      preparedLastAssistantText['text'],
    );
    steps['preparedTarget'] = <String, dynamic>{
      'status': 'ok',
      'sessionFile': _nonEmptyString(preparedState['sessionFile']),
      'sessionName': _nonEmptyString(preparedState['sessionName']),
      'entriesCount': targetEntriesCount,
      'leafId': targetLeafId,
      'entryPreview': _entryPreview(preparedEntries),
      'lastAssistantText': targetLastAssistantText,
      'rawState': preparedState,
      'stderrTail': control.stderrTail,
    };

    if (!bootstrappedSessionFile) {
      final newSessionStep = await _exerciseNewSession(control);
      steps['newSession'] = newSessionStep;
    }
  } finally {
    await control.dispose();
  }

  final launchWithSessionStep = await _exerciseLaunchWithSessionFlag(
    executable: options.piExecutable,
    workingDirectory: fixture.project.path,
    environment: fixture.environment,
    targetSessionPath: targetSessionPath!,
    expectedSessionName: targetSessionName,
    expectedEntriesCount: targetEntriesCount,
    expectedLeafId: targetLeafId,
    expectedLastAssistantText: targetLastAssistantText,
  );
  steps['launchWithSessionFlag'] = launchWithSessionStep;

  final crossProcessSwitchStep = await _exerciseCrossProcessSwitch(
    executable: options.piExecutable,
    workingDirectory: fixture.project.path,
    environment: fixture.environment,
    targetSessionPath: targetSessionPath,
    expectedSessionName: targetSessionName,
    expectedEntriesCount: targetEntriesCount,
    expectedLeafId: targetLeafId,
    expectedLastAssistantText: targetLastAssistantText,
  );
  steps['crossProcessSwitch'] = crossProcessSwitchStep;

  final newSessionStep = steps['newSession'] is Map<String, dynamic>
      ? steps['newSession'] as Map<String, dynamic>
      : steps['bootstrapNewSession'] is Map<String, dynamic>
      ? steps['bootstrapNewSession'] as Map<String, dynamic>
      : null;
  final newSessionCreatesDistinct =
      newSessionStep?['createdDistinctSession'] == true;
  final createdPersistedFromUnboundStart =
      newSessionStep?['createdPersistedSessionFromUnboundStart'] == true;
  final sessionFlagStatus =
      launchWithSessionStep['status']?.toString() ?? 'unknown';
  final crossProcessStatus =
      crossProcessSwitchStep['status']?.toString() ?? 'unknown';

  if (!bootstrappedSessionFile && newSessionCreatesDistinct) {
    notes.add(
      'Fresh RPC controller already starts bound to a persistent session; product code must not auto-send new_session on top of startup binding.',
    );
  } else if (createdPersistedFromUnboundStart) {
    notes.add(
      'Fresh controller began without an observable sessionFile; new_session created the first persistent session reference.',
    );
  } else {
    notes.add(
      'Fresh controller startup vs new_session persistence semantics still need follow-up evidence.',
    );
  }
  if (sessionFlagStatus == 'matched-target') {
    notes.add(
      'The official --session startup path rebound the controller to the requested target session in the first get_state round trip.',
    );
  } else if (sessionFlagStatus == 'unsupported') {
    warnings.add(
      'The official --session startup path appears unsupported in this Pi build.',
    );
  }
  if (crossProcessStatus == 'distinct-initial-session-then-switch') {
    warnings.add(
      'Fresh controller + switch_session first exposed a different initial session before rebinding to the target; treat this as orphan-risk until proven otherwise.',
    );
  }

  report['summary'] = <String, dynamic>{
    'freshControllerStartsWithSession': steps['startup']?['status'] == 'ok'
        ? true
        : steps['startup']?['status'] == 'missing-session-file'
        ? false
        : null,
    'newSessionCreatesDistinctSession': newSessionCreatesDistinct,
    'newSessionCreatedPersistedSessionFromUnboundStart':
        createdPersistedFromUnboundStart,
    'sessionFlagSupport': sessionFlagStatus,
    'crossProcessSwitchBehavior': crossProcessStatus,
    'recommendedKnownSessionOpenPath': _recommendedKnownSessionOpenPath(
      sessionFlagStatus: sessionFlagStatus,
      crossProcessStatus: crossProcessStatus,
    ),
    'promptPersistenceEvidence': _promptPersistenceEvidence(
      promptStep: promptStep,
      sessionFlagStep: launchWithSessionStep,
      crossProcessSwitchStep: crossProcessSwitchStep,
    ),
  };
  report['steps'] = steps;
  report['notes'] = notes;
  report['warnings'] = warnings;
  report['finishedAt'] = DateTime.now().toUtc().toIso8601String();
  return report;
}

String _recommendedKnownSessionOpenPath({
  required String sessionFlagStatus,
  required String crossProcessStatus,
}) {
  if (sessionFlagStatus == 'matched-target') {
    return 'prefer-launch-with-session-flag';
  }
  if (crossProcessStatus == 'distinct-initial-session-then-switch') {
    return 'no-safe-cross-process-open-proven';
  }
  if (crossProcessStatus ==
      'switched-to-target-without-distinct-initial-session') {
    return 'fresh-controller-then-switch-session';
  }
  return 'needs-follow-up';
}

String _promptPersistenceEvidence({
  required Map<String, dynamic>? promptStep,
  required Map<String, dynamic> sessionFlagStep,
  required Map<String, dynamic> crossProcessSwitchStep,
}) {
  if (promptStep == null) {
    return 'not-tested';
  }
  final promptStatus = promptStep['status']?.toString();
  if (promptStatus == 'blocked') {
    return 'blocked-no-auth-or-model';
  }
  final sessionFlagMatches =
      sessionFlagStep['matchesExpectedTranscript'] == true;
  final switchMatches =
      crossProcessSwitchStep['matchesExpectedTranscript'] == true;
  if (promptStatus == 'ok' && sessionFlagMatches && switchMatches) {
    return 'verified';
  }
  if (sessionFlagMatches && switchMatches) {
    return 'verified-session-entries-without-assistant-text';
  }
  if (promptStatus != 'ok') {
    return 'failed-before-persistence-check';
  }
  return 'incomplete';
}

Future<Map<String, dynamic>> _exercisePrompt(
  _RpcProbeProcess process,
  String prompt,
) async {
  final events = <String>[];
  final completer = Completer<void>();
  final subscription = process.events.listen((event) {
    final type = event['type']?.toString() ?? 'unknown';
    events.add(type);
    if (type == 'agent_settled' && !completer.isCompleted) {
      completer.complete();
    }
  });

  try {
    await process.prompt(prompt);
    await completer.future.timeout(const Duration(seconds: 90));
    final lastAssistantText = await process.getLastAssistantText();
    final observedText = _nonEmptyString(lastAssistantText['text']);
    if (observedText != null && observedText.contains('PI_APP_C1_PROMPT_OK')) {
      return <String, dynamic>{
        'status': 'ok',
        'events': events,
        'lastAssistantText': observedText,
        'stderrTail': process.stderrTail,
      };
    }

    final errorSource = [
      observedText,
      process.stderrTail,
    ].whereType<String>().join('\n');
    if (_looksLikeAuthOrModelBlock(errorSource)) {
      return <String, dynamic>{
        'status': 'blocked',
        'events': events,
        'lastAssistantText': observedText,
        'stderrTail': process.stderrTail,
      };
    }

    return <String, dynamic>{
      'status': 'failed',
      'events': events,
      'lastAssistantText': observedText,
      'stderrTail': process.stderrTail,
      'reason': 'Prompt settled without the expected token.',
    };
  } on TimeoutException {
    final errorSource = process.stderrTail ?? '';
    return <String, dynamic>{
      'status': _looksLikeAuthOrModelBlock(errorSource) ? 'blocked' : 'failed',
      'events': events,
      'stderrTail': process.stderrTail,
      'reason': 'Prompt did not reach agent_settled before timeout.',
    };
  } catch (error) {
    final source = '$error\n${process.stderrTail ?? ''}';
    return <String, dynamic>{
      'status': _looksLikeAuthOrModelBlock(source) ? 'blocked' : 'failed',
      'events': events,
      'stderrTail': process.stderrTail,
      'reason': error.toString(),
    };
  } finally {
    await subscription.cancel();
  }
}

Future<Map<String, dynamic>> _exerciseNewSession(
  _RpcProbeProcess process,
) async {
  final before = await process.getState();
  final response = await process.newSession();
  final after = await process.getState();
  final cancelled = response['cancelled'] == true;
  final beforeFile = _nonEmptyString(before['sessionFile']);
  final afterFile = _nonEmptyString(after['sessionFile']);
  return <String, dynamic>{
    'status': cancelled ? 'cancelled' : 'ok',
    'cancelled': cancelled,
    'beforeSessionFile': beforeFile,
    'afterSessionFile': afterFile,
    'beforeSessionId': _nonEmptyString(before['sessionId']),
    'afterSessionId': _nonEmptyString(after['sessionId']),
    'createdDistinctSession':
        !cancelled &&
        beforeFile != null &&
        afterFile != null &&
        beforeFile != afterFile,
    'createdPersistedSessionFromUnboundStart':
        !cancelled && beforeFile == null && afterFile != null,
    'beforeRawState': before,
    'afterRawState': after,
    'stderrTail': process.stderrTail,
  };
}

Future<Map<String, dynamic>> _exerciseLaunchWithSessionFlag({
  required String executable,
  required String workingDirectory,
  required Map<String, String> environment,
  required String targetSessionPath,
  required String? expectedSessionName,
  required int? expectedEntriesCount,
  required String? expectedLeafId,
  required String? expectedLastAssistantText,
}) async {
  final process = await _RpcProbeProcess.start(
    executable: executable,
    workingDirectory: workingDirectory,
    environment: environment,
    sessionPath: targetSessionPath,
  );
  try {
    final state = await process.getState();
    final entries = await process.getEntries();
    final lastAssistantText = await process.getLastAssistantText();
    final observedSessionPath = _nonEmptyString(state['sessionFile']);
    final observedEntriesCount = _entriesCount(entries);
    final observedLeafId = _nonEmptyString(entries['leafId']);
    final observedLastAssistantText = _nonEmptyString(
      lastAssistantText['text'],
    );
    final matchesExpectedTranscript =
        expectedEntriesCount == observedEntriesCount &&
        expectedLeafId == observedLeafId &&
        expectedLastAssistantText == observedLastAssistantText;
    return <String, dynamic>{
      'status': observedSessionPath == targetSessionPath
          ? 'matched-target'
          : 'mismatched-target',
      'targetSessionPath': targetSessionPath,
      'observedSessionPath': observedSessionPath,
      'observedSessionName': _nonEmptyString(state['sessionName']),
      'expectedSessionName': expectedSessionName,
      'entriesCount': observedEntriesCount,
      'leafId': observedLeafId,
      'lastAssistantText': observedLastAssistantText,
      'matchesExpectedTranscript': matchesExpectedTranscript,
      'stderrTail': process.stderrTail,
    };
  } catch (error) {
    final message = error.toString();
    return <String, dynamic>{
      'status': _looksLikeUnsupportedSessionFlag(message, process.stderrTail)
          ? 'unsupported'
          : 'failed',
      'targetSessionPath': targetSessionPath,
      'error': message,
      'stderrTail': process.stderrTail,
    };
  } finally {
    await process.dispose();
  }
}

Future<Map<String, dynamic>> _exerciseCrossProcessSwitch({
  required String executable,
  required String workingDirectory,
  required Map<String, String> environment,
  required String? targetSessionPath,
  required String? expectedSessionName,
  required int? expectedEntriesCount,
  required String? expectedLeafId,
  required String? expectedLastAssistantText,
}) async {
  final process = await _RpcProbeProcess.start(
    executable: executable,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  try {
    final before = await process.getState();
    if (targetSessionPath == null) {
      return <String, dynamic>{
        'status': 'blocked-missing-target',
        'stderrTail': process.stderrTail,
      };
    }
    final response = await process.switchSession(targetSessionPath);
    final after = await process.getState();
    final entries = await process.getEntries();
    final lastAssistantText = await process.getLastAssistantText();
    final cancelled = response['cancelled'] == true;
    final beforeSessionPath = _nonEmptyString(before['sessionFile']);
    final afterSessionPath = _nonEmptyString(after['sessionFile']);
    final distinctInitialSession =
        beforeSessionPath != null &&
        afterSessionPath != null &&
        beforeSessionPath != targetSessionPath;
    final observedEntriesCount = _entriesCount(entries);
    final observedLeafId = _nonEmptyString(entries['leafId']);
    final observedLastAssistantText = _nonEmptyString(
      lastAssistantText['text'],
    );
    final matchesExpectedTranscript =
        expectedEntriesCount == observedEntriesCount &&
        expectedLeafId == observedLeafId &&
        expectedLastAssistantText == observedLastAssistantText;
    return <String, dynamic>{
      'status': cancelled
          ? 'cancelled'
          : distinctInitialSession
          ? 'distinct-initial-session-then-switch'
          : 'switched-to-target-without-distinct-initial-session',
      'cancelled': cancelled,
      'targetSessionPath': targetSessionPath,
      'beforeSessionPath': beforeSessionPath,
      'afterSessionPath': afterSessionPath,
      'observedSessionName': _nonEmptyString(after['sessionName']),
      'expectedSessionName': expectedSessionName,
      'entriesCount': observedEntriesCount,
      'leafId': observedLeafId,
      'lastAssistantText': observedLastAssistantText,
      'matchesExpectedTranscript': matchesExpectedTranscript,
      'stderrTail': process.stderrTail,
    };
  } catch (error) {
    return <String, dynamic>{
      'status': 'failed',
      'targetSessionPath': targetSessionPath,
      'error': error.toString(),
      'stderrTail': process.stderrTail,
    };
  } finally {
    await process.dispose();
  }
}

Future<String> _readPiVersion(
  String executable,
  Map<String, String> environment,
) async {
  try {
    final result = await Process.run(
      executable,
      const <String>['--version'],
      environment: environment,
      runInShell: false,
    );
    final output = '${result.stdout}\n${result.stderr}'.trim();
    return output.isEmpty ? 'unknown' : output;
  } catch (_) {
    return 'unknown';
  }
}

bool _looksLikeAuthOrModelBlock(String source) {
  final text = source.toLowerCase();
  return text.contains('auth') ||
      text.contains('login') ||
      text.contains('unauthorized') ||
      text.contains('api key') ||
      text.contains('not logged') ||
      text.contains('model') && text.contains('not available') ||
      text.contains('credential');
}

bool _looksLikeUnsupportedSessionFlag(String error, String? stderrTail) {
  final text = '$error\n${stderrTail ?? ''}'.toLowerCase();
  return text.contains('unknown option') ||
      text.contains('unknown argument') ||
      text.contains('unexpected argument') ||
      text.contains('--session');
}

int _entriesCount(Map<String, dynamic> data) {
  final entries = data['entries'];
  return entries is List ? entries.length : 0;
}

List<Map<String, dynamic>> _entryPreview(Map<String, dynamic> data) {
  final entries = data['entries'];
  if (entries is! List) {
    return const <Map<String, dynamic>>[];
  }
  return entries
      .take(3)
      .map<Map<String, dynamic>>((entry) {
        if (entry is! Map) {
          return <String, dynamic>{'raw': entry.toString()};
        }
        final message = entry['message'];
        return <String, dynamic>{
          'type': entry['type']?.toString(),
          'id': entry['id']?.toString(),
          'parentId': entry['parentId']?.toString(),
          'role': message is Map ? message['role']?.toString() : null,
        };
      })
      .toList(growable: false);
}

String? _nonEmptyString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

class _ProbeOptions {
  const _ProbeOptions({
    required this.piExecutable,
    required this.prompt,
    required this.keepFixture,
    required this.reportPath,
  });

  final String piExecutable;
  final String prompt;
  final bool keepFixture;
  final String? reportPath;
}

_ProbeOptions _parseOptions(List<String> arguments) {
  String piExecutable = 'pi';
  String prompt = _defaultPrompt;
  bool keepFixture = false;
  String? reportPath;

  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    switch (argument) {
      case '--pi':
        index += 1;
        if (index >= arguments.length) {
          throw ArgumentError('Missing value for --pi.');
        }
        piExecutable = arguments[index];
      case '--prompt':
        index += 1;
        if (index >= arguments.length) {
          throw ArgumentError('Missing value for --prompt.');
        }
        prompt = arguments[index];
      case '--report':
        index += 1;
        if (index >= arguments.length) {
          throw ArgumentError('Missing value for --report.');
        }
        reportPath = arguments[index];
      case '--keep-fixture':
        keepFixture = true;
      case '--help':
      case '-h':
        _printUsageAndExit();
      default:
        throw ArgumentError('Unknown argument: $argument');
    }
  }

  return _ProbeOptions(
    piExecutable: piExecutable,
    prompt: prompt,
    keepFixture: keepFixture,
    reportPath: reportPath,
  );
}

Never _printUsageAndExit() {
  stdout.writeln(
    'Usage: dart run tool/verify_pi_core_session_lifecycle.dart '
    '[--pi PATH] [--prompt TEXT] [--report FILE] [--keep-fixture]',
  );
  exit(0);
}

class _ProbeFixture {
  _ProbeFixture({
    required this.root,
    required this.home,
    required this.agent,
    required this.project,
    required this.appDataRoot,
    required this.environment,
    required this.gitInitialized,
  });

  final Directory root;
  final Directory home;
  final Directory agent;
  final Directory project;
  final Directory appDataRoot;
  final Map<String, String> environment;
  final bool gitInitialized;

  static Future<_ProbeFixture> create() async {
    final root = await Directory.systemTemp.createTemp(
      'pi-app-lifecycle-probe-',
    );
    final home = Directory('${root.path}${Platform.pathSeparator}home');
    final agent = Directory('${root.path}${Platform.pathSeparator}pi-agent');
    final project = Directory('${root.path}${Platform.pathSeparator}project');
    final appDataRoot = Directory(
      '${home.path}${Platform.pathSeparator}.pi-app-dev',
    );
    await home.create(recursive: true);
    await agent.create(recursive: true);
    await project.create(recursive: true);
    await File(
      '${project.path}${Platform.pathSeparator}README.md',
    ).writeAsString(
      'Temporary isolated lifecycle probe project.\n',
      flush: true,
    );

    final environment = Map<String, String>.from(Platform.environment)
      ..['HOME'] = home.path
      ..['PI_CODING_AGENT_DIR'] = agent.path;

    var gitInitialized = false;
    try {
      final result = await Process.run(
        'git',
        const <String>['init', '-q'],
        workingDirectory: project.path,
        runInShell: false,
      );
      gitInitialized = result.exitCode == 0;
    } catch (_) {
      gitInitialized = false;
    }

    return _ProbeFixture(
      root: root,
      home: home,
      agent: agent,
      project: project,
      appDataRoot: appDataRoot,
      environment: environment,
      gitInitialized: gitInitialized,
    );
  }

  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'root': root.path,
      'home': home.path,
      'agentDir': agent.path,
      'project': project.path,
      'appDataRoot': appDataRoot.path,
      'gitInitialized': gitInitialized,
    };
  }
}

class _RpcProbeProcess {
  _RpcProbeProcess._({
    required this.process,
    required StreamSubscription<String> stdoutSubscription,
    required StreamSubscription<String> stderrSubscription,
    required Future<void> exitSubscription,
  }) : _stdoutSubscription = stdoutSubscription,
       _stderrSubscription = stderrSubscription,
       _exitSubscription = exitSubscription;

  final Process process;
  final StreamSubscription<String> _stdoutSubscription;
  final StreamSubscription<String> _stderrSubscription;
  final Future<void> _exitSubscription;
  final StreamController<Map<String, dynamic>> _eventsController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pending =
      <String, Completer<Map<String, dynamic>>>{};
  final StringBuffer _stdoutBuffer = StringBuffer();
  final StringBuffer _stderrBuffer = StringBuffer();
  int _nextRequestId = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  String? get stderrTail {
    final text = _stderrBuffer.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Future<_RpcProbeProcess> start({
    required String executable,
    required String workingDirectory,
    required Map<String, String> environment,
    String? sessionPath,
  }) async {
    final arguments = <String>[
      '--mode',
      'rpc',
      if (sessionPath != null) ...<String>['--session', sessionPath],
      '--no-approve',
      '--no-tools',
    ];
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: false,
    );

    late final _RpcProbeProcess probe;
    final stdoutSubscription = process.stdout
        .transform(utf8.decoder)
        .listen((chunk) => probe._consumeStdout(chunk));
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen((chunk) => probe._consumeStderr(chunk));
    final exitSubscription = process.exitCode.then((exitCode) {
      probe._handleProcessExit(exitCode);
    });

    probe = _RpcProbeProcess._(
      process: process,
      stdoutSubscription: stdoutSubscription,
      stderrSubscription: stderrSubscription,
      exitSubscription: exitSubscription,
    );
    return probe;
  }

  Future<Map<String, dynamic>> getState() =>
      _responseData(awaitResponse: _send('get_state'), command: 'get_state');

  Future<Map<String, dynamic>> getEntries() => _responseData(
    awaitResponse: _send('get_entries'),
    command: 'get_entries',
  );

  Future<Map<String, dynamic>> getLastAssistantText() => _responseData(
    awaitResponse: _send('get_last_assistant_text'),
    command: 'get_last_assistant_text',
  );

  Future<Map<String, dynamic>> newSession() async {
    final data = await _responseData(
      awaitResponse: _send('new_session'),
      command: 'new_session',
    );
    return <String, dynamic>{'cancelled': data['cancelled'] == true};
  }

  Future<Map<String, dynamic>> switchSession(String sessionPath) async {
    final data = await _responseData(
      awaitResponse: _send('switch_session', <String, dynamic>{
        'sessionPath': sessionPath,
      }),
      command: 'switch_session',
    );
    return <String, dynamic>{'cancelled': data['cancelled'] == true};
  }

  Future<void> setSessionName(String name) async {
    await _send('set_session_name', <String, dynamic>{'name': name});
  }

  Future<void> prompt(String message) async {
    await _send('prompt', <String, dynamic>{'message': message});
  }

  Future<Map<String, dynamic>> _send(
    String type, [
    Map<String, dynamic> fields = const <String, dynamic>{},
  ]) async {
    if (_disposed) {
      throw StateError('RPC probe process has already been disposed.');
    }
    final id = 'probe-${_nextRequestId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    final record = <String, dynamic>{'id': id, 'type': type, ...fields};
    try {
      process.stdin.write('${jsonEncode(record)}\n');
    } catch (error) {
      _pending.remove(id);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    return completer.future.timeout(const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> _responseData({
    required Future<Map<String, dynamic>> awaitResponse,
    required String command,
  }) async {
    final response = await awaitResponse;
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Pi RPC $command returned invalid data: $data');
  }

  void _consumeStdout(String chunk) {
    _stdoutBuffer.write(chunk);
    if (utf8.encode(_stdoutBuffer.toString()).length > _maxRecordBytes &&
        !_stdoutBuffer.toString().contains('\n')) {
      _failPending('Pi core emitted a record larger than 1 MiB.');
      return;
    }

    while (true) {
      final buffer = _stdoutBuffer.toString();
      final newlineIndex = buffer.indexOf('\n');
      if (newlineIndex < 0) {
        break;
      }
      var line = buffer.substring(0, newlineIndex);
      final remainder = buffer.substring(newlineIndex + 1);
      _stdoutBuffer
        ..clear()
        ..write(remainder);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isEmpty) {
        continue;
      }
      if (utf8.encode(line).length > _maxRecordBytes) {
        _failPending('Pi core emitted a record larger than 1 MiB.');
        return;
      }
      _handleLine(line);
    }
  }

  void _consumeStderr(String chunk) {
    _stderrBuffer.write(chunk);
    final text = _stderrBuffer.toString();
    if (text.length > 8192) {
      _stderrBuffer
        ..clear()
        ..write(text.substring(text.length - 8192));
    }
  }

  void _handleLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('Pi RPC line is not a JSON object.');
      }
      final record = Map<String, dynamic>.from(decoded);
      if (record['type'] == 'response') {
        _handleResponse(record);
        return;
      }
      _eventsController.add(record);
    } catch (error) {
      _failPending('Invalid Pi RPC output: $error');
    }
  }

  void _handleResponse(Map<String, dynamic> record) {
    final id = _nonEmptyString(record['id']);
    if (id == null) {
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    if (record['success'] == true) {
      completer.complete(record);
      return;
    }
    completer.completeError(
      StateError(record['error']?.toString() ?? 'Pi RPC request failed.'),
    );
  }

  void _handleProcessExit(int exitCode) {
    if (_disposed) {
      return;
    }
    _failPending(
      'Pi RPC process exited with code $exitCode. ${stderrTail ?? ''}'.trim(),
    );
  }

  void _failPending(String message) {
    for (final entry in _pending.entries.toList()) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(StateError(message));
      }
    }
    _pending.clear();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _failPending('RPC probe process was disposed.');
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    await _eventsController.close();
    try {
      process.kill();
    } catch (_) {}
    await _exitSubscription.catchError((_) {});
  }
}
