import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'app_persistence.dart';
import 'app_runtime.dart';
import 'desktop_design.dart';
import 'settings_feature.dart';
import 'workspace_feature.dart';

part 'app_models.dart';
part 'app_copy.dart';
part 'app_data.dart';
part 'desktop_app.dart';

extension _DesktopShellThemeLookup on BuildContext {
  DesktopPalette get appPalette => desktopPalette;
}

ThemeMode _themeModeForPreference(AppThemeMode themeMode) {
  return desktopThemeModeForPreference(themeMode);
}

ThemeData _buildAppTheme(Brightness brightness, AppPreferences preferences) {
  return buildDesktopTheme(brightness, preferences);
}

double _textScaleForUiScale(AppUiScale scale) {
  return desktopTextScaleForUiScale(scale);
}
