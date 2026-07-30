import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int _piHostProtocolVersion = 1;
const int _maxPiHostRecordBytes = 1024 * 1024;

enum PiHostDelivery { steer, followUp }

enum PiHostEventType {
  hostError,
  sessionCreated,
  sessionState,
  runStarted,
  messageDelta,
  thinkingDelta,
  toolStarted,
  toolUpdated,
  toolCompleted,
  runSettled,
  runAborted,
  runFailed,
  runtimeDiagnostic,
  queueUpdated,
  extensionUiRequest,
}

class PiHostClientException implements Exception {
  const PiHostClientException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PiHostHealth {
  const PiHostHealth({
    required this.protocolVersion,
    required this.sdkVersion,
    required this.agentDir,
  });

  final int protocolVersion;
  final String sdkVersion;
  final String agentDir;

  factory PiHostHealth.fromJson(Map<String, dynamic> json) {
    return PiHostHealth(
      protocolVersion: _intValue(json['protocolVersion']) ?? 0,
      sdkVersion: json['sdkVersion']?.toString() ?? '',
      agentDir: json['agentDir']?.toString() ?? '',
    );
  }
}

class PiHostModel {
  const PiHostModel({
    required this.provider,
    required this.id,
    required this.name,
    required this.reasoning,
  });

  final String provider;
  final String id;
  final String name;
  final bool reasoning;

  String get displayLabel => '$provider/$name';

  factory PiHostModel.fromJson(Map<String, dynamic> json) {
    return PiHostModel(
      provider: json['provider']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      reasoning: json['reasoning'] == true,
    );
  }
}

class PiHostSession {
  const PiHostSession({
    required this.id,
    required this.cwd,
    required this.piSessionId,
    required this.sessionFile,
    required this.sessionName,
    required this.model,
    required this.thinkingLevel,
    required this.availableThinkingLevels,
    required this.isStreaming,
    required this.isProjectTrusted,
  });

  final String id;
  final String cwd;
  final String piSessionId;
  final String? sessionFile;
  final String? sessionName;
  final PiHostModel? model;
  final String thinkingLevel;
  final List<String> availableThinkingLevels;
  final bool isStreaming;
  final bool isProjectTrusted;

  factory PiHostSession.fromJson(Map<String, dynamic> json) {
    final modelValue = json['model'];
    return PiHostSession(
      id: json['id']?.toString() ?? '',
      cwd: json['cwd']?.toString() ?? '',
      piSessionId: json['piSessionId']?.toString() ?? '',
      sessionFile: modelValue == null
          ? json['sessionFile']?.toString()
          : json['sessionFile']?.toString(),
      sessionName: json['sessionName']?.toString(),
      model: modelValue is Map
          ? PiHostModel.fromJson(Map<String, dynamic>.from(modelValue))
          : null,
      thinkingLevel: json['thinkingLevel']?.toString() ?? 'off',
      availableThinkingLevels: _stringList(json['availableThinkingLevels']),
      isStreaming: json['isStreaming'] == true,
      isProjectTrusted: json['isProjectTrusted'] == true,
    );
  }
}

class PiHostEvent {
  const PiHostEvent({
    required this.type,
    this.sessionId,
    this.data = const <String, dynamic>{},
  });

  final PiHostEventType type;
  final String? sessionId;
  final Map<String, dynamic> data;

  String? get delta => data['delta']?.toString();
  String? get message => data['message']?.toString();

  PiHostSession? get session {
    final value = data['session'];
    if (value is! Map) {
      return null;
    }
    return PiHostSession.fromJson(Map<String, dynamic>.from(value));
  }

  factory PiHostEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return PiHostEvent(
      type: _eventTypeFor(json['event']?.toString()),
      sessionId: json['sessionId']?.toString(),
      data: data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{},
    );
  }
}

abstract class PiHostClient {
  Stream<PiHostEvent> get events;

  Future<PiHostHealth> ensureStarted();

  Future<PiHostSession> createSession({
    required String cwd,
    List<String> tools = const <String>[],
  });

  Future<bool> prompt({
    required String sessionId,
    required String text,
    PiHostDelivery? delivery,
  });

