enum AppLanguage { english, simplifiedChinese }

enum AppThemeMode { dark, light, system }

enum AppUiScale { small, regular, large }

enum AppInterfaceDensity { compact, comfortable }

enum AppCodeFont { jetBrainsMono, systemMono }

enum AppOpenDestination { vscode, cursor, terminal }

class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.english,
    this.themeMode = AppThemeMode.dark,
    this.uiScale = AppUiScale.regular,
    this.interfaceDensity = AppInterfaceDensity.comfortable,
    this.codeFont = AppCodeFont.jetBrainsMono,
    this.openDestination = AppOpenDestination.vscode,
    this.defaultPermissions = true,
    this.autoReview = true,
    this.fullAccess = true,
    this.showInMenuBar = true,
    this.showBottomPanel = false,
    this.preventSleep = false,
    this.suggestedPrompts = true,
    this.projectPaths = const <String>[],
  });

  final AppLanguage language;
  final AppThemeMode themeMode;
  final AppUiScale uiScale;
  final AppInterfaceDensity interfaceDensity;
  final AppCodeFont codeFont;
  final AppOpenDestination openDestination;
  final bool defaultPermissions;
  final bool autoReview;
  final bool fullAccess;
  final bool showInMenuBar;
  final bool showBottomPanel;
  final bool preventSleep;
  final bool suggestedPrompts;
  final List<String> projectPaths;

  AppPreferences copyWith({
    AppLanguage? language,
    AppThemeMode? themeMode,
    AppUiScale? uiScale,
    AppInterfaceDensity? interfaceDensity,
    AppCodeFont? codeFont,
    AppOpenDestination? openDestination,
    bool? defaultPermissions,
    bool? autoReview,
    bool? fullAccess,
    bool? showInMenuBar,
    bool? showBottomPanel,
    bool? preventSleep,
    bool? suggestedPrompts,
    List<String>? projectPaths,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      uiScale: uiScale ?? this.uiScale,
      interfaceDensity: interfaceDensity ?? this.interfaceDensity,
      codeFont: codeFont ?? this.codeFont,
      openDestination: openDestination ?? this.openDestination,
      defaultPermissions: defaultPermissions ?? this.defaultPermissions,
      autoReview: autoReview ?? this.autoReview,
      fullAccess: fullAccess ?? this.fullAccess,
      showInMenuBar: showInMenuBar ?? this.showInMenuBar,
      showBottomPanel: showBottomPanel ?? this.showBottomPanel,
      preventSleep: preventSleep ?? this.preventSleep,
      suggestedPrompts: suggestedPrompts ?? this.suggestedPrompts,
      projectPaths: projectPaths ?? this.projectPaths,
    );
  }
}
