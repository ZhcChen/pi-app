import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/main.dart';

class _FakeFileInspector implements PiCoreRuntimeFileInspector {
  _FakeFileInspector(this.states);

  final Map<String, PiCoreRuntimeFileState> states;

  @override
  PiCoreRuntimeFileState inspect(String executablePath) {
    return states[executablePath] ?? PiCoreRuntimeFileState.missing;
  }
}

class _FakeProcessRunner implements PiCoreRuntimeProcessRunner {
  _FakeProcessRunner({
    this.versionOutput = 'pi 0.82.0',
    this.versionError,
    this.healthError,
  });

  final String versionOutput;
  final Object? versionError;
  final Object? healthError;
  final List<String> versionRequests = <String>[];
  final List<String> healthRequests = <String>[];

  @override
  Future<void> checkHealth(String executablePath) async {
    healthRequests.add(executablePath);
    final error = healthError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<String> readVersion(String executablePath) async {
    versionRequests.add(executablePath);
    final error = versionError;
    if (error != null) {
      throw error;
    }
    return versionOutput;
  }
}

void main() {
  test(
    'detector reports missing Pi when no configured source exists',
    () async {
      final detector = PlatformPiCoreRuntimeDetector(
        environment: const <String, String>{},
        fileInspector: _FakeFileInspector(
          const <String, PiCoreRuntimeFileState>{},
        ),
        processRunner: _FakeProcessRunner(),
      );

      final snapshot = await detector.detect(selectedExecutablePath: null);

      expect(snapshot.status, PiCoreRuntimeStatus.missing);
      expect(snapshot.source, isNull);
      expect(snapshot.executablePath, isNull);
    },
  );

  test('detector distinguishes an invalid selected path', () async {
    const selectedPath = '/mock/missing-pi';
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{},
      fileInspector: _FakeFileInspector(
        const <String, PiCoreRuntimeFileState>{},
      ),
      processRunner: _FakeProcessRunner(),
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.invalidExecutable);
    expect(snapshot.source, PiCoreRuntimeSource.savedPreference);
    expect(snapshot.executablePath, selectedPath);
    expect(snapshot.diagnosticCode, PiCoreRuntimeDiagnosticCode.pathNotFound);
  });

  test(
    'detector distinguishes an executable without execute permission',
    () async {
      const selectedPath = '/mock/non-executable-pi';
      final detector = PlatformPiCoreRuntimeDetector(
        environment: const <String, String>{},
        fileInspector: _FakeFileInspector(
          const <String, PiCoreRuntimeFileState>{
            selectedPath: PiCoreRuntimeFileState.notExecutable,
          },
        ),
        processRunner: _FakeProcessRunner(),
      );

      final snapshot = await detector.detect(
        selectedExecutablePath: selectedPath,
      );

      expect(snapshot.status, PiCoreRuntimeStatus.invalidExecutable);
      expect(
        snapshot.diagnosticCode,
        PiCoreRuntimeDiagnosticCode.notExecutable,
      );
    },
  );