  Future<PiHostSession> abort({required String sessionId});

  Future<PiHostSession> getSessionState({required String sessionId});

  Future<List<PiHostModel>> listModels({required String sessionId});

  Future<PiHostSession> setModel({
    required String sessionId,
    required String provider,
    required String modelId,
  });

  Future<PiHostSession> setThinkingLevel({
    required String sessionId,
    required String level,
  });

  Future<void> dispose();
}

class PiHostLaunchCommand {
  const PiHostLaunchCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

typedef PiHostProcessStarter =
    Future<Process> Function(PiHostLaunchCommand command);

class LocalPiHostClient implements PiHostClient {
  LocalPiHostClient({
    Map<String, String>? environment,
    PiHostProcessStarter? startProcess,
  }) : _environment = environment,
       _startProcess = startProcess ?? _defaultStartProcess;

  final Map<String, String>? _environment;
  final PiHostProcessStarter _startProcess;
  final StreamController<PiHostEvent> _events =
      StreamController<PiHostEvent>.broadcast();
  final Map<String, Completer<dynamic>> _pending =
      <String, Completer<dynamic>>{};

  Process? _process;
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Future<PiHostHealth>? _startFuture;
  String _stdoutBuffer = '';
  String _stderrBuffer = '';
  int _nextRequestNumber = 0;
  bool _isDisposed = false;

  @override
  Stream<PiHostEvent> get events => _events.stream;

  @override
  Future<PiHostHealth> ensureStarted() {
    if (_isDisposed) {
      return Future<PiHostHealth>.error(
        const PiHostClientException(
          'Pi host client has already been disposed.',
        ),
      );
    }

    return _startFuture ??= _start();
  }

  Future<PiHostHealth> _start() async {
    Process? startedProcess;
    try {
      final command = _resolveLaunchCommand();
      final process = await _startProcess(command);
      startedProcess = process;
      _process = process;
      _stdoutBuffer = '';
      _stderrBuffer = '';
      _stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .listen(
            (chunk) => _consumeStdout(process, chunk),
            onError: (Object error, StackTrace _) {
              _failProtocol(process, 'Invalid Pi host stdout: $error');
            },
            onDone: () => _handleStdoutDone(process),
          );
      _stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .listen((chunk) => _consumeStderr(process, chunk));
      unawaited(
        process.exitCode.then(
          (exitCode) => _handleProcessExit(process, exitCode),
        ),
      );

      final result = await _sendRequest(
        'host.health',
        const <String, dynamic>{},
      ).timeout(const Duration(seconds: 10));
      final health = PiHostHealth.fromJson(_asJsonMap(result, 'host health'));
      if (health.protocolVersion != _piHostProtocolVersion) {
        throw PiHostClientException(
          'Unsupported Pi host protocol: ${health.protocolVersion}.',
        );
      }
      return health;
    } catch (error) {
      if (startedProcess == null || identical(_process, startedProcess)) {
        _startFuture = null;
      }
      await _terminateProcess(expectedProcess: startedProcess);
      rethrow;
    }
  }

  @override
  Future<PiHostSession> createSession({
    required String cwd,
    List<String> tools = const <String>[],
  }) async {
    final result = await _request('session.create', <String, dynamic>{
      'cwd': cwd,
      'tools': tools,
    });
    return PiHostSession.fromJson(_asJsonMap(result, 'session.create result'));
  }

  @override
  Future<bool> prompt({
    required String sessionId,
    required String text,
    PiHostDelivery? delivery,
  }) async {
    final result = await _request('session.prompt', <String, dynamic>{
      'sessionId': sessionId,
      'text': text,
      if (delivery != null) 'delivery': _deliveryName(delivery),
    });
    final payload = _asJsonMap(result, 'session.prompt result');
    return payload['accepted'] == true;
  }

  @override
  Future<PiHostSession> abort({required String sessionId}) async {
    final result = await _request('session.abort', <String, dynamic>{
      'sessionId': sessionId,
    });
    return PiHostSession.fromJson(_asJsonMap(result, 'session.abort result'));
  }

