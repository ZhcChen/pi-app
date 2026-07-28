import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const int piCoreRuntimeMaxJsonlRecordBytes = 1024 * 1024;
const Duration _piCoreRuntimeCommandTimeout = Duration(seconds: 5);
const Duration _piCoreRuntimeShutdownTimeout = Duration(milliseconds: 500);
const String _piCoreHealthRequestId = 'pi-app-runtime-health';

enum PiCoreRuntimeStatus {
  checking,
  missing,
  invalidExecutable,
  healthCheckFailed,
  ready,
}

enum PiCoreRuntimeSource { environmentOverride, savedPreference, path }

enum PiCoreRuntimeDiagnosticCode {
  none,
  pathNotFound,
  notExecutable,
  rpcStartFailed,
  rpcTimedOut,
  rpcInvalidJson,
  rpcRejected,
}

class PiCoreRuntimeSnapshot {
  const PiCoreRuntimeSnapshot({
    required this.status,
    this.source,
    this.executablePath,
    this.version,
    this.diagnosticCode = PiCoreRuntimeDiagnosticCode.none,
  });

  const PiCoreRuntimeSnapshot.checking()
    : status = PiCoreRuntimeStatus.checking,
      source = null,
      executablePath = null,
      version = null,
      diagnosticCode = PiCoreRuntimeDiagnosticCode.none;

  final PiCoreRuntimeStatus status;
  final PiCoreRuntimeSource? source;
  final String? executablePath;
  final String? version;
  final PiCoreRuntimeDiagnosticCode diagnosticCode;

  bool get isReady => status == PiCoreRuntimeStatus.ready;
}

abstract interface class PiCoreRuntimeDetector {
  Future<PiCoreRuntimeSnapshot> detect({
    required String? selectedExecutablePath,
  });

  /// Returns an override for the product RPC client, or null to let it use
  /// its normal PATH fallback.
  String? resolveExecutableOverride({required String? selectedExecutablePath});
}

enum PiCoreRuntimeFileState { missing, notFile, notExecutable, executable }

abstract interface class PiCoreRuntimeFileInspector {
  PiCoreRuntimeFileState inspect(String executablePath);
}

abstract interface class PiCoreRuntimeProcessRunner {
  Future<String> readVersion(String executablePath);

  Future<void> checkHealth(String executablePath);
}

/// Detects a user-managed Pi core without exposing RPC records to the UI.
class PlatformPiCoreRuntimeDetector implements PiCoreRuntimeDetector {
  PlatformPiCoreRuntimeDetector({
    Map<String, String>? environment,
    PiCoreRuntimeFileInspector? fileInspector,
    PiCoreRuntimeProcessRunner? processRunner,
  }) : _environment = environment,
       _fileInspector = fileInspector ?? _PlatformPiCoreRuntimeFileInspector(),
       _processRunner = processRunner ?? _PlatformPiCoreRuntimeProcessRunner();

  final Map<String, String>? _environment;
  final PiCoreRuntimeFileInspector _fileInspector;
  final PiCoreRuntimeProcessRunner _processRunner;

  Map<String, String> get _resolvedEnvironment =>
      _environment ?? Platform.environment;

