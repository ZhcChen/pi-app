import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'pi_host_client.dart';

const String piCoreRpcAdapterVersion = '1';
const int _piCoreRpcProtocolVersion = 1;
const int _maxPiCoreRpcRecordBytes = 1024 * 1024;
const List<String> _piCoreBuiltinTools = <String>[
  'read',
  'grep',
  'find',
  'ls',
  'bash',
  'edit',
  'write',
];

class PiCoreRpcLaunchCommand {
  const PiCoreRpcLaunchCommand({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;
}

typedef PiCoreRpcProcessStarter =
    Future<Process> Function(PiCoreRpcLaunchCommand command);
typedef PiCoreVersionReader = Future<String> Function(String executable);
typedef PiCoreExecutableResolver = String? Function();
typedef PiCoreRuntimeGate = Future<void> Function();

/// 已安装 Pi CLI 的 `--mode rpc` 产品适配器。
///
/// 公共接口继续沿用既有产品 contract，因此 workspace widget 不消费原始
/// Pi RPC schema。每个 session 独占一个 process，因为 Pi RPC process
/// 同一时刻只承载一个活跃 session。
class PiCoreRpcClient implements PiHostClient {
  PiCoreRpcClient({
    Map<String, String>? environment,
    PiCoreExecutableResolver? executableResolver,
    PiCoreRuntimeGate? runtimeGate,
    PiCoreRpcProcessStarter? startProcess,
    PiCoreVersionReader? readVersion,
    this.extensionCompletionDelay = const Duration(milliseconds: 250),
  }) : _environment = environment,
       _executableResolver = executableResolver,
       _runtimeGate = runtimeGate,
       _startProcess = startProcess ?? _defaultStartProcess,
       _readVersion = readVersion ?? _defaultReadVersion;

  final Map<String, String>? _environment;
  final PiCoreExecutableResolver? _executableResolver;
  final PiCoreRuntimeGate? _runtimeGate;
  final PiCoreRpcProcessStarter _startProcess;
  final PiCoreVersionReader _readVersion;
  final Duration extensionCompletionDelay;
  final StreamController<PiHostEvent> _events =
      StreamController<PiHostEvent>.broadcast();
  final Map<String, _PiCoreRpcSession> _sessions =
      <String, _PiCoreRpcSession>{};

  Future<PiHostHealth>? _healthFuture;
  String? _healthExecutable;
  int _nextRequestNumber = 0;
  int _nextSessionNumber = 0;
  bool _isDisposed = false;

  @override
  Stream<PiHostEvent> get events => _events.stream;

  @override
  Future<PiHostHealth> ensureStarted() async {
    if (_isDisposed) {
      throw const PiHostClientException(
        'Pi core RPC client has already been disposed.',
      );
    }
    await _ensureRuntimeReady();
    return _ensureStartedForExecutable(_resolveExecutable());
  }

  Future<void> _ensureRuntimeReady() async {
    final runtimeGate = _runtimeGate;
    if (runtimeGate == null) {
      return;
    }
    try {
      await runtimeGate();
    } catch (_) {
      throw const PiHostClientException('Pi core runtime is not ready.');
    }
  }

  Future<PiHostHealth> _ensureStartedForExecutable(String executable) {
    final existingHealth = _healthFuture;
    if (existingHealth != null && _healthExecutable == executable) {
      return existingHealth;
    }

    _healthExecutable = executable;
    final health = _loadHealth(executable);
    _healthFuture = health;
    return health;
  }

  Future<PiHostHealth> _loadHealth(String executable) async {
    try {
      var version = 'unknown';
      try {
        final reportedVersion = (await _readVersion(executable)).trim();
        if (reportedVersion.isNotEmpty) {
          version = reportedVersion;
        }
      } catch (_) {
        // 版本元数据不能阻止实际可用的 Pi RPC runtime。
      }
      final environment = _environment ?? Platform.environment;
      return PiHostHealth(
        protocolVersion: _piCoreRpcProtocolVersion,
        sdkVersion: version,
        agentDir: environment['PI_CODING_AGENT_DIR']?.trim() ?? '',
      );
    } catch (_) {
      if (_healthExecutable == executable) {
        _healthFuture = null;
        _healthExecutable = null;
      }
      rethrow;
    }
  }

  @override
  Future<PiHostSession> createSession({
    required String cwd,
    List<String> tools = const <String>[],
  }) async {
    if (_isDisposed) {
      throw const PiHostClientException(
        'Pi core RPC client has already been disposed.',
      );
    }
    if (cwd.trim().isEmpty) {
      throw const PiHostClientException('Pi session cwd must not be empty.');
    }
    _validateTools(tools);
    await _ensureRuntimeReady();
    final executable = _resolveExecutable();
    await _ensureStartedForExecutable(executable);

    final sessionId =
        'pi-core-${DateTime.now().microsecondsSinceEpoch}-${_nextSessionNumber++}';
    final command = PiCoreRpcLaunchCommand(
      executable: executable,
      arguments: <String>[
        '--mode',
        'rpc',
        '--no-approve',
        if (tools.isEmpty) '--no-tools' else '--tools',
        if (tools.isNotEmpty) tools.join(','),
      ],
      workingDirectory: cwd,
    );
    final process = await _startProcess(command);
    final session = _PiCoreRpcSession(
      id: sessionId,
      cwd: cwd,
      generation: _nextSessionNumber,
      process: process,
    );
    _sessions[session.id] = session;
    _bindProcess(session);

    try {
      final snapshot = await _loadSessionSnapshot(
        session,
      ).timeout(const Duration(seconds: 10));
      _emitEvent(
        PiHostEvent(
          type: PiHostEventType.sessionCreated,
          sessionId: session.id,
          data: <String, dynamic>{'session': _sessionToJson(snapshot)},
        ),
      );
      return snapshot;
    } catch (error) {
      await _disposeSession(session, emitFailure: false);
      rethrow;
    }
  }

  @override
  Future<bool> prompt({
    required String sessionId,
    required String text,
    PiHostDelivery? delivery,
  }) async {
    final session = _requireSession(sessionId);
    final command = switch (delivery) {
      PiHostDelivery.steer => 'steer',
      PiHostDelivery.followUp => 'follow_up',
      null => 'prompt',
    };
    final requestMarker = session.eventSequence;
    if (delivery == null) {
      session
        ..awaitingAgentStart = true
        ..agentStartedForPrompt = false
        ..sawExtensionUiRequest = false
        ..promptResponseReceived = false
        ..deferredRunFailureMessage = null
        ..promptEventMarker = requestMarker;
      session.localCompletionTimer?.cancel();
      session.localCompletionTimer = null;
    }

    final response = await _request(session, command, <String, dynamic>{
      'message': text,
    });
    final accepted = response['success'] == true;
    if (delivery == null) {
      session.promptResponseReceived = true;
      final deferredFailure = session.deferredRunFailureMessage;
      if (deferredFailure != null) {
        session.deferredRunFailureMessage = null;
        _emitRunFailed(session, deferredFailure);
        throw PiHostClientException(deferredFailure);
      }
      if (!accepted) {
        session
          ..awaitingAgentStart = false
          ..agentStartedForPrompt = false;
      }
    }
    if (accepted && delivery == null) {
      _scheduleLocalCompletion(session);
    }
    return accepted;
  }

  @override
  Future<PiHostSession> abort({required String sessionId}) async {
    final session = _requireSession(sessionId);
    await _request(session, 'abort', const <String, dynamic>{});
    return _loadSessionSnapshot(session);
  }

  @override
  Future<PiHostSession> switchSession({
    required String sessionId,
    required String sessionPath,
  }) async {
    final session = _requireSession(sessionId);
    final normalizedPath = sessionPath.trim();
    if (normalizedPath.isEmpty) {
      throw const PiHostClientException('Pi session path must not be empty.');
    }
    if (session.isStreaming ||
        session.awaitingAgentStart ||
        session.agentStartedForPrompt ||
        session.localCompletionTimer != null) {
      throw const PiHostClientException(
        'Cannot switch Pi sessions while the agent is still running.',
      );
    }
    session
      ..awaitingAgentStart = false
      ..agentStartedForPrompt = false
      ..sawExtensionUiRequest = false
      ..promptResponseReceived = false
      ..deferredRunFailureMessage = null;
    session.localCompletionTimer?.cancel();
    session.localCompletionTimer = null;

    final response = await _request(
      session,
      'switch_session',
      <String, dynamic>{'sessionPath': normalizedPath},
    );
    final data = _responseData(response, 'switch_session');
    if (data['cancelled'] == true) {
      throw const PiHostClientException('Pi session switch was cancelled.');
    }
    return _loadSessionSnapshot(session);
  }

  @override
  Future<PiHostSession> getSessionState({required String sessionId}) async {
    return _loadSessionSnapshot(_requireSession(sessionId));
  }

  @override
  Future<List<PiHostModel>> listModels({required String sessionId}) async {
    final response = await _request(
      _requireSession(sessionId),
      'get_available_models',
      const <String, dynamic>{},
    );
    final data = _responseData(response, 'get_available_models');
    final models = data['models'];
    if (models is! List) {
      throw const PiHostClientException(
        'Pi core returned an invalid model list.',
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
    final session = _requireSession(sessionId);
    await _request(session, 'set_model', <String, dynamic>{
      'provider': provider,
      'modelId': modelId,
    });
    return _loadSessionSnapshot(session);
  }

  @override
  Future<PiHostSession> setThinkingLevel({
    required String sessionId,
    required String level,
  }) async {
    final session = _requireSession(sessionId);
    await _request(session, 'set_thinking_level', <String, dynamic>{
      'level': level,
    });
    return _loadSessionSnapshot(session);
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    final sessions = _sessions.values.toList(growable: false);
    _sessions.clear();
    await Future.wait(
      sessions.map((session) => _disposeSession(session, emitFailure: false)),
    );
    await _events.close();
  }

  Future<PiHostSession> _loadSessionSnapshot(_PiCoreRpcSession session) async {
    final stateResponse = await _request(
      session,
      'get_state',
      const <String, dynamic>{},
    );
    final state = _responseData(stateResponse, 'get_state');
    final thinkingResponse = await _request(
      session,
      'get_available_thinking_levels',
      const <String, dynamic>{},
    );
    final thinking = _responseData(
      thinkingResponse,
      'get_available_thinking_levels',
    );
    final snapshot = _snapshotFromState(
      session,
      state,
      _stringList(thinking['levels']),
    );
    session.isStreaming = snapshot.isStreaming;
    return snapshot;
  }

  Future<Map<String, dynamic>> _request(
    _PiCoreRpcSession session,
    String type,
    Map<String, dynamic> fields,
  ) async {
    if (!identical(_sessions[session.id], session) || session.isClosed) {
      throw const PiHostClientException(
        'Pi core session is no longer available.',
      );
    }

    final id =
        'pi-core-${session.generation}-${DateTime.now().microsecondsSinceEpoch}-${_nextRequestNumber++}';
    final record = <String, dynamic>{'id': id, 'type': type, ...fields};
    final line = '${jsonEncode(record)}\n';
    if (utf8.encode(line).length > _maxPiCoreRpcRecordBytes) {
      throw const PiHostClientException(
        'Pi core RPC request exceeds the 1 MiB limit.',
      );
    }

    final completer = Completer<Map<String, dynamic>>();
    session.pending[id] = completer;
    try {
      session.process.stdin.write(line);
      await session.process.stdin.flush();
    } catch (error) {
      session.pending.remove(id);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
      _failSession(session, 'Failed to write to Pi core: $error');
    }
    return completer.future;
  }

  void _bindProcess(_PiCoreRpcSession session) {
    session.stdoutSubscription = session.process.stdout
        .transform(utf8.decoder)
        .listen(
          (chunk) => _consumeStdout(session, chunk),
          onError: (Object error, StackTrace _) {
            _failSession(session, 'Invalid Pi core stdout: $error');
          },
          onDone: () => _handleStdoutDone(session),
        );
    session.stderrSubscription = session.process.stderr
        .transform(utf8.decoder)
        .listen((chunk) => _consumeStderr(session, chunk));
    unawaited(
      session.process.exitCode.then(
        (exitCode) => _handleProcessExit(session, exitCode),
      ),
    );
  }

  void _consumeStdout(_PiCoreRpcSession session, String chunk) {
    if (!_isActive(session)) {
      return;
    }

    session.stdoutBuffer += chunk;
    if (utf8.encode(session.stdoutBuffer).length > _maxPiCoreRpcRecordBytes &&
        !session.stdoutBuffer.contains('\n')) {
      _failSession(session, 'Pi core emitted a record larger than 1 MiB.');
      return;
    }

    while (true) {
      final newlineIndex = session.stdoutBuffer.indexOf('\n');
      if (newlineIndex < 0) {
        break;
      }
      var line = session.stdoutBuffer.substring(0, newlineIndex);
      session.stdoutBuffer = session.stdoutBuffer.substring(newlineIndex + 1);
      if (line.endsWith('\r')) {
        line = line.substring(0, line.length - 1);
      }
      if (line.isEmpty) {
        continue;
      }
      if (utf8.encode(line).length > _maxPiCoreRpcRecordBytes) {
        _failSession(session, 'Pi core emitted a record larger than 1 MiB.');
        return;
      }
      _handleRpcLine(session, line);
    }
  }

  void _handleRpcLine(_PiCoreRpcSession session, String line) {
    if (!_isActive(session)) {
      return;
    }

    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('Pi core line is not a JSON object.');
      }
      final record = Map<String, dynamic>.from(decoded);
      session.eventSequence += 1;
      if (record['type'] == 'response') {
        _handleResponse(session, record);
        return;
      }
      _handleEvent(session, record);
    } catch (error) {
      _failSession(session, 'Invalid Pi core RPC output: $error');
    }
  }

  void _handleResponse(_PiCoreRpcSession session, Map<String, dynamic> record) {
    final id = record['id']?.toString();
    if (id == null) {
      throw const PiHostClientException(
        'Pi core response does not include an id.',
      );
    }
    final completer = session.pending.remove(id);
    if (completer == null) {
      return;
    }
    if (record['success'] == true) {
      completer.complete(record);
      return;
    }
    completer.completeError(
      PiHostClientException(
        record['error']?.toString() ?? 'Pi core RPC request failed.',
      ),
    );
  }

  void _handleEvent(_PiCoreRpcSession session, Map<String, dynamic> record) {
    final type = record['type']?.toString();
    switch (type) {
      case 'agent_start':
        session
          ..agentStartedForPrompt = true
          ..awaitingAgentStart = false
          ..sawExtensionUiRequest = false
          ..isStreaming = true;
        session.localCompletionTimer?.cancel();
        session.localCompletionTimer = null;
        _emitEvent(
          PiHostEvent(type: PiHostEventType.runStarted, sessionId: session.id),
        );
        break;
      case 'agent_settled':
        session
          ..awaitingAgentStart = false
          ..agentStartedForPrompt = false
          ..sawExtensionUiRequest = false
          ..isStreaming = false;
        session.localCompletionTimer?.cancel();
        session.localCompletionTimer = null;
        _emitEvent(
          PiHostEvent(type: PiHostEventType.runSettled, sessionId: session.id),
        );
        break;
      case 'agent_end':
        if (_agentEndWasAborted(record)) {
          session.isStreaming = false;
          _emitEvent(
            PiHostEvent(
              type: PiHostEventType.runAborted,
              sessionId: session.id,
            ),
          );
        }
        break;
      case 'message_update':
        _handleMessageUpdate(session, record);
        break;
      case 'tool_execution_start':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.toolStarted,
            sessionId: session.id,
            data: <String, dynamic>{
              'toolCallId': record['toolCallId'],
              'toolName': record['toolName'],
              'args': record['args'],
            },
          ),
        );
        break;
      case 'tool_execution_update':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.toolUpdated,
            sessionId: session.id,
            data: <String, dynamic>{
              'toolCallId': record['toolCallId'],
              'toolName': record['toolName'],
              'partialResult': record['partialResult'],
            },
          ),
        );
        break;
      case 'tool_execution_end':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.toolCompleted,
            sessionId: session.id,
            data: <String, dynamic>{
              'toolCallId': record['toolCallId'],
              'toolName': record['toolName'],
              'result': record['result'],
              'isError': record['isError'] == true,
            },
          ),
        );
        break;
      case 'queue_update':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.queueUpdated,
            sessionId: session.id,
            data: record,
          ),
        );
        break;
      case 'extension_ui_request':
        final method = record['method']?.toString() ?? '';
        if (session.awaitingAgentStart &&
            session.eventSequence > session.promptEventMarker) {
          session.sawExtensionUiRequest = true;
        }
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.extensionUiRequest,
            sessionId: session.id,
            data: record,
          ),
        );
        if (_requiresExtensionUiResponse(method)) {
          _cancelUnsupportedExtensionDialog(session, record, method);
        }
        break;
      case 'extension_error':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.runtimeDiagnostic,
            sessionId: session.id,
            data: <String, dynamic>{
              'message': record['error']?.toString() ?? 'Pi extension failed.',
              'extensionPath': record['extensionPath'],
              'event': record['event'],
            },
          ),
        );
        break;
      default:
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.runtimeDiagnostic,
            sessionId: session.id,
            data: <String, dynamic>{
              'message': 'Unhandled Pi core RPC event: ${type ?? 'unknown'}.',
              'eventType': type,
            },
          ),
        );
    }
  }

  void _handleMessageUpdate(
    _PiCoreRpcSession session,
    Map<String, dynamic> record,
  ) {
    final event = record['assistantMessageEvent'];
    if (event is! Map) {
      return;
    }
    final data = Map<String, dynamic>.from(event);
    switch (data['type']?.toString()) {
      case 'text_delta':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.messageDelta,
            sessionId: session.id,
            data: <String, dynamic>{'delta': data['delta']?.toString() ?? ''},
          ),
        );
        break;
      case 'thinking_delta':
        _emitEvent(
          PiHostEvent(
            type: PiHostEventType.thinkingDelta,
            sessionId: session.id,
            data: <String, dynamic>{'delta': data['delta']?.toString() ?? ''},
          ),
        );
        break;
      case 'error':
        if (data['reason']?.toString() == 'aborted') {
          _emitEvent(
            PiHostEvent(
              type: PiHostEventType.runAborted,
              sessionId: session.id,
            ),
          );
        }
        break;
    }
  }

  void _scheduleLocalCompletion(_PiCoreRpcSession session) {
    if (!_isActive(session) || !session.awaitingAgentStart) {
      return;
    }
    session.localCompletionTimer?.cancel();
    final delay = session.sawExtensionUiRequest
        ? extensionCompletionDelay
        : const Duration(seconds: 2);
    session.localCompletionTimer = Timer(delay, () {
      if (!_isActive(session) ||
          !session.awaitingAgentStart ||
          session.agentStartedForPrompt) {
        return;
      }
      final sawExtensionUiRequest = session.sawExtensionUiRequest;
      session
        ..awaitingAgentStart = false
        ..sawExtensionUiRequest = false
        ..promptResponseReceived = false;
      _emitEvent(
        PiHostEvent(
          type: PiHostEventType.runSettled,
          sessionId: session.id,
          data: <String, dynamic>{
            'handledWithoutRun': true,
            'sawExtensionUiRequest': sawExtensionUiRequest,
          },
        ),
      );
    });
  }

  void _cancelUnsupportedExtensionDialog(
    _PiCoreRpcSession session,
    Map<String, dynamic> record,
    String method,
  ) {
    final requestId = record['id']?.toString();
    if (requestId == null || requestId.isEmpty) {
      _failSession(
        session,
        'Pi extension requested an invalid $method dialog.',
      );
      return;
    }
    session
      ..awaitingAgentStart = false
      ..sawExtensionUiRequest = false
      ..localCompletionTimer?.cancel();
    session.localCompletionTimer = null;
    final message =
        'Pi extension requested $method UI, which is not supported until the extension UI bridge is available.';
    _emitEvent(
      PiHostEvent(
        type: PiHostEventType.runtimeDiagnostic,
        sessionId: session.id,
        data: <String, dynamic>{'message': message, 'method': method},
      ),
    );
    if (session.promptResponseReceived) {
      _emitRunFailed(session, message);
    } else {
      session.deferredRunFailureMessage = message;
    }
    unawaited(
      _sendUncorrelated(session, <String, dynamic>{
        'type': 'extension_ui_response',
        'id': requestId,
        'cancelled': true,
      }),
    );
  }

  void _emitRunFailed(_PiCoreRpcSession session, String message) {
    session.isStreaming = false;
    _emitEvent(
      PiHostEvent(
        type: PiHostEventType.runFailed,
        sessionId: session.id,
        data: <String, dynamic>{'message': message},
      ),
    );
  }

  Future<void> _sendUncorrelated(
    _PiCoreRpcSession session,
    Map<String, dynamic> record,
  ) async {
    if (!_isActive(session)) {
      return;
    }
    final line = '${jsonEncode(record)}\n';
    if (utf8.encode(line).length > _maxPiCoreRpcRecordBytes) {
      _failSession(session, 'Pi core RPC request exceeds the 1 MiB limit.');
      return;
    }
    try {
      session.process.stdin.write(line);
      await session.process.stdin.flush();
    } catch (error) {
      _failSession(session, 'Failed to respond to Pi extension UI: $error');
    }
  }

  void _consumeStderr(_PiCoreRpcSession session, String chunk) {
    if (!_isActive(session)) {
      return;
    }
    session.stderrBuffer = '${session.stderrBuffer}$chunk';
    if (session.stderrBuffer.length > 8192) {
      session.stderrBuffer = session.stderrBuffer.substring(
        session.stderrBuffer.length - 8192,
      );
    }
  }

  void _handleStdoutDone(_PiCoreRpcSession session) {
    if (!_isActive(session) || session.stdoutBuffer.isEmpty) {
      return;
    }
    _failSession(
      session,
      'Pi core stdout closed with an incomplete JSONL record.',
    );
  }

  Future<void> _handleProcessExit(
    _PiCoreRpcSession session,
    int exitCode,
  ) async {
    if (_isDisposed || !_isActive(session)) {
      return;
    }
    final detail = session.stderrBuffer.trim();
    final message = detail.isEmpty
        ? 'Pi core exited with code $exitCode.'
        : 'Pi core exited with code $exitCode: $detail';
    await _disposeSession(session, emitFailure: true, message: message);
  }

  void _failSession(_PiCoreRpcSession session, String message) {
    if (!_isActive(session)) {
      return;
    }
    unawaited(_disposeSession(session, emitFailure: true, message: message));
  }

  Future<void> _disposeSession(
    _PiCoreRpcSession session, {
    required bool emitFailure,
    String? message,
  }) async {
    if (session.isClosed) {
      return;
    }
    session.isClosed = true;
    if (identical(_sessions[session.id], session)) {
      _sessions.remove(session.id);
    }
    session.localCompletionTimer?.cancel();
    session.localCompletionTimer = null;
    final error = PiHostClientException(
      message ?? 'Pi core session is no longer available.',
    );
    for (final completer in session.pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    session.pending.clear();
    await session.stdoutSubscription?.cancel();
    await session.stderrSubscription?.cancel();
    session.stdoutSubscription = null;
    session.stderrSubscription = null;
    if (session.process.kill(ProcessSignal.sigterm)) {
      await session.process.exitCode.catchError((_) => -1);
    }
    if (emitFailure && !_isDisposed) {
      _emitEvent(
        PiHostEvent(
          type: PiHostEventType.hostError,
          sessionId: session.id,
          data: <String, dynamic>{'message': error.message},
        ),
      );
    }
  }

  bool _isActive(_PiCoreRpcSession session) {
    return !_isDisposed &&
        !session.isClosed &&
        identical(_sessions[session.id], session);
  }

  _PiCoreRpcSession _requireSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.isClosed) {
      throw const PiHostClientException(
        'Pi core session is no longer available.',
      );
    }
    return session;
  }

  PiHostSession _snapshotFromState(
    _PiCoreRpcSession session,
    Map<String, dynamic> state,
    List<String> availableThinkingLevels,
  ) {
    final model = state['model'];
    return PiHostSession(
      id: session.id,
      cwd: session.cwd,
      piSessionId: state['sessionId']?.toString() ?? '',
      sessionFile: state['sessionFile']?.toString(),
      sessionName: state['sessionName']?.toString(),
      model: model is Map
          ? PiHostModel.fromJson(Map<String, dynamic>.from(model))
          : null,
      thinkingLevel: state['thinkingLevel']?.toString() ?? 'off',
      availableThinkingLevels: availableThinkingLevels,
      isStreaming: state['isStreaming'] == true,
      isProjectTrusted: false,
    );
  }

  String _resolveExecutable() {
    final resolved = _executableResolver?.call()?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final executable =
        (_environment ?? Platform.environment)['PI_CORE_EXECUTABLE']?.trim();
    return executable == null || executable.isEmpty ? 'pi' : executable;
  }

  void _validateTools(List<String> tools) {
    for (final tool in tools) {
      if (!_piCoreBuiltinTools.contains(tool)) {
        throw PiHostClientException('Unsupported Pi core builtin tool: $tool.');
      }
    }
  }

  void _emitEvent(PiHostEvent event) {
    if (!_isDisposed && !_events.isClosed) {
      _events.add(event);
    }
  }

  static Future<Process> _defaultStartProcess(PiCoreRpcLaunchCommand command) {
    return Process.start(
      command.executable,
      command.arguments,
      workingDirectory: command.workingDirectory,
      runInShell: false,
    );
  }

  static Future<String> _defaultReadVersion(String executable) async {
    final result = await Process.run(executable, const <String>[
      '--version',
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw PiHostClientException(
        'Pi core version check failed: ${result.stderr.toString().trim()}',
      );
    }
    return result.stdout.toString();
  }
}

