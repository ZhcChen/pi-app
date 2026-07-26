import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_preferences.dart';

abstract class DesktopRuntimeController {
  Future<void> sync(AppPreferences preferences);
}

class PlatformDesktopRuntimeController implements DesktopRuntimeController {
  bool? _lastPreventSleep;

  @override
  Future<void> sync(AppPreferences preferences) async {
    if (_lastPreventSleep == preferences.preventSleep) {
      return;
    }

    _lastPreventSleep = preferences.preventSleep;

    try {
      await WakelockPlus.toggle(enable: preferences.preventSleep);
    } catch (_) {}
  }
}

class MemoryDesktopRuntimeController implements DesktopRuntimeController {
  AppPreferences? lastSyncedPreferences;
  int syncCount = 0;

  @override
  Future<void> sync(AppPreferences preferences) async {
    lastSyncedPreferences = preferences;
    syncCount += 1;
  }
}
