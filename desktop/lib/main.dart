import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/desktop_shell.dart';

export 'src/app_preferences.dart';
export 'src/app_persistence.dart';
export 'src/app_runtime.dart';
export 'src/desktop_design.dart';
export 'src/desktop_primitives.dart';
export 'src/pi_config_store.dart';
export 'src/project_registry_store.dart';
export 'src/workspace_feature.dart';
export 'src/settings_feature.dart';
export 'src/desktop_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _prepareDesktopWindow();
  runApp(PiDesktopApp(workspaceRootPath: _defaultWorkspaceRootPath()));
}

String? _defaultWorkspaceRootPath() {
  final configured = Platform.environment['PI_WORKSPACE_ROOT'];
  if (configured != null && configured.isNotEmpty) {
    return configured;
  }

  try {
    final currentDirectory = Directory.current;
    if (currentDirectory.path.endsWith('${Platform.pathSeparator}desktop')) {
      return currentDirectory.parent.path;
    }
  } catch (_) {}

  return null;
}

Future<void> _prepareDesktopWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    title: 'Pi App',
    minimumSize: Size(1280, 820),
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });
}