  @override
  Future<PiHostSession> getSessionState({required String sessionId}) async {
    final result = await _request('session.getState', <String, dynamic>{
      'sessionId': sessionId,
    });
    return PiHostSession.fromJson(_asJsonMap(result, 'session state result'));
  }

  @override
  Future<List<PiHostModel>> listModels({required String sessionId}) async {
    final result = await _request('session.listModels', <String, dynamic>{
      'sessionId': sessionId,
    });
    final payload = _asJsonMap(result, 'session.listModels result');
    final models = payload['models'];
    if (models is! List) {
      throw const PiHostClientException(
        'Pi host returned an invalid model list.',
      );
    }
    return models
        .whereType<Map>()
        .map((value) => PiHostModel.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  @override
  Future<PiHostSession> setModel({
    required String sessionId,
    required String provider,
    required String modelId,
  }) async {
    final result = await _request('session.setModel', <String, dynamic>{
      'sessionId': sessionId,
      'provider': provider,
      'modelId': modelId,
    });
    return PiHostSession.fromJson(
      _asJsonMap(result, 'session.setModel result'),
    );
  }

  @override
  Future<PiHostSession> setThinkingLevel({
    required String sessionId,
    required String level,
  }) async {
    final result = await _request('session.setThinkingLevel', <String, dynamic>{
      'sessionId': sessionId,
      'level': level,
    });
    return PiHostSession.fromJson(
      _asJsonMap(result, 'session.setThinkingLevel result'),
    );
  }

  Future<dynamic> _request(String method, Map<String, dynamic> params) async {
    await ensureStarted();
    return _sendRequest(method, params);
  }

  Future<dynamic> _sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    final process = _process;
    if (process == null) {
      return Future<dynamic>.error(
        const PiHostClientException('Pi host process is not running.'),
      );
    }

    final id =
        'flutter-${DateTime.now().microsecondsSinceEpoch}-${_nextRequestNumber++}';
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    try {
      process.stdin.write(
        '${jsonEncode(<String, dynamic>{'id': id, 'method': method, 'params': params})}\n',
      );
      await process.stdin.flush();
    } catch (error) {
      _pending.remove(id);
      completer.completeError(error);
      _failProtocol(process, 'Failed to write to Pi host: $error');
    }
    return completer.future;
  }

  PiHostLaunchCommand _resolveLaunchCommand() {
    final environment = _environment ?? Platform.environment;
    final configuredExecutable = environment['PI_HOST_EXECUTABLE']?.trim();
    final configuredEntrypoint = environment['PI_HOST_ENTRYPOINT']?.trim();
    final entrypoint =
        configuredEntrypoint == null || configuredEntrypoint.isEmpty
        ? _findDevelopmentEntrypoint()
        : configuredEntrypoint;

    if (entrypoint == null || entrypoint.isEmpty) {
      throw const PiHostClientException(
        'Pi host is unavailable. Build host with `cd host && npm run build`, or set PI_HOST_ENTRYPOINT.',
      );
    }

    final entrypointFile = File(entrypoint).absolute;
    if (!entrypointFile.existsSync()) {
      throw const PiHostClientException(
        'Pi host is unavailable. Build host with `cd host && npm run build`, or set PI_HOST_ENTRYPOINT.',
      );
    }

    return PiHostLaunchCommand(
      executable: configuredExecutable == null || configuredExecutable.isEmpty
          ? 'node'
          : configuredExecutable,
      arguments: <String>[entrypointFile.path],
      workingDirectory: entrypointFile.parent.parent.parent.path,
    );
  }

  String? _findDevelopmentEntrypoint() {
    final current = Directory.current;
    final candidates = <File>[
      File(
        '${current.path}${Platform.pathSeparator}host${Platform.pathSeparator}dist${Platform.pathSeparator}src${Platform.pathSeparator}index.js',
      ),
      File(
        '${current.parent.path}${Platform.pathSeparator}host${Platform.pathSeparator}dist${Platform.pathSeparator}src${Platform.pathSeparator}index.js',
      ),
    ];
    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        return candidate.path;
      }
    }
    return null;
  }

  static Future<Process> _defaultStartProcess(PiHostLaunchCommand command) {
    return Process.start(
      command.executable,
      command.arguments,
      workingDirectory: command.workingDirectory,
      runInShell: false,
    );
  }

