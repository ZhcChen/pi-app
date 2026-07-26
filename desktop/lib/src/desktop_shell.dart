import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'app_persistence.dart';
import 'app_runtime.dart';
import 'desktop_design.dart';
import 'desktop_primitives.dart';
import 'workspace_feature.dart';

part 'app_models.dart';
part 'app_copy.dart';
part 'app_data.dart';
part 'desktop_app.dart';
part 'settings_view.dart';
part 'settings_components.dart';

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

double _densityValue(
  AppInterfaceDensity density, {
  required double compact,
  required double comfortable,
}) {
  return desktopDensityValue(
    density,
    compact: compact,
    comfortable: comfortable,
  );
}

TextStyle _withCodeFont(TextStyle base, AppCodeFont codeFont) {
  return desktopWithCodeFont(base, codeFont);
}

typedef _AppTypography = DesktopTypography;
typedef _DesktopSurface = DesktopSurface;
typedef _DesktopFieldSurface = DesktopFieldSurface;
typedef _DesktopTextActionButton = DesktopTextActionButton;
typedef _DesktopSelectionTile = DesktopSelectionTile;