  @override
  Future<PiCoreRuntimeSnapshot> detect({
    required String? selectedExecutablePath,
  }) async {
    final environmentOverride = _normalizedPath(
      _resolvedEnvironment['PI_CORE_EXECUTABLE'],
    );
    final selectedPath = _normalizedPath(selectedExecutablePath);
    if (environmentOverride == null &&
        selectedPath != null &&
        !_isAbsolutePath(selectedPath)) {
      return PiCoreRuntimeSnapshot(
        status: PiCoreRuntimeStatus.invalidExecutable,
        source: PiCoreRuntimeSource.savedPreference,
        executablePath: selectedPath,
        diagnosticCode: PiCoreRuntimeDiagnosticCode.pathNotFound,
      );
    }

    final candidate = _findCandidate(selectedExecutablePath);
    if (candidate == null) {
      return const PiCoreRuntimeSnapshot(status: PiCoreRuntimeStatus.missing);
    }

    final fileState = _fileInspector.inspect(candidate.executablePath);
    if (fileState != PiCoreRuntimeFileState.executable) {
      return PiCoreRuntimeSnapshot(
        status: PiCoreRuntimeStatus.invalidExecutable,
        source: candidate.source,
        executablePath: candidate.executablePath,
        diagnosticCode: fileState == PiCoreRuntimeFileState.notExecutable
            ? PiCoreRuntimeDiagnosticCode.notExecutable
            : PiCoreRuntimeDiagnosticCode.pathNotFound,
      );
    }

    // 版本仅用于诊断；受限 RPC health 决定 Pi 是否可用。
    String? version;
    try {
      version = _versionForDisplay(
        await _processRunner.readVersion(candidate.executablePath),
      );
    } catch (_) {}

    try {
      await _processRunner.checkHealth(candidate.executablePath);
    } on _PiCoreRuntimeProbeException catch (error) {
      return PiCoreRuntimeSnapshot(
        status: PiCoreRuntimeStatus.healthCheckFailed,
        source: candidate.source,
        executablePath: candidate.executablePath,
        version: version,
        diagnosticCode: error.code,
      );
    } catch (_) {
      return PiCoreRuntimeSnapshot(
        status: PiCoreRuntimeStatus.healthCheckFailed,
        source: candidate.source,
        executablePath: candidate.executablePath,
        version: version,
        diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcStartFailed,
      );
    }

    return PiCoreRuntimeSnapshot(
      status: PiCoreRuntimeStatus.ready,
      source: candidate.source,
      executablePath: candidate.executablePath,
      version: version,
    );
  }

  @override
  String? resolveExecutableOverride({required String? selectedExecutablePath}) {
    final environmentOverride = _normalizedPath(
      _resolvedEnvironment['PI_CORE_EXECUTABLE'],
    );
    if (environmentOverride != null) {
      return environmentOverride;
    }
    return _normalizedPath(selectedExecutablePath);
  }

  _PiCoreRuntimeCandidate? _findCandidate(String? selectedExecutablePath) {
    final environmentOverride = _normalizedPath(
      _resolvedEnvironment['PI_CORE_EXECUTABLE'],
    );
    if (environmentOverride != null) {
      return _candidateForEnvironmentOverride(environmentOverride);
    }

    final selectedPath = _normalizedPath(selectedExecutablePath);
    if (selectedPath != null) {
      return _PiCoreRuntimeCandidate(
        source: PiCoreRuntimeSource.savedPreference,
        executablePath: selectedPath,
      );
    }

    return _findOnPath('pi');
  }

  _PiCoreRuntimeCandidate _candidateForEnvironmentOverride(String value) {
    if (_isAbsolutePath(value)) {
      return _PiCoreRuntimeCandidate(
        source: PiCoreRuntimeSource.environmentOverride,
        executablePath: value,
      );
    }

    final resolvedFromPath = _findOnPath(value);
    if (resolvedFromPath != null) {
      return _PiCoreRuntimeCandidate(
        source: PiCoreRuntimeSource.environmentOverride,
        executablePath: resolvedFromPath.executablePath,
      );
    }
    return _PiCoreRuntimeCandidate(
      source: PiCoreRuntimeSource.environmentOverride,
      executablePath: value,
    );
  }

  _PiCoreRuntimeCandidate? _findOnPath(String command) {
    final pathValue = _resolvedEnvironment['PATH'];
    if (pathValue == null || pathValue.trim().isEmpty) {
      return null;
    }

    final separator = Platform.isWindows ? ';' : ':';
    final commandNames = Platform.isWindows
        ? <String>['$command.exe', '$command.cmd', '$command.bat', command]
        : <String>[command];
    for (final rawDirectory in pathValue.split(separator)) {
      final directory = rawDirectory.trim().isEmpty
          ? Directory.current.path
          : rawDirectory.trim();
      for (final commandName in commandNames) {
        final candidate = File(_joinPath(directory, commandName)).absolute.path;
        if (_fileInspector.inspect(candidate) !=
            PiCoreRuntimeFileState.missing) {
          return _PiCoreRuntimeCandidate(
            source: PiCoreRuntimeSource.path,
            executablePath: candidate,
          );
        }
      }
    }
    return null;
  }
}

