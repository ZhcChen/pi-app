import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'src/desktop_shell.dart';

export 'src/app_preferences.dart';
export 'src/app_persistence.dart';
export 'src/app_runtime.dart';
export 'src/desktop_design.dart';
export 'src/desktop_primitives.dart';
export 'src/workspace_feature.dart';
export 'src/settings_feature.dart';
export 'src/desktop_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _prepareDesktopWindow();
  runApp(const PiDesktopApp());
}

Future<void> _prepareDesktopWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    title: 'Pi Desktop',
    minimumSize: Size(1280, 820),
    backgroundColor: Colors.transparent,
  );

  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.maximize();
  });
}