class _PiCoreRpcSession {
  _PiCoreRpcSession({
    required this.id,
    required this.cwd,
    required this.generation,
    required this.process,
  });

  final String id;
  final String cwd;
  final int generation;
  final Process process;
  final Map<String, Completer<Map<String, dynamic>>> pending =
      <String, Completer<Map<String, dynamic>>>{};

  StreamSubscription<String>? stdoutSubscription;
  StreamSubscription<String>? stderrSubscription;
  Timer? localCompletionTimer;
  String stdoutBuffer = '';
  String stderrBuffer = '';
  int eventSequence = 0;
  int promptEventMarker = 0;
  bool awaitingAgentStart = false;
  bool agentStartedForPrompt = false;
  bool sawExtensionUiRequest = false;
  bool promptResponseReceived = false;
  bool isStreaming = false;
  String? deferredRunFailureMessage;
  bool isClosed = false;
}

Map<String, dynamic> _responseData(
  Map<String, dynamic> response,
  String command,
) {
  final data = response['data'];
  if (data is! Map) {
    throw PiHostClientException('Pi core returned invalid $command data.');
  }
  return Map<String, dynamic>.from(data);
}

bool _agentEndWasAborted(Map<String, dynamic> record) {
  final messages = record['messages'];
  if (messages is! List) {
    return false;
  }
  return messages.any(
    (message) =>
        message is Map &&
        message['role'] == 'assistant' &&
        message['stopReason'] == 'aborted',
  );
}

bool _requiresExtensionUiResponse(String method) {
  return switch (method) {
    'select' || 'confirm' || 'input' || 'editor' => true,
    _ => false,
  };
}

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
