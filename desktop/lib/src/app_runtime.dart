import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_preferences.dart';

class DesktopRuntimeCapabilities {
  const DesktopRuntimeCapabilities({required this.supportsShowInMenuBar});

  final bool supportsShowInMenuBar;
}

class DesktopOpenRequest {
  const DesktopOpenRequest({
    required this.destination,
    required this.targetPath,
    this.workspacePath,
  });

  final AppOpenDestination destination;
  final String targetPath;
  final String? workspacePath;
}

class DesktopOpenResult {
  const DesktopOpenResult._({required this.launched, this.errorMessage});

  const DesktopOpenResult.success() : this._(launched: true);

  const DesktopOpenResult.failure(String message)
    : this._(launched: false, errorMessage: message);

  final bool launched;
  final String? errorMessage;
}

typedef DesktopRuntimeToggle = Future<void> Function(bool enabled);
typedef DesktopRuntimeLauncher =
    Future<DesktopOpenResult> Function(DesktopOpenRequest request);

abstract class DesktopRuntimeController {
  DesktopRuntimeCapabilities get capabilities;

  Future<void> sync(AppPreferences preferences);

  Future<DesktopOpenResult> openTarget(DesktopOpenRequest request);
}

class PlatformDesktopRuntimeController implements DesktopRuntimeController {
  PlatformDesktopRuntimeController({
    DesktopRuntimeCapabilities? capabilities,
    DesktopRuntimeToggle? setPreventSleep,
    DesktopRuntimeToggle? setShowInMenuBar,
    DesktopRuntimeLauncher? openTarget,
  }) : capabilities =
           capabilities ??
           DesktopRuntimeCapabilities(supportsShowInMenuBar: Platform.isMacOS),
       _setPreventSleep = setPreventSleep ?? _togglePreventSleep,
       _setShowInMenuBar = setShowInMenuBar ?? _toggleShowInMenuBar,
       _openTarget = openTarget ?? _launchOpenTarget;

  static const MethodChannel _runtimeChannel = MethodChannel(
    'pi.dev/desktop_runtime',
  );

  @override
  final DesktopRuntimeCapabilities capabilities;

  final DesktopRuntimeToggle _setPreventSleep;
  final DesktopRuntimeToggle _setShowInMenuBar;
  final DesktopRuntimeLauncher _openTarget;

  bool? _lastPreventSleep;
  bool? _lastShowInMenuBar;

  @override
  Future<void> sync(AppPreferences preferences) async {
    await _syncShowInMenuBar(preferences.showInMenuBar);
    await _syncPreventSleep(preferences.preventSleep);
  }

  @override
  Future<DesktopOpenResult> openTarget(DesktopOpenRequest request) {
    return _openTarget(request);
  }

  Future<void> _syncShowInMenuBar(bool enabled) async {
    if (_lastShowInMenuBar == enabled) {
      return;
    }

    _lastShowInMenuBar = enabled;

    if (!capabilities.supportsShowInMenuBar) {
      return;
    }

    try {
      await _setShowInMenuBar(enabled);
    } catch (_) {}
  }

  Future<void> _syncPreventSleep(bool enabled) async {
    if (_lastPreventSleep == enabled) {
      return;
    }

    _lastPreventSleep = enabled;

    try {
      await _setPreventSleep(enabled);
    } catch (_) {}
  }

  static Future<void> _togglePreventSleep(bool enabled) async {
    await WakelockPlus.toggle(enable: enabled);
  }

  static Future<void> _toggleShowInMenuBar(bool enabled) async {
    await _runtimeChannel.invokeMethod('setShowInMenuBarEnabled', {
      'enabled': enabled,
    });
  }

  static Future<DesktopOpenResult> _launchOpenTarget(
    DesktopOpenRequest request,
  ) async {
    final entityType = FileSystemEntity.typeSync(request.targetPath);
    if (entityType == FileSystemEntityType.notFound) {
      return DesktopOpenResult.failure('Path not found: ${request.targetPath}');
    }

    return switch (request.destination) {
      AppOpenDestination.vscode => _openInVsCode(request),
      AppOpenDestination.cursor => _openInCursor(request),
      AppOpenDestination.terminal => _openInTerminal(request),
    };
  }

