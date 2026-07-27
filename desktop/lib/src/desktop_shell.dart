import 'package:flutter/material.dart';

import 'app_copy.dart';
import 'app_data.dart';
import 'app_persistence.dart';
import 'app_preferences.dart';
import 'app_runtime.dart';
import 'desktop_design.dart';
import 'pi_config_store.dart';
import 'settings_feature.dart';
import 'workspace_feature.dart';

class PiDesktopApp extends StatefulWidget {
  const PiDesktopApp({
    super.key,
    this.enablePersistence = true,
    this.preferencesStore,
    this.runtimeController,
    this.piConfigStore,
    this.workspaceRootPath,
  });

  final bool enablePersistence;
  final DesktopPreferencesStore? preferencesStore;
  final DesktopRuntimeController? runtimeController;
  final PiConfigStore? piConfigStore;
  final String? workspaceRootPath;

  @override
  State<PiDesktopApp> createState() => _PiDesktopAppState();
}

class _PiDesktopAppState extends State<PiDesktopApp> {
  late final DesktopPreferencesStore _preferencesStore =
      widget.preferencesStore ?? FileDesktopPreferencesStore();
  late final DesktopRuntimeController _runtimeController =
      widget.runtimeController ?? PlatformDesktopRuntimeController();
  late final PiConfigStore _piConfigStore =
      widget.piConfigStore ?? FilePiConfigStore();

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
      theme: buildDesktopTheme(Brightness.light, _preferences),
      darkTheme: buildDesktopTheme(Brightness.dark, _preferences),
      themeMode: desktopThemeModeForPreference(_preferences.themeMode),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              desktopTextScaleForUiScale(_preferences.uiScale),
            ),
          ),
          child: child,
        );
      },
      home: _PiDesktopShell(
        preferences: _preferences,
        runtimeCapabilities: _runtimeController.capabilities,
        runtimeController: _runtimeController,
        piConfigStore: _piConfigStore,
        workspaceRootPath: widget.workspaceRootPath,
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

enum _DesktopRoute { workspace, settings }

class _PiDesktopShell extends StatefulWidget {
  const _PiDesktopShell({
    required this.preferences,
    required this.runtimeCapabilities,
    required this.runtimeController,
    required this.piConfigStore,
    required this.workspaceRootPath,
    required this.onPreferencesChanged,
  });

  final AppPreferences preferences;
  final DesktopRuntimeCapabilities runtimeCapabilities;
  final DesktopRuntimeController runtimeController;
  final PiConfigStore piConfigStore;
  final String? workspaceRootPath;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  @override
  State<_PiDesktopShell> createState() => _PiDesktopShellState();
}

class _PiDesktopShellState extends State<_PiDesktopShell> {
  final TextEditingController _settingsSearchController =
      TextEditingController();
  final TextEditingController _composerController = TextEditingController();

  PiConfigSnapshot? _piConfigSnapshot;
  String? _piConfigLoadError;
  WorkspacePreparedTask? _preparedTask;

  _DesktopRoute _route = _DesktopRoute.workspace;
  SettingsCategory _selectedSettingsCategory = SettingsCategory.general;
  int _selectedActionIndex = 0;
  int _selectedProjectIndex = 0;
  late List<WorkspaceProjectGroup> _projects;

  WorkspaceProjectGroup? get _selectedProject {
    if (_projects.isEmpty) {
      return null;
    }

    final index = _selectedProjectIndex.clamp(0, _projects.length - 1);
    return _projects[index];
  }

  AppCopy get _copy => AppCopy(widget.preferences.language);
  String get _settingsSearchQuery => _settingsSearchController.text.trim();
  WorkspacePreparedTask? get _visiblePreparedTask {
    final preparedTask = _preparedTask;
    final selectedProject = _selectedProject;
    if (preparedTask == null || selectedProject?.sessionCwd == null) {
      return null;
    }

    return preparedTask.sessionCwd == selectedProject!.sessionCwd
        ? preparedTask
        : null;
  }

  @override
  void initState() {
    super.initState();
    _projects = buildDesktopProjects(widget.workspaceRootPath);
    _settingsSearchController.addListener(_onSettingsSearchChanged);
    _loadPiConfig();
  }

  @override
  void didUpdateWidget(covariant _PiDesktopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceRootPath != widget.workspaceRootPath) {
      _refreshProjects();
    }
  }

  @override
  void dispose() {
    _settingsSearchController
      ..removeListener(_onSettingsSearchChanged)
      ..dispose();
    _composerController.dispose();
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

  void _refreshProjects() {
    final projects = buildDesktopProjects(widget.workspaceRootPath);
    setState(() {
      _projects = projects;
      if (_projects.isEmpty) {
        _selectedProjectIndex = 0;
      } else if (_selectedProjectIndex >= _projects.length) {
        _selectedProjectIndex = _projects.length - 1;
      }
    });
  }

  Future<void> _loadPiConfig() async {
    try {
      final snapshot = await widget.piConfigStore.loadSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _piConfigSnapshot = snapshot;
        _piConfigLoadError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _piConfigLoadError = error.toString();
      });
    }
  }

  Future<void> _savePromptFile(PiPromptFileKind kind, String content) async {
    try {
      final snapshot = await widget.piConfigStore.savePromptFile(kind, content);
      if (!mounted) {
        return;
      }
      setState(() {
        _piConfigSnapshot = snapshot;
        _piConfigLoadError = null;
      });
      _showNotice(_copy.piConfigSavedNotice);
    } catch (error) {
      _showNotice(_copy.piConfigSaveFailedNotice(error.toString()));
    }
  }

  Future<void> _saveModelPreferences(PiModelPreferences preferences) async {
    try {
      final snapshot = await widget.piConfigStore.saveModelPreferences(
        preferences,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _piConfigSnapshot = snapshot;
        _piConfigLoadError = null;
      });
      _showNotice(_copy.piConfigSavedNotice);
    } catch (error) {
      _showNotice(_copy.piConfigSaveFailedNotice(error.toString()));
    }
  }

  Future<void> _saveModelsJson(String content) async {
    try {
      final snapshot = await widget.piConfigStore.saveModelsJson(content);
      if (!mounted) {
        return;
      }
      setState(() {
        _piConfigSnapshot = snapshot;
        _piConfigLoadError = null;
      });
      _showNotice(_copy.piConfigSavedNotice);
    } catch (error) {
      _showNotice(_copy.piConfigSaveFailedNotice(error.toString()));
    }
  }

  Future<void> _openProject(WorkspaceProjectGroup project) async {
    await _openTarget(
      targetPath: project.workspacePath,
      workspacePath: project.workspacePath,
    );
  }

  void _submitComposerTask() {
    final project = _selectedProject;
    final sessionCwd = project?.sessionCwd;
    if (project == null || sessionCwd == null || sessionCwd.isEmpty) {
      _showNotice(_copy.composerNoProjectNotice);
      return;
    }

    final prompt = _composerController.text.trim();
    if (prompt.isEmpty) {
      _showNotice(_copy.composerEmptyTaskNotice);
      return;
    }

    setState(() {
      _preparedTask = WorkspacePreparedTask(
        projectName: project.name,
        prompt: prompt,
        sessionCwd: sessionCwd,
      );
    });
    _composerController.clear();
    _showNotice(_copy.composerPreparedNotice(project.name));
  }

  Future<void> _openProjectItem(
    WorkspaceProjectGroup project,
    WorkspaceProjectItem item,
  ) async {
    await _openTarget(
      targetPath: item.targetPath,
      workspacePath: project.workspacePath,
    );
  }

  Future<void> _openTarget({
    required String? targetPath,
    required String? workspacePath,
  }) async {
    if (targetPath == null) {
      _showNotice(_copy.openTargetUnavailableLabel);
      return;
    }

    final result = await widget.runtimeController.openTarget(
      DesktopOpenRequest(
        destination: widget.preferences.openDestination,
        targetPath: targetPath,
        workspacePath: workspacePath,
      ),
    );

    if (!mounted || result.launched) {
      return;
    }

    _showNotice(
      _copy.openFailedMessage(
        widget.preferences.openDestination,
        result.errorMessage ?? 'Unknown error.',
      ),
    );
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        final palette = context.desktopPalette;
        final sidebarWidth = constraints.maxWidth >= 1540 ? 318.0 : 296.0;
        final actions = buildPrimaryActions(_copy);
        final promptCards = widget.preferences.suggestedPrompts
            ? buildPromptCards(_copy)
            : const <WorkspacePromptCard>[];
        final selectedProject = _selectedProject;

        return Row(
          children: [
            SizedBox(
              width: sidebarWidth,
              child: WorkspaceSidebar(
                copy: _copy,
                actions: actions,
                projects: _projects,
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
                onOpenProject: _openProject,
                onOpenProjectItem: _openProjectItem,
                onOpenSettings: _openSettings,
              ),
            ),
            Container(width: 1, color: palette.divider),
            Expanded(
              child: WorkspaceCanvas(
                copy: _copy,
                preferences: widget.preferences,
                project: selectedProject,
                promptCards: promptCards,
                composerController: _composerController,
                preparedTask: _visiblePreparedTask,
                onSubmitTask: _submitComposerTask,
                onOpenProject: selectedProject == null
                    ? null
                    : () => _openProject(selectedProject),
                onOpenProjectItem: selectedProject == null
                    ? null
                    : (item) => _openProjectItem(selectedProject, item),
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
      runtimeCapabilities: widget.runtimeCapabilities,
      piConfigSnapshot: _piConfigSnapshot,
      piConfigLoadError: _piConfigLoadError,
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
      onSavePromptFile: _savePromptFile,
      onSaveModelPreferences: _saveModelPreferences,
      onSaveModelsJson: _saveModelsJson,
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
