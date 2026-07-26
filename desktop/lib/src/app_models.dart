part of '../main.dart';

enum AppLanguage { english, simplifiedChinese }

enum AppThemeMode { dark, light, system }

enum AppUiScale { small, regular, large }

enum AppInterfaceDensity { compact, comfortable }

enum AppCodeFont { jetBrainsMono, systemMono }

enum AppOpenDestination { vscode, cursor, terminal }

enum _DesktopRoute { workspace, settings }

enum _SettingsCategory {
  general,
  appearance,
  voice,
  configuration,
  personalization,
  pets,
  keyboardShortcuts,
  account,
  appshots,
  plugins,
  browser,
  computerUse,
  hooks,
  connections,
  git,
  environments,
  worktrees,
  archivedTasks,
}

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
    );
  }
}

class _SidebarAction {
  const _SidebarAction({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _ProjectGroup {
  const _ProjectGroup({
    required this.name,
    required this.branch,
    required this.items,
  });

  final String name;
  final String branch;
  final List<String> items;
}

class _PromptCard {
  const _PromptCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

class _SettingsNavSection {
  const _SettingsNavSection({required this.label, required this.items});

  final String label;
  final List<_SettingsNavItem> items;
}

class _SettingsNavItem {
  const _SettingsNavItem({
    required this.category,
    required this.label,
    required this.icon,
    this.external = false,
  });

  final _SettingsCategory category;
  final String label;
  final IconData icon;
  final bool external;
}

class _DropdownEntry<T> {
  const _DropdownEntry({required this.value, required this.label});

  final T value;
  final String label;
}
