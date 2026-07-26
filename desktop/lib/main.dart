import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

part 'src/app_models.dart';
part 'src/app_copy.dart';
part 'src/app_theme.dart';
part 'src/app_data.dart';
part 'src/app_persistence.dart';
part 'src/app_runtime.dart';
part 'src/desktop_app.dart';
part 'src/workspace_view.dart';
part 'src/settings_view.dart';

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