class PiCoreRuntimeController {
  PiCoreRuntimeController({PiCoreRuntimeDetector? detector})
    : _detector = detector ?? PlatformPiCoreRuntimeDetector();

  final PiCoreRuntimeDetector _detector;
  final Set<void Function()> _listeners = <void Function()>{};
  PiCoreRuntimeSnapshot _snapshot = const PiCoreRuntimeSnapshot.checking();
  String? _selectedExecutablePath;
  int _refreshGeneration = 0;
  Future<void>? _pendingRefresh;
  bool _isDisposed = false;

  PiCoreRuntimeSnapshot get snapshot => _snapshot;
  String? get selectedExecutablePath => _selectedExecutablePath;

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  String? resolveExecutableOverride() {
    return _detector.resolveExecutableOverride(
      selectedExecutablePath: _selectedExecutablePath,
    );
  }

  void configure(String? selectedExecutablePath) {
    final normalizedPath = _normalizedPath(selectedExecutablePath);
    if (normalizedPath == _selectedExecutablePath) {
      return;
    }
    _selectedExecutablePath = normalizedPath;
    _refreshGeneration += 1;
    _setSnapshot(const PiCoreRuntimeSnapshot.checking());
  }

  Future<void> sync(String? selectedExecutablePath) async {
    configure(selectedExecutablePath);
    await refresh();
  }

  Future<void> refresh() {
    final refresh = _runRefresh();
    _pendingRefresh = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_pendingRefresh, refresh)) {
          _pendingRefresh = null;
        }
      }),
    );
    return refresh;
  }

  Future<void> ensureReady() async {
    final pendingRefresh = _pendingRefresh ?? refresh();
    await pendingRefresh;
    if (_isDisposed) {
      throw StateError('Pi core runtime controller has been disposed.');
    }
    if (!_snapshot.isReady) {
      throw StateError('Pi core runtime is not ready.');
    }
  }

  Future<void> _runRefresh() async {
    final generation = ++_refreshGeneration;
    _setSnapshot(const PiCoreRuntimeSnapshot.checking());

    PiCoreRuntimeSnapshot result;
    try {
      result = await _detector.detect(
        selectedExecutablePath: _selectedExecutablePath,
      );
    } catch (_) {
      result = const PiCoreRuntimeSnapshot(
        status: PiCoreRuntimeStatus.healthCheckFailed,
        diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcStartFailed,
      );
    }

    if (_isDisposed || generation != _refreshGeneration) {
      return;
    }
    _setSnapshot(result);
  }

  void _setSnapshot(PiCoreRuntimeSnapshot value) {
    if (_isDisposed) {
      return;
    }
    _snapshot = value;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void dispose() {
    _isDisposed = true;
    _listeners.clear();
  }
}

/// A deterministic detector for widget and controller tests.
class MemoryPiCoreRuntimeDetector implements PiCoreRuntimeDetector {
  MemoryPiCoreRuntimeDetector({
    PiCoreRuntimeSnapshot snapshot = const PiCoreRuntimeSnapshot(
      status: PiCoreRuntimeStatus.ready,
      source: PiCoreRuntimeSource.path,
      executablePath: '/mock/pi',
      version: 'test',
    ),
    this.executableOverride,
  }) : _snapshot = snapshot;

  PiCoreRuntimeSnapshot _snapshot;
  String? executableOverride;
  String? lastSelectedExecutablePath;

  PiCoreRuntimeSnapshot get snapshot => _snapshot;