  void _consumeStdout(Process source, String chunk) {
    if (!identical(_process, source)) {
      return;
    }

    _stdoutBuffer += chunk;
    if (utf8.encode(_stdoutBuffer).length > _maxPiHostRecordBytes &&
        !_stdoutBuffer.contains('\n')) {
      _failProtocol(source, 'Pi host emitted a record larger than 1 MiB.');
      return;
    }
    while (true) {
      final newlineIndex = _stdoutBuffer.indexOf('\n');
      if (newlineIndex < 0) {
        break;
      }

      var line = _stdoutBuffer.substring(0, newlineIndex);
      _stdoutBuffer = _stdoutBuffer.substring(newlineIndex + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isEmpty) {
        continue;
      }
      if (utf8.encode(line).length > _maxPiHostRecordBytes) {
        _failProtocol(source, 'Pi host emitted a record larger than 1 MiB.');
        return;
      }
      _handleHostLine(source, line);
    }
  }

  void _handleHostLine(Process source, String line) {
    if (!identical(_process, source)) {
      return;
    }

    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('Pi host line is not a JSON object.');
      }
      final json = Map<String, dynamic>.from(decoded);
      if (json['type'] == 'response') {
        _handleResponse(source, json);
      } else if (json['type'] == 'event') {
        _emitEvent(PiHostEvent.fromJson(json));
      } else {
        throw const FormatException('Pi host emitted an unknown record type.');
      }
    } catch (error) {
      _failProtocol(source, 'Invalid Pi host output: $error');
    }
  }

  void _handleResponse(Process source, Map<String, dynamic> json) {
    if (!identical(_process, source)) {
      return;
    }

    final id = json['id']?.toString();
    if (id == null) {
      return;
    }
    final completer = _pending.remove(id);
    if (completer == null) {
      return;
    }

    if (json['ok'] == true) {
      completer.complete(json['result']);
      return;
    }

    final error = json['error'];
    final message = error is Map ? error['message']?.toString() : null;
    completer.completeError(
      PiHostClientException(message ?? 'Pi host request failed.'),
    );
  }

  void _consumeStderr(Process source, String chunk) {
    if (!identical(_process, source)) {
      return;
    }

    _stderrBuffer = '$_stderrBuffer$chunk';
    if (_stderrBuffer.length > 8192) {
      _stderrBuffer = _stderrBuffer.substring(_stderrBuffer.length - 8192);
    }
  }

  void _handleStdoutDone(Process source) {
    if (!identical(_process, source)) {
      return;
    }

    if (_stdoutBuffer.isNotEmpty) {
      _failProtocol(
        source,
        'Pi host stdout closed with an incomplete JSONL record.',
      );
      return;
    }
    _stdoutBuffer = '';
  }

  Future<void> _handleProcessExit(Process source, int exitCode) async {
    if (_isDisposed || !identical(_process, source)) {
      return;
    }

    _startFuture = null;
    final details = _stderrBuffer.trim();
    final message = details.isEmpty
        ? 'Pi host exited with code $exitCode.'
        : 'Pi host exited with code $exitCode: $details';
    _completePendingWithError(PiHostClientException(message));
    _emitEvent(
      PiHostEvent(
        type: PiHostEventType.hostError,
        data: <String, dynamic>{'message': message},
      ),
    );
    await _terminateProcess(expectedProcess: source);
  }

  void _emitEvent(PiHostEvent event) {
    if (!_isDisposed && !_events.isClosed) {
      _events.add(event);
    }
  }

  void _failProtocol(Process source, String message) {
    if (!identical(_process, source)) {
      return;
    }

    _startFuture = null;
    _completePendingWithError(PiHostClientException(message));
    _emitEvent(
      PiHostEvent(
        type: PiHostEventType.hostError,
        data: <String, dynamic>{'message': message},
      ),
    );
    unawaited(_terminateProcess(expectedProcess: source));
  }

  void _completePendingWithError(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  Future<void> _terminateProcess({Process? expectedProcess}) async {
    final process = _process;
    if (process == null ||
        (expectedProcess != null && !identical(process, expectedProcess))) {
      return;
    }

    _process = null;
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    process.kill(ProcessSignal.sigterm);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _completePendingWithError(
      const PiHostClientException('Pi host client was disposed.'),
    );
    await _terminateProcess();
    await _events.close();
  }
}

