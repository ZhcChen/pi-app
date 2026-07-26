part of 'desktop_shell.dart';

class PiDesktopApp extends StatefulWidget {
  const PiDesktopApp({
    super.key,
    this.enablePersistence = true,
    this.preferencesStore,
    this.runtimeController,
  });

  final bool enablePersistence;
  final DesktopPreferencesStore? preferencesStore;
  final DesktopRuntimeController? runtimeController;

  @override
  State<PiDesktopApp> createState() => _PiDesktopAppState();
}

class _PiDesktopAppState extends State<PiDesktopApp> {
  late final DesktopPreferencesStore _preferencesStore =
      widget.preferencesStore ?? FileDesktopPreferencesStore();
  late final DesktopRuntimeController _runtimeController =
      widget.runtimeController ?? PlatformDesktopRuntimeController();

  AppPreferences _preferences = const AppPreferences();

  @override
  void initState() {
    super.initState();
    _syncRuntime(_preferences);
    if (widget.enablePersistence) {
      _loadPersistedPreferences();
    }
  }

  Future<void> _syncRuntime(AppPreferences preferences) async {
    await _runtimeController.sync(preferences);
  }

  Future<void> _loadPersistedPreferences() async {
    final preferences = await _preferencesStore.loadPreferences();
    if (!mounted || _samePreferences(preferences, _preferences)) {
      return;
    }

    setState(() {
      _preferences = preferences;
    });
    await _syncRuntime(preferences);
  }

  Future<void> _handlePreferencesChanged(AppPreferences preferences) async {
    if (_samePreferences(preferences, _preferences)) {
      return;
    }

    setState(() {
      _preferences = preferences;
    });

    await _syncRuntime(preferences);

    if (widget.enablePersistence) {
      await _preferencesStore.savePreferences(preferences);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pi Desktop',
      debugShowCheckedModeBanner: false,
      theme: _buildAppTheme(Brightness.light, _preferences),
      darkTheme: _buildAppTheme(Brightness.dark, _preferences),
      themeMode: _themeModeForPreference(_preferences.themeMode),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              _textScaleForUiScale(_preferences.uiScale),
            ),
          ),
          child: child,
        );
      },
      home: _PiDesktopShell(
        preferences: _preferences,
        onPreferencesChanged: _handlePreferencesChanged,
      ),
    );
  }
}

bool _samePreferences(AppPreferences a, AppPreferences b) {
  return a.language == b.language &&
      a.themeMode == b.themeMode &&
      a.uiScale == b.uiScale &&
      a.interfaceDensity == b.interfaceDensity &&
      a.codeFont == b.codeFont &&
      a.openDestination == b.openDestination &&
      a.defaultPermissions == b.defaultPermissions &&
      a.autoReview == b.autoReview &&
      a.fullAccess == b.fullAccess &&
      a.showInMenuBar == b.showInMenuBar &&
      a.showBottomPanel == b.showBottomPanel &&
      a.preventSleep == b.preventSleep &&
      a.suggestedPrompts == b.suggestedPrompts;
}

class _PiDesktopShell extends StatefulWidget {
  const _PiDesktopShell({
    required this.preferences,
    required this.onPreferencesChanged,
  });

  final AppPreferences preferences;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  @override
  State<_PiDesktopShell> createState() => _PiDesktopShellState();
}

class _PiDesktopShellState extends State<_PiDesktopShell> {
  final TextEditingController _settingsSearchController =
      TextEditingController();

  _DesktopRoute _route = _DesktopRoute.workspace;
  SettingsCategory _selectedSettingsCategory = SettingsCategory.general;
  int _selectedActionIndex = 0;
  int _selectedProjectIndex = 0;

  WorkspaceProjectGroup get _selectedProject =>
      desktopProjects[_selectedProjectIndex];
  AppCopy get _copy => AppCopy(widget.preferences.language);
  String get _settingsSearchQuery => _settingsSearchController.text.trim();

