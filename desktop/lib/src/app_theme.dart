part of 'desktop_shell.dart';

class _AppPalette {
  const _AppPalette({
    required this.canvas,
    required this.sidebar,
    required this.settingsSidebar,
    required this.panel,
    required this.panelRaised,
    required this.composerShell,
    required this.composerInput,
    required this.settingsField,
    required this.selection,
    required this.divider,
    required this.dividerLight,
    required this.dividerSoft,
    required this.dividerStrong,
    required this.accent,
    required this.switchActive,
    required this.switchInactive,
    required this.textStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color canvas;
  final Color sidebar;
  final Color settingsSidebar;
  final Color panel;
  final Color panelRaised;
  final Color composerShell;
  final Color composerInput;
  final Color settingsField;
  final Color selection;
  final Color divider;
  final Color dividerLight;
  final Color dividerSoft;
  final Color dividerStrong;
  final Color accent;
  final Color switchActive;
  final Color switchInactive;
  final Color textStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
}

const _darkPalette = _AppPalette(
  canvas: Color(0xFF181818),
  sidebar: Color(0xFF242424),
  settingsSidebar: Color(0xFF252525),
  panel: Color(0xFF191919),
  panelRaised: Color(0xFF232323),
  composerShell: Color(0xFF232323),
  composerInput: Color(0xFF343434),
  settingsField: Color(0xFF2C2C2C),
  selection: Color(0xFF3A3A3A),
  divider: Color(0xFF303030),
  dividerLight: Color(0xFF353535),
  dividerSoft: Color(0xFF2E2E2E),
  dividerStrong: Color(0xFF4A4A4A),
  accent: Color(0xFFB47CFF),
  switchActive: Color(0xFF2C96FF),
  switchInactive: Color(0xFF4A4A4A),
  textStrong: Color(0xFFF1F1F1),
  textPrimary: Color(0xFFE2E2E2),
  textSecondary: Color(0xFFC3C3C3),
  textMuted: Color(0xFF8C8C8C),
);

const _lightPalette = _AppPalette(
  canvas: Color(0xFFF5F7FA),
  sidebar: Color(0xFFEDEFF3),
  settingsSidebar: Color(0xFFF0F2F5),
  panel: Color(0xFFFFFFFF),
  panelRaised: Color(0xFFFFFFFF),
  composerShell: Color(0xFFEFF2F6),
  composerInput: Color(0xFFFFFFFF),
  settingsField: Color(0xFFF7F9FB),
  selection: Color(0xFFE1E6ED),
  divider: Color(0xFFD6DCE3),
  dividerLight: Color(0xFFDCE2E8),
  dividerSoft: Color(0xFFE7ECF1),
  dividerStrong: Color(0xFFB7C0CB),
  accent: Color(0xFF8A5FF6),
  switchActive: Color(0xFF2C96FF),
  switchInactive: Color(0xFFBCC4CF),
  textStrong: Color(0xFF111418),
  textPrimary: Color(0xFF232831),
  textSecondary: Color(0xFF5D6774),
  textMuted: Color(0xFF8792A0),
);

_AppPalette _paletteForBrightness(Brightness brightness) {
  return brightness == Brightness.dark ? _darkPalette : _lightPalette;
}

extension _AppThemeLookup on BuildContext {
  _AppPalette get appPalette =>
      _paletteForBrightness(Theme.of(this).brightness);
}

ThemeMode _themeModeForPreference(AppThemeMode themeMode) {
  return switch (themeMode) {
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
  };
}

ThemeData _buildAppTheme(Brightness brightness, AppPreferences preferences) {
  final palette = _paletteForBrightness(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
  );
  final textTheme = _buildAppTextTheme(palette, brightness);

  return ThemeData(
    useMaterial3: true,
    fontFamily: _appFontFamily,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.canvas,
    splashFactory: NoSplash.splashFactory,
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    visualDensity: _visualDensityForDensity(preferences.interfaceDensity),
  );
}

class _AppTypography {
  static TextStyle brandTitle(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static TextStyle brandAccentTitle(_AppPalette palette) => TextStyle(
    color: palette.accent,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );

  static TextStyle heroTitle(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.14,
  );

  static TextStyle promptTitle(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static TextStyle composerInput(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle composerHint(_AppPalette palette) => TextStyle(
    color: palette.textMuted,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle composerTag(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle controlLabel(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle sidebarItem(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle projectItem(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle sectionLabel(_AppPalette palette) => TextStyle(
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsBackLabel(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsSearchText(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsSearchHint(_AppPalette palette) => TextStyle(
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsGroupLabel(_AppPalette palette) => TextStyle(
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsNavItem(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle settingsPageTitle(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    height: 1.15,
  );

  static TextStyle settingsSectionTitle(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static TextStyle settingsRowTitle(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static TextStyle settingsRowDescription(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle settingsDropdownValue(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle placeholderBody(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle previewHeadline(_AppPalette palette) => TextStyle(
    color: palette.textStrong,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static TextStyle previewBody(_AppPalette palette) => TextStyle(
    color: palette.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle codePreview(_AppPalette palette) => TextStyle(
    color: palette.textPrimary,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );
}

TextTheme _buildAppTextTheme(_AppPalette palette, Brightness brightness) {
  final typography = Typography.material2021(platform: defaultTargetPlatform);
  final base = brightness == Brightness.dark
      ? typography.white
      : typography.black;

  return base
      .copyWith(
        bodyLarge: base.bodyLarge?.copyWith(
          color: palette.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          color: palette.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.35,
        ),
        bodySmall: base.bodySmall?.copyWith(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        titleMedium: base.titleMedium?.copyWith(
          color: palette.textStrong,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
        labelLarge: base.labelLarge?.copyWith(
          color: palette.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
        labelMedium: base.labelMedium?.copyWith(
          color: palette.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      )
      .apply(
        fontFamily: _appFontFamily,
        bodyColor: palette.textPrimary,
        displayColor: palette.textStrong,
      );
}

VisualDensity _visualDensityForDensity(AppInterfaceDensity density) {
  return switch (density) {
    AppInterfaceDensity.compact => const VisualDensity(
      horizontal: -2,
      vertical: -2,
    ),
    AppInterfaceDensity.comfortable => VisualDensity.standard,
  };
}

double _textScaleForUiScale(AppUiScale scale) {
  return switch (scale) {
    AppUiScale.small => 0.94,
    AppUiScale.regular => 1.0,
    AppUiScale.large => 1.08,
  };
}

double _densityValue(
  AppInterfaceDensity density, {
  required double compact,
  required double comfortable,
}) {
  return density == AppInterfaceDensity.compact ? compact : comfortable;
}

String _systemMonoFontFamily() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => 'Menlo',
    TargetPlatform.windows => 'Consolas',
    TargetPlatform.linux => 'Liberation Mono',
    _ => 'monospace',
  };
}

TextStyle _withCodeFont(TextStyle base, AppCodeFont codeFont) {
  return switch (codeFont) {
    AppCodeFont.jetBrainsMono => base.copyWith(fontFamily: _codeFontFamily),
    AppCodeFont.systemMono => base.copyWith(
      fontFamily: _systemMonoFontFamily(),
      fontFamilyFallback: const ['DejaVu Sans Mono', 'monospace'],
    ),
  };
}

const _appFontFamily = 'Inter';
const _codeFontFamily = 'JetBrainsMono';
const _piDarkMarkAsset = '../assets/branding/source/dark/pi-mark.svg';