  test('detector discovers a compatible Pi on PATH and runs health', () async {
    final pathDirectory =
        '${Directory.systemTemp.path}${Platform.pathSeparator}pi-bin';
    final executablePath = '$pathDirectory${Platform.pathSeparator}pi';
    final runner = _FakeProcessRunner();
    final detector = PlatformPiCoreRuntimeDetector(
      environment: <String, String>{'PATH': pathDirectory},
      fileInspector: _FakeFileInspector(<String, PiCoreRuntimeFileState>{
        executablePath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: runner,
    );

    final snapshot = await detector.detect(selectedExecutablePath: null);

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.source, PiCoreRuntimeSource.path);
    expect(snapshot.executablePath, executablePath);
    expect(snapshot.version, '0.82.0');
    expect(runner.versionRequests, <String>[executablePath]);
    expect(runner.healthRequests, <String>[executablePath]);
  });

  test('environment override wins over the saved executable path', () async {
    const environmentPath = '/mock/environment-pi';
    const selectedPath = '/mock/selected-pi';
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{
        'PI_CORE_EXECUTABLE': environmentPath,
      },
      fileInspector: _FakeFileInspector(const <String, PiCoreRuntimeFileState>{
        environmentPath: PiCoreRuntimeFileState.executable,
        selectedPath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: _FakeProcessRunner(),
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.source, PiCoreRuntimeSource.environmentOverride);
    expect(snapshot.executablePath, environmentPath);
    expect(
      detector.resolveExecutableOverride(selectedExecutablePath: selectedPath),
      environmentPath,
    );
  });

  test('bare environment override keeps its override source', () async {
    final pathDirectory =
        '${Directory.systemTemp.path}${Platform.pathSeparator}pi-override-bin';
    final executablePath = '$pathDirectory${Platform.pathSeparator}pi';
    final detector = PlatformPiCoreRuntimeDetector(
      environment: <String, String>{
        'PI_CORE_EXECUTABLE': 'pi',
        'PATH': pathDirectory,
      },
      fileInspector: _FakeFileInspector(<String, PiCoreRuntimeFileState>{
        executablePath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: _FakeProcessRunner(),
    );

    final snapshot = await detector.detect(selectedExecutablePath: null);

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.source, PiCoreRuntimeSource.environmentOverride);
    expect(snapshot.executablePath, executablePath);
    expect(
      detector.resolveExecutableOverride(selectedExecutablePath: null),
      'pi',
    );
  });

  test('detector accepts a newer Pi version when RPC health passes', () async {
    const selectedPath = '/mock/newer-pi';
    final runner = _FakeProcessRunner(versionOutput: 'pi 0.83.0');
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{},
      fileInspector: _FakeFileInspector(const <String, PiCoreRuntimeFileState>{
        selectedPath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: runner,
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.version, '0.83.0');
    expect(runner.healthRequests, <String>[selectedPath]);
  });

  test('detector accepts qualified and extended Pi versions', () async {
    const selectedPath = '/mock/qualified-pi';
    for (final entry in <(String, String)>[
      ('pi 0.82.0-beta', '0.82.0-beta'),
      ('pi 0.82.0.1', '0.82.0.1'),
    ]) {
      final runner = _FakeProcessRunner(versionOutput: entry.$1);
      final detector = PlatformPiCoreRuntimeDetector(
        environment: const <String, String>{},
        fileInspector: _FakeFileInspector(
          const <String, PiCoreRuntimeFileState>{
            selectedPath: PiCoreRuntimeFileState.executable,
          },
        ),
        processRunner: runner,
      );

      final snapshot = await detector.detect(
        selectedExecutablePath: selectedPath,
      );

      expect(snapshot.status, PiCoreRuntimeStatus.ready);
      expect(snapshot.version, entry.$2);
      expect(runner.healthRequests, <String>[selectedPath]);
    }
  });

  test('detector continues when version metadata is unavailable', () async {
    const selectedPath = '/mock/version-failure-pi';
    final runner = _FakeProcessRunner(versionError: StateError('failed'));
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{},
      fileInspector: _FakeFileInspector(const <String, PiCoreRuntimeFileState>{
        selectedPath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: runner,
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.version, isNull);
    expect(runner.healthRequests, <String>[selectedPath]);
  });

  test('detector continues when version output is empty', () async {
    const selectedPath = '/mock/empty-version-pi';
    final runner = _FakeProcessRunner(versionOutput: '   \n');
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{},
      fileInspector: _FakeFileInspector(const <String, PiCoreRuntimeFileState>{
        selectedPath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: runner,
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.ready);
    expect(snapshot.version, isNull);
    expect(runner.healthRequests, <String>[selectedPath]);
  });

  test('detector reports a restricted RPC health failure', () async {
    const selectedPath = '/mock/pi';
    final detector = PlatformPiCoreRuntimeDetector(
      environment: const <String, String>{},
      fileInspector: _FakeFileInspector(const <String, PiCoreRuntimeFileState>{
        selectedPath: PiCoreRuntimeFileState.executable,
      }),
      processRunner: _FakeProcessRunner(healthError: StateError('unhealthy')),
    );

    final snapshot = await detector.detect(
      selectedExecutablePath: selectedPath,
    );

    expect(snapshot.status, PiCoreRuntimeStatus.healthCheckFailed);
    expect(snapshot.version, '0.82.0');
    expect(snapshot.diagnosticCode, PiCoreRuntimeDiagnosticCode.rpcStartFailed);
  });

  test(
    'controller gates the product runtime on the current health snapshot',
    () async {
      final detector = MemoryPiCoreRuntimeDetector();
      final controller = PiCoreRuntimeController(detector: detector);
      addTearDown(controller.dispose);

      await controller.sync('/mock/selected-pi');
      await controller.ensureReady();

      expect(controller.selectedExecutablePath, '/mock/selected-pi');
      expect(controller.resolveExecutableOverride(), '/mock/selected-pi');

      detector.setSnapshot(
        const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      await controller.refresh();

      await expectLater(controller.ensureReady(), throwsStateError);
    },
  );
}