  @override
  void initState() {
    super.initState();
    _settingsSearchController.addListener(_onSettingsSearchChanged);
  }

  @override
  void dispose() {
    _settingsSearchController
      ..removeListener(_onSettingsSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSettingsSearchChanged() {
    setState(() {});
  }

  void _openSettings() {
    setState(() {
      _route = _DesktopRoute.settings;
    });
  }

  void _backToWorkspace() {
    setState(() {
      _route = _DesktopRoute.workspace;
    });
  }

  void _updatePreferences(AppPreferences next) {
    widget.onPreferencesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_route) {
        _DesktopRoute.workspace => _buildWorkspaceShell(),
        _DesktopRoute.settings => _buildSettingsShell(),
      },
    );
  }

  Widget _buildWorkspaceShell() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final palette = context.appPalette;
        final sidebarWidth = constraints.maxWidth >= 1540 ? 318.0 : 296.0;
        final actions = buildPrimaryActions(_copy);
        final promptCards = widget.preferences.suggestedPrompts
            ? buildPromptCards(_copy)
            : const <WorkspacePromptCard>[];

        return Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: WorkspaceSidebar(
                copy: _copy,
                actions: actions,
                projects: desktopProjects,
                preferences: widget.preferences,
                selectedActionIndex: _selectedActionIndex,
                selectedProjectIndex: _selectedProjectIndex,
                onActionSelected: (index) {
                  setState(() {
                    _selectedActionIndex = index;
                  });
                },
                onProjectSelected: (index) {
                  setState(() {
                    _selectedProjectIndex = index;
                  });
                },
                onOpenSettings: _openSettings,
              ),
            ),
            Container(width: 1, color: palette.divider),
            Expanded(
              child: WorkspaceCanvas(
                copy: _copy,
                preferences: widget.preferences,
                project: _selectedProject,
                promptCards: promptCards,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsShell() {
    final sections = buildSettingsSections(_copy);
    final filteredSections = filterSettingsSections(
      sections,
      _settingsSearchQuery,
    );

    return SettingsView(
      copy: _copy,
      preferences: widget.preferences,
      searchController: _settingsSearchController,
      sections: filteredSections,
      selectedCategory: _selectedSettingsCategory,
      onCategorySelected: (category) {
        setState(() {
          _selectedSettingsCategory = category;
        });
      },
      onBackToApp: _backToWorkspace,
      onLanguageChanged: (language) {
        _updatePreferences(widget.preferences.copyWith(language: language));
      },
      onThemeModeChanged: (themeMode) {
        _updatePreferences(widget.preferences.copyWith(themeMode: themeMode));
      },
      onUiScaleChanged: (scale) {
        _updatePreferences(widget.preferences.copyWith(uiScale: scale));
      },
      onInterfaceDensityChanged: (density) {
        _updatePreferences(
          widget.preferences.copyWith(interfaceDensity: density),
        );
      },
      onCodeFontChanged: (codeFont) {
        _updatePreferences(widget.preferences.copyWith(codeFont: codeFont));
      },
      onOpenDestinationChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(openDestination: value));
      },
      onDefaultPermissionsChanged: (value) {
        _updatePreferences(
          widget.preferences.copyWith(defaultPermissions: value),
        );
      },
      onAutoReviewChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(autoReview: value));
      },
      onFullAccessChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(fullAccess: value));
      },
      onShowInMenuBarChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(showInMenuBar: value));
      },
      onShowBottomPanelChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(showBottomPanel: value));
      },
      onPreventSleepChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(preventSleep: value));
      },
      onSuggestedPromptsChanged: (value) {
        _updatePreferences(
          widget.preferences.copyWith(suggestedPrompts: value),
        );
      },
      onShowLicenses: () {
        showLicensePage(
          context: context,
          applicationName: 'Pi Desktop',
          applicationVersion: '1.0.0',
        );
      },
    );
  }
}