class MemoryPiHostClient implements PiHostClient {
  MemoryPiHostClient({
    this.health = const PiHostHealth(
      protocolVersion: _piHostProtocolVersion,
      sdkVersion: '0.82.0-test',
      agentDir: '/mock/.pi/agent',
    ),
    this.promptAccepted = true,
    this.emitRunStartedOnPrompt = true,
    this.settleWithoutRunOnPrompt = false,
    this.promptResponseCompleter,
  });

  final PiHostHealth health;
  bool promptAccepted;
  bool emitRunStartedOnPrompt;
  bool settleWithoutRunOnPrompt;
  Completer<bool>? promptResponseCompleter;
  final StreamController<PiHostEvent> _events =
      StreamController<PiHostEvent>.broadcast();
  final Map<String, PiHostSession> _sessions = <String, PiHostSession>{};
  final List<({String sessionId, List<String> tools})> createdSessions =
      <({String sessionId, List<String> tools})>[];
  final List<({String sessionId, String text, PiHostDelivery? delivery})>
  promptRequests =
      <({String sessionId, String text, PiHostDelivery? delivery})>[];
  final List<String> abortedSessionIds = <String>[];
  int _nextSession = 0;
  bool disposed = false;

  @override
  Stream<PiHostEvent> get events => _events.stream;

  @override
  Future<PiHostHealth> ensureStarted() async => health;

  @override
  Future<PiHostSession> createSession({
    required String cwd,
    List<String> tools = const <String>[],
  }) async {
    final session = PiHostSession(
      id: 'memory-session-${_nextSession++}',
      cwd: cwd,
      piSessionId: 'pi-memory-$_nextSession',
      sessionFile: null,
      sessionName: null,
      model: const PiHostModel(
        provider: 'test',
        id: 'test-model',
        name: 'Test model',
        reasoning: true,
      ),
      thinkingLevel: 'medium',
      availableThinkingLevels: const <String>['off', 'low', 'medium', 'high'],
      isStreaming: false,
      isProjectTrusted: false,
    );
    _sessions[session.id] = session;
    createdSessions.add((
      sessionId: session.id,
      tools: List<String>.from(tools),
    ));
    emit(
      PiHostEvent(
        type: PiHostEventType.sessionCreated,
        sessionId: session.id,
        data: <String, dynamic>{'session': _sessionToJson(session)},
      ),
    );
    return session;
  }

  @override
  Future<bool> prompt({
    required String sessionId,
    required String text,
    PiHostDelivery? delivery,
  }) async {
    _requireSession(sessionId);
    promptRequests.add((sessionId: sessionId, text: text, delivery: delivery));
    if (settleWithoutRunOnPrompt) {
      final session = _requireSession(sessionId);
      emit(
        PiHostEvent(
          type: PiHostEventType.runSettled,
          sessionId: sessionId,
          data: <String, dynamic>{
            'session': _sessionToJson(session),
            'handledWithoutRun': true,
          },
        ),
      );
    } else if (emitRunStartedOnPrompt) {
      emit(PiHostEvent(type: PiHostEventType.runStarted, sessionId: sessionId));
    }
    final responseCompleter = promptResponseCompleter;
    if (responseCompleter != null) {
      return responseCompleter.future;
    }
    return promptAccepted;
  }

  @override
  Future<PiHostSession> abort({required String sessionId}) async {
    abortedSessionIds.add(sessionId);
    return _requireSession(sessionId);
  }

  @override
  Future<PiHostSession> getSessionState({required String sessionId}) async {
    return _requireSession(sessionId);
  }

  @override
  Future<List<PiHostModel>> listModels({required String sessionId}) async {
    return <PiHostModel>[_requireSession(sessionId).model!];
  }

