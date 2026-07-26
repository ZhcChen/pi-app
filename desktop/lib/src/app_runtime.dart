import 'dart:io';

import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_preferences.dart';

class DesktopRuntimeCapabilities {
  const DesktopRuntimeCapabilities({required this.supportsShowInMenuBar});

  final bool supportsShowInMenuBar;
}

typedef DesktopRuntimeToggle = Future<void> Function(bool enabled);

abstract class DesktopRuntimeController {
  DesktopRuntimeCapabilities get capabilities;

  Future<void> sync(AppPreferences preferences);
}

class PlatformDesktopRuntimeController implements DesktopRuntimeController {
  PlatformDesktopRuntimeController({
    DesktopRuntimeCapabilities? capabilities,
    DesktopRuntimeToggle? setPreventSleep,
    DesktopRuntimeToggle? setShowInMenuBar,
  }) : capabilities =
           capabilities ??
           DesktopRuntimeCapabilities(supportsShowInMenuBar: Platform.isMacOS),
       _setPreventSleep = setPreventSleep ?? _togglePreventSleep,
       _setShowInMenuBar = setShowInMenuBar ?? _toggleShowInMenuBar;

  static const MethodChannel _runtimeChannel = MethodChannel(
    'pi.dev/desktop_runtime',
  );

  @override
  final DesktopRuntimeCapabilities capabilities;

  final DesktopRuntimeToggle _setPreventSleep;
  final DesktopRuntimeToggle _setShowInMenuBar;

  bool? _lastPreventSleep;
  bool? _lastShowInMenuBar;

  @override
  Future<void> sync(AppPreferences preferences) async {
    await _syncShowInMenuBar(preferences.showInMenuBar);
    await _syncPreventSleep(preferences.preventSleep);
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
}

class MemoryDesktopRuntimeController implements DesktopRuntimeController {
  MemoryDesktopRuntimeController({DesktopRuntimeCapabilities? capabilities})
    : capabilities =
          capabilities ??
          const DesktopRuntimeCapabilities(supportsShowInMenuBar: true);

  @override
  final DesktopRuntimeCapabilities capabilities;

  AppPreferences? lastSyncedPreferences;
  int syncCount = 0;

  @override
  Future<void> sync(AppPreferences preferences) async {
    lastSyncedPreferences = preferences;
    syncCount += 1;
  }
}