  void setSnapshot(PiCoreRuntimeSnapshot value) {
    _snapshot = value;
  }

  @override
  Future<PiCoreRuntimeSnapshot> detect({
    required String? selectedExecutablePath,
  }) async {
    lastSelectedExecutablePath = selectedExecutablePath;
    return _snapshot;
  }

  @override
  String? resolveExecutableOverride({required String? selectedExecutablePath}) {
    return executableOverride ?? selectedExecutablePath;
  }
}

class _PlatformPiCoreRuntimeFileInspector
    implements PiCoreRuntimeFileInspector {
  @override
  PiCoreRuntimeFileState inspect(String executablePath) {
    try {
      final type = FileSystemEntity.typeSync(executablePath);
      if (type == FileSystemEntityType.notFound) {
        return PiCoreRuntimeFileState.missing;
      }
      if (type != FileSystemEntityType.file) {
        return PiCoreRuntimeFileState.notFile;
      }
      if (Platform.isWindows) {
        return PiCoreRuntimeFileState.executable;
      }
      final mode = File(executablePath).statSync().mode;
      return mode & 0x49 == 0
          ? PiCoreRuntimeFileState.notExecutable
          : PiCoreRuntimeFileState.executable;
    } catch (_) {
      return PiCoreRuntimeFileState.missing;
    }
  }
}