  @override
  Future<PiHostSession> setModel({
    required String sessionId,
    required String provider,
    required String modelId,
  }) async {
    final current = _requireSession(sessionId);
    final updated = PiHostSession(
      id: current.id,
      cwd: current.cwd,
      piSessionId: current.piSessionId,
      sessionFile: current.sessionFile,
      sessionName: current.sessionName,
      model: PiHostModel(
        provider: provider,
        id: modelId,
        name: modelId,
        reasoning: current.model?.reasoning ?? false,
      ),
      thinkingLevel: current.thinkingLevel,
      availableThinkingLevels: current.availableThinkingLevels,
      isStreaming: current.isStreaming,
      isProjectTrusted: current.isProjectTrusted,
    );
    _sessions[sessionId] = updated;
    return updated;
  }

  @override
  Future<PiHostSession> setThinkingLevel({
    required String sessionId,
    required String level,
  }) async {
    final current = _requireSession(sessionId);
    final updated = PiHostSession(
      id: current.id,
      cwd: current.cwd,
      piSessionId: current.piSessionId,
      sessionFile: current.sessionFile,
      sessionName: current.sessionName,
      model: current.model,
      thinkingLevel: level,
      availableThinkingLevels: current.availableThinkingLevels,
      isStreaming: current.isStreaming,
      isProjectTrusted: current.isProjectTrusted,
    );
    _sessions[sessionId] = updated;
    return updated;
  }

  void emit(PiHostEvent event) {
    if (!disposed) {
      _events.add(event);
    }
  }

  void setSessionNameForTesting({
    required String sessionId,
    required String? sessionName,
  }) {
    final current = _requireSession(sessionId);
    _sessions[sessionId] = PiHostSession(
      id: current.id,
      cwd: current.cwd,
      piSessionId: current.piSessionId,
      sessionFile: current.sessionFile,
      sessionName: sessionName,
      model: current.model,
      thinkingLevel: current.thinkingLevel,
      availableThinkingLevels: current.availableThinkingLevels,
      isStreaming: current.isStreaming,
      isProjectTrusted: current.isProjectTrusted,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }

  PiHostSession _requireSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw PiHostClientException('Unknown memory session: $sessionId');
    }
    return session;
  }
}

PiHostEventType _eventTypeFor(String? value) {
  return switch (value) {
    'session.created' => PiHostEventType.sessionCreated,
    'session.state' => PiHostEventType.sessionState,
    'run.started' => PiHostEventType.runStarted,
    'message.delta' => PiHostEventType.messageDelta,
    'thinking.delta' => PiHostEventType.thinkingDelta,
    'tool.started' => PiHostEventType.toolStarted,
    'tool.updated' => PiHostEventType.toolUpdated,
    'tool.completed' => PiHostEventType.toolCompleted,
    'run.settled' => PiHostEventType.runSettled,
    'run.aborted' => PiHostEventType.runAborted,
    'run.failed' => PiHostEventType.runFailed,
    'runtime.diagnostic' => PiHostEventType.runtimeDiagnostic,
    _ => PiHostEventType.hostError,
  };
}

String _deliveryName(PiHostDelivery delivery) {
  return switch (delivery) {
    PiHostDelivery.steer => 'steer',
    PiHostDelivery.followUp => 'followUp',
  };
}

Map<String, dynamic> _asJsonMap(Object? value, String label) {
  if (value is! Map) {
    throw PiHostClientException('Pi host returned an invalid $label.');
  }
  return Map<String, dynamic>.from(value);
}

int? _intValue(Object? value) => value is int ? value : int.tryParse('$value');

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((entry) => entry.toString()).toList(growable: false);
}

Map<String, dynamic> _sessionToJson(PiHostSession session) {
  return <String, dynamic>{
    'id': session.id,
    'cwd': session.cwd,
    'piSessionId': session.piSessionId,
    'sessionFile': session.sessionFile,
    'sessionName': session.sessionName,
    'model': session.model == null
        ? null
        : <String, dynamic>{
            'provider': session.model!.provider,
            'id': session.model!.id,
            'name': session.model!.name,
            'reasoning': session.model!.reasoning,
          },
    'thinkingLevel': session.thinkingLevel,
    'availableThinkingLevels': session.availableThinkingLevels,
    'isStreaming': session.isStreaming,
    'isProjectTrusted': session.isProjectTrusted,
  };
}