  static Future<DesktopOpenResult> _openInVsCode(DesktopOpenRequest request) {
    if (Platform.isMacOS) {
      return _launchCandidates([
        _LaunchCommand('code', [request.targetPath]),
        _LaunchCommand('open', [
          '-a',
          'Visual Studio Code',
          request.targetPath,
        ]),
      ], failureMessage: 'Could not find a launchable VS Code command or app.');
    }

    if (Platform.isWindows) {
      return _launchCandidates([
        _LaunchCommand('code.cmd', [request.targetPath]),
        _LaunchCommand('code.exe', [request.targetPath]),
        _LaunchCommand('cmd.exe', [
          '/c',
          'start',
          '',
          'code',
          request.targetPath,
        ]),
      ], failureMessage: 'Could not find a launchable VS Code command or app.');
    }

    return _launchCandidates([
      _LaunchCommand('code', [request.targetPath]),
    ], failureMessage: 'Could not find a launchable VS Code command or app.');
  }

  static Future<DesktopOpenResult> _openInCursor(DesktopOpenRequest request) {
    if (Platform.isMacOS) {
      return _launchCandidates([
        _LaunchCommand('cursor', [request.targetPath]),
        _LaunchCommand('open', ['-a', 'Cursor', request.targetPath]),
      ], failureMessage: 'Could not find a launchable Cursor command or app.');
    }

    if (Platform.isWindows) {
      return _launchCandidates([
        _LaunchCommand('cursor.cmd', [request.targetPath]),
        _LaunchCommand('cursor.exe', [request.targetPath]),
        _LaunchCommand('cmd.exe', [
          '/c',
          'start',
          '',
          'cursor',
          request.targetPath,
        ]),
      ], failureMessage: 'Could not find a launchable Cursor command or app.');
    }

    return _launchCandidates([
      _LaunchCommand('cursor', [request.targetPath]),
    ], failureMessage: 'Could not find a launchable Cursor command or app.');
  }

  static Future<DesktopOpenResult> _openInTerminal(DesktopOpenRequest request) {
    final directory = _terminalDirectoryFor(request.targetPath);

    if (Platform.isMacOS) {
      return _launchCandidates([
        _LaunchCommand('open', ['-a', 'Terminal', directory]),
      ], failureMessage: 'Could not open Terminal for $directory.');
    }

    if (Platform.isWindows) {
      return _launchCandidates([
        _LaunchCommand('cmd.exe', [
          '/c',
          'start',
          '',
          'cmd.exe',
          '/K',
          'cd /d "$directory"',
        ]),
      ], failureMessage: 'Could not open Terminal for $directory.');
    }

    return _launchCandidates([
      _LaunchCommand('x-terminal-emulator', ['--working-directory', directory]),
      _LaunchCommand('gnome-terminal', ['--working-directory=$directory']),
      _LaunchCommand('konsole', ['--workdir', directory]),
      _LaunchCommand('xfce4-terminal', ['--working-directory', directory]),
    ], failureMessage: 'Could not open Terminal for $directory.');
  }

  static String _terminalDirectoryFor(String targetPath) {
    final entityType = FileSystemEntity.typeSync(targetPath);
    if (entityType == FileSystemEntityType.directory) {
      return targetPath;
    }

    return File(targetPath).parent.path;
  }

  static Future<DesktopOpenResult> _launchCandidates(
    List<_LaunchCommand> candidates, {
    required String failureMessage,
  }) async {
    Object? lastError;

    for (final candidate in candidates) {
      try {
        await Process.start(
          candidate.executable,
          candidate.arguments,
          mode: ProcessStartMode.detached,
        );
        return const DesktopOpenResult.success();
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError == null) {
      return DesktopOpenResult.failure(failureMessage);
    }

    return DesktopOpenResult.failure('$failureMessage ${lastError.toString()}');
  }
}

class MemoryDesktopRuntimeController implements DesktopRuntimeController {
  MemoryDesktopRuntimeController({
    DesktopRuntimeCapabilities? capabilities,
    this.openResult = const DesktopOpenResult.success(),
  }) : capabilities =
           capabilities ??
           const DesktopRuntimeCapabilities(supportsShowInMenuBar: true);

  @override
  final DesktopRuntimeCapabilities capabilities;

  final DesktopOpenResult openResult;

  AppPreferences? lastSyncedPreferences;
  DesktopOpenRequest? lastOpenRequest;
  int syncCount = 0;
  int openCount = 0;

  @override
  Future<void> sync(AppPreferences preferences) async {
    lastSyncedPreferences = preferences;
    syncCount += 1;
  }

  @override
  Future<DesktopOpenResult> openTarget(DesktopOpenRequest request) async {
    lastOpenRequest = request;
    openCount += 1;
    return openResult;
  }
}

class _LaunchCommand {
  const _LaunchCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