class _PlatformPiCoreRuntimeProcessRunner
    implements PiCoreRuntimeProcessRunner {
  static const int _maxVersionOutputBytes = 64 * 1024;

  @override
  Future<String> readVersion(String executablePath) async {
    final Process process;
    try {
      process = await Process.start(executablePath, const <String>[
        '--version',
      ], runInShell: false);
    } on ProcessException {
      throw StateError('Could not read Pi core version.');
    }

    final stdout = BytesBuilder(copy: false);
    final stdoutSubscription = process.stdout.listen((chunk) {
      if (stdout.length + chunk.length <= _maxVersionOutputBytes) {
        stdout.add(chunk);
      }
    });
    final stderrSubscription = process.stderr.listen((_) {});

    try {
      final outputStreams = Future.wait<void>(<Future<void>>[
        stdoutSubscription.asFuture<void>(),
        stderrSubscription.asFuture<void>(),
      ]);
      final values = await Future.wait<Object?>(<Future<Object?>>[
        process.exitCode,
        outputStreams,
      ]).timeout(_piCoreRuntimeCommandTimeout);
      final exitCode = values.first! as int;
      if (exitCode != 0) {
        throw StateError('Pi core version check failed.');
      }
      return utf8.decode(stdout.takeBytes());
    } on TimeoutException {
      throw StateError('Pi core version check timed out.');
    } catch (_) {
      throw StateError('Could not read Pi core version.');
    } finally {
      await _stopProcess(process);
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
  }

  @override
  Future<void> checkHealth(String executablePath) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'pi-app-runtime-health-',
    );
    Process? process;
    try {
      try {
        process = await Process.start(
          executablePath,
          const <String>['--mode', 'rpc', '--no-approve', '--no-tools'],
          workingDirectory: temporaryDirectory.path,
          runInShell: false,
        );
      } on ProcessException {
        throw const _PiCoreRuntimeProbeException(
          PiCoreRuntimeDiagnosticCode.rpcStartFailed,
        );
      }
      await _awaitHealthResponse(process);
    } finally {
      if (process != null) {
        await _stopProcess(process);
      }
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    }
  }

  Future<void> _awaitHealthResponse(Process process) async {
    final response = Completer<void>();
    final lineBytes = BytesBuilder(copy: false);
    var lineByteCount = 0;

    void fail(PiCoreRuntimeDiagnosticCode code) {
      if (!response.isCompleted) {
        response.completeError(_PiCoreRuntimeProbeException(code));
      }
    }

    void handleLine(List<int> bytes) {
      if (bytes.isEmpty || response.isCompleted) {
        return;
      }
      var line = bytes;
      if (line.last == 0x0d) {
        line = line.sublist(0, line.length - 1);
      }
      if (line.isEmpty) {
        return;
      }
      if (line.length > piCoreRuntimeMaxJsonlRecordBytes) {
        fail(PiCoreRuntimeDiagnosticCode.rpcInvalidJson);
        return;
      }
      try {
        final decoded = jsonDecode(utf8.decode(line));
        if (decoded is! Map) {
          fail(PiCoreRuntimeDiagnosticCode.rpcInvalidJson);
          return;
        }
        final record = Map<String, dynamic>.from(decoded);
        if (record['type'] != 'response' ||
            record['id'] != _piCoreHealthRequestId) {
          return;
        }
        if (record['success'] != true || record['data'] is! Map) {
          fail(PiCoreRuntimeDiagnosticCode.rpcRejected);
          return;
        }
        response.complete();
      } on FormatException {
        fail(PiCoreRuntimeDiagnosticCode.rpcInvalidJson);
      }
    }

    final stdoutSubscription = process.stdout.listen(
      (chunk) {
        for (final byte in chunk) {
          if (byte == 0x0a) {
            handleLine(lineBytes.takeBytes());
            lineByteCount = 0;
            continue;
          }
          lineBytes.addByte(byte);
          lineByteCount += 1;
          if (lineByteCount > piCoreRuntimeMaxJsonlRecordBytes) {
            fail(PiCoreRuntimeDiagnosticCode.rpcInvalidJson);
            return;
          }
        }
      },
      onError: (_, _) => fail(PiCoreRuntimeDiagnosticCode.rpcStartFailed),
      onDone: () {
        if (!response.isCompleted) {
          fail(PiCoreRuntimeDiagnosticCode.rpcStartFailed);
        }
      },
      cancelOnError: true,
    );
    final stderrSubscription = process.stderr.listen((_) {});
    unawaited(
      process.exitCode.then<void>((_) {
        if (!response.isCompleted) {
          fail(PiCoreRuntimeDiagnosticCode.rpcStartFailed);
        }
      }),
    );

    try {
      const request = '{"id":"pi-app-runtime-health","type":"get_state"}\n';
      process.stdin.add(utf8.encode(request));
      await process.stdin.flush();
      await response.future.timeout(
        _piCoreRuntimeCommandTimeout,
        onTimeout: () => throw const _PiCoreRuntimeProbeException(
          PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
    } finally {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }
  }

  Future<void> _stopProcess(Process process) async {
    try {
      await process.stdin.close();
    } catch (_) {}
    try {
      await process.exitCode.timeout(_piCoreRuntimeShutdownTimeout);
      return;
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
    } catch (_) {
      return;
    }
    try {
      await process.exitCode.timeout(_piCoreRuntimeShutdownTimeout);
    } catch (_) {
      process.kill(ProcessSignal.sigkill);
    }
  }
}

class _PiCoreRuntimeCandidate {
  const _PiCoreRuntimeCandidate({
    required this.source,
    required this.executablePath,
  });

  final PiCoreRuntimeSource source;
  final String executablePath;
}

class _PiCoreRuntimeProbeException implements Exception {
  const _PiCoreRuntimeProbeException(this.code);

  final PiCoreRuntimeDiagnosticCode code;
}

String? _normalizedPath(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _joinPath(String directory, String fileName) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$fileName';
  }
  return '$directory${Platform.pathSeparator}$fileName';
}

bool _isAbsolutePath(String path) {
  if (Platform.isWindows) {
    return RegExp(r'^[a-zA-Z]:[\\/]|^\\\\').hasMatch(path);
  }
  return path.startsWith(Platform.pathSeparator);
}

String? _versionForDisplay(String output) {
  final normalized = output.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final semanticVersion = RegExp(
    r'\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?',
  ).firstMatch(normalized);
  if (semanticVersion != null) {
    return semanticVersion.group(0);
  }
  return normalized.length <= 160
      ? normalized
      : '${normalized.substring(0, 157)}...';
}
