import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'app_copy.dart';
import 'app_data.dart';
import 'app_persistence.dart';
import 'app_preferences.dart';
import 'app_runtime.dart';
import 'app_update_service.dart';
import 'desktop_design.dart';
import 'pi_config_store.dart';
import 'pi_core_installer.dart';
import 'pi_core_rpc_client.dart';
import 'pi_core_runtime.dart';
import 'pi_host_client.dart';
import 'project_registry_store.dart';
import 'settings_feature.dart';
import 'workspace_feature.dart';

class PiDesktopApp extends StatefulWidget {
  const PiDesktopApp({
    super.key,
    this.enablePersistence = true,
    this.enforcePiCoreRuntimeGate,
    this.preferencesStore,
    this.runtimeController,
    this.piConfigStore,
    this.piCoreRuntimeController,
    this.piCoreInstallerClient,
    this.piHostClient,
    this.appUpdateClient,
    this.projectRegistryStore,
    this.workspaceRootPath,
    this.pickProjectDirectory,
    this.pickPiCoreExecutable,
  });

  final bool enablePersistence;
  final bool? enforcePiCoreRuntimeGate;
  final DesktopPreferencesStore? preferencesStore;
  final DesktopRuntimeController? runtimeController;
  final PiConfigStore? piConfigStore;
  final PiCoreRuntimeController? piCoreRuntimeController;
  final PiCoreInstallerClient? piCoreInstallerClient;
  final PiHostClient? piHostClient;
  final AppUpdateClient? appUpdateClient;
  final ProjectRegistryStore? projectRegistryStore;
  final String? workspaceRootPath;
  final Future<String?> Function()? pickProjectDirectory;
  final Future<String?> Function()? pickPiCoreExecutable;

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
  late final PiCoreRuntimeController _piCoreRuntimeController =
      widget.piCoreRuntimeController ?? PiCoreRuntimeController();
  late final PiCoreInstallerClient _piCoreInstallerClient =
      widget.piCoreInstallerClient ?? OfficialPiCoreInstallerClient();
  late final PiHostClient _piHostClient =
      widget.piHostClient ??
      PiCoreRpcClient(
        executableResolver: _piCoreRuntimeController.resolveExecutableOverride,
        runtimeGate: _piCoreRuntimeController.ensureReady,
      );
  late final AppUpdateClient _appUpdateClient =
      widget.appUpdateClient ?? GitHubAppUpdateClient();
  late final ProjectRegistryStore _projectRegistryStore =
      widget.projectRegistryStore ?? FileProjectRegistryStore();

  // 持久化设置异步加载；在解析出保存策略或新安装默认值前保持受限。
  AppPreferences _preferences = const AppPreferences(
    toolPolicySource: AppToolPolicySource.bootstrapRestricted,
    defaultPermissions: false,
    fullAccess: false,
  );

  @override
  void initState() {
    super.initState();
    _piCoreRuntimeController.addListener(_onPiCoreRuntimeChanged);
    if (widget.enablePersistence) {
      _syncRuntime(_preferences);
      _loadPersistedPreferences();
      return;
    }
    _preferences = const AppPreferences();
    _syncRuntime(_preferences);
  }

  Future<void> _syncRuntime(AppPreferences preferences) async {
    _piCoreRuntimeController.configure(preferences.piCoreExecutablePath);
    await _runtimeController.sync(preferences);
  }

  void _onPiCoreRuntimeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _choosePiCoreExecutable() async {
    final picker = widget.pickPiCoreExecutable ?? _pickPiCoreExecutable;
    String? selectedPath;
    try {
      selectedPath = await picker();
    } catch (_) {
      return;
    }
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    await _handlePreferencesChanged(
      _preferences.copyWith(piCoreExecutablePath: selectedPath.trim()),
    );
    await _piCoreRuntimeController.refresh();
  }

  Future<void> _clearPiCoreExecutable() async {
    await _handlePreferencesChanged(
      _preferences.copyWith(clearPiCoreExecutablePath: true),
    );
    await _piCoreRuntimeController.refresh();
  }

  @override
  void dispose() {
    _piCoreRuntimeController.removeListener(_onPiCoreRuntimeChanged);
    if (widget.piCoreRuntimeController == null) {
      _piCoreRuntimeController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPersistedPreferences() async {
    final preferences = await _preferencesStore.loadPreferences();
    if (!mounted || _samePreferences(preferences, _preferences)) {
      return;
    }
    final shouldRefreshPiCoreRuntime =
        preferences.piCoreExecutablePath != _preferences.piCoreExecutablePath;

    setState(() {
      _preferences = preferences;
    });
    await _syncRuntime(preferences);
    if (shouldRefreshPiCoreRuntime && widget.piCoreRuntimeController != null) {
      await _piCoreRuntimeController.refresh();
    }
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
      title: piAppDisplayName(),
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
        piCoreRuntimeController: _piCoreRuntimeController,
        piCoreRuntimeSnapshot: _piCoreRuntimeController.snapshot,
        onRefreshPiCoreRuntime: _piCoreRuntimeController.refresh,
        onChoosePiCoreExecutable: _choosePiCoreExecutable,
        onClearPiCoreExecutable: _clearPiCoreExecutable,
        piCoreInstallerClient: _piCoreInstallerClient,
        piHostClient: _piHostClient,
        enforcePiCoreRuntimeGate:
            widget.enforcePiCoreRuntimeGate ?? widget.piHostClient == null,
        appUpdateClient: _appUpdateClient,
        ownsPiHostClient: widget.piHostClient == null,
        projectRegistryStore: _projectRegistryStore,
        enableProjectPersistence: widget.enablePersistence,
        workspaceRootPath: widget.workspaceRootPath,
        pickProjectDirectory:
            widget.pickProjectDirectory ?? _pickProjectDirectory,
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
      a.piCoreExecutablePath == b.piCoreExecutablePath &&
      a.toolPolicySource == b.toolPolicySource &&
      a.defaultPermissions == b.defaultPermissions &&
      a.autoReview == b.autoReview &&
      a.fullAccess == b.fullAccess &&
      a.showInMenuBar == b.showInMenuBar &&
      a.showBottomPanel == b.showBottomPanel &&
      a.preventSleep == b.preventSleep &&
      a.suggestedPrompts == b.suggestedPrompts;
}

Future<String?> _pickProjectDirectory() async {
  return getDirectoryPath();
}

Future<String?> _pickPiCoreExecutable() async {
  final executable = await openFile();
  return executable?.path;
}

enum _DesktopRoute { workspace, settings }

enum _ToolPolicyUpgradeChoice { authorize, keepRestricted }

enum _PiCoreRepairChoice { refresh, openSettings }

const Duration _piCoreInstallerPollInterval = Duration(seconds: 2);

class _PiDesktopShell extends StatefulWidget {
  const _PiDesktopShell({
    required this.preferences,
    required this.runtimeCapabilities,
    required this.runtimeController,
    required this.piConfigStore,
    required this.piCoreRuntimeController,
    required this.piCoreRuntimeSnapshot,
    required this.onRefreshPiCoreRuntime,
    required this.onChoosePiCoreExecutable,
    required this.onClearPiCoreExecutable,
    required this.piCoreInstallerClient,
    required this.piHostClient,
    required this.enforcePiCoreRuntimeGate,
    required this.appUpdateClient,
    required this.ownsPiHostClient,
    required this.projectRegistryStore,
    required this.enableProjectPersistence,
    required this.workspaceRootPath,
    required this.pickProjectDirectory,
    required this.onPreferencesChanged,
  });

  final AppPreferences preferences;
  final DesktopRuntimeCapabilities runtimeCapabilities;
  final DesktopRuntimeController runtimeController;
  final PiConfigStore piConfigStore;
  final PiCoreRuntimeController piCoreRuntimeController;
  final PiCoreRuntimeSnapshot piCoreRuntimeSnapshot;
  final Future<void> Function() onRefreshPiCoreRuntime;
  final Future<void> Function() onChoosePiCoreExecutable;
  final Future<void> Function() onClearPiCoreExecutable;
  final PiCoreInstallerClient piCoreInstallerClient;
  final PiHostClient piHostClient;
  final bool enforcePiCoreRuntimeGate;
  final AppUpdateClient appUpdateClient;
  final bool ownsPiHostClient;
  final ProjectRegistryStore projectRegistryStore;
  final bool enableProjectPersistence;
  final String? workspaceRootPath;
  final Future<String?> Function() pickProjectDirectory;
  final Future<void> Function(AppPreferences) onPreferencesChanged;

  @override
  State<_PiDesktopShell> createState() => _PiDesktopShellState();
}

class _PiDesktopShellState extends State<_PiDesktopShell> {
  final TextEditingController _settingsSearchController =
      TextEditingController();
  final TextEditingController _composerController = TextEditingController();

  PiConfigSnapshot? _piConfigSnapshot;
  String? _piConfigLoadError;
  PiCoreInstallerBundle? _preparedPiCoreInstaller;
  PiCoreInstallerDownloadProgress? _piCoreInstallerDownloadProgress;
  String? _piCoreInstallerError;
  bool _isPreparingPiCoreInstaller = false;
  bool _isWaitingForPiCoreInstaller = false;
  int _piCoreInstallerWaitGeneration = 0;
  int _sessionViewGeneration = 0;
  AppUpdateCheck? _appUpdateCheck;
  AppUpdateDownloadProgress? _appUpdateDownloadProgress;
  File? _downloadedUpdateInstaller;
  String? _appUpdateCurrentVersion;
  String? _appUpdateError;
  bool _isCheckingAppUpdate = false;
  bool _isDownloadingAppUpdate = false;
  final Map<String, WorkspaceSessionState> _sessionsByCwd =
      <String, WorkspaceSessionState>{};
  final Map<String, String> _sessionCwdById = <String, String>{};
  StreamSubscription<PiHostEvent>? _piHostSubscription;
  ProjectRegistrySnapshot _projectRegistry = const ProjectRegistrySnapshot();

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
  PiCoreRuntimeSnapshot get _currentPiCoreRuntimeSnapshot =>
      widget.piCoreRuntimeController.snapshot;
  String get _settingsSearchQuery => _settingsSearchController.text.trim();
  WorkspaceSessionState? get _visibleSession {
    final sessionCwd = _selectedProject?.sessionCwd;
    if (sessionCwd == null || sessionCwd.isEmpty) {
      return null;
    }
    return _sessionsByCwd[sessionCwd];
  }

  @override
  void initState() {
    super.initState();
    _projects = buildDesktopProjects(widget.workspaceRootPath);
    _settingsSearchController.addListener(_onSettingsSearchChanged);
    _piHostSubscription = widget.piHostClient.events.listen(_handlePiHostEvent);
    _loadPiConfig();
    unawaited(_loadAppUpdateCurrentVersion());
    if (widget.enableProjectPersistence) {
      _loadProjectRegistry();
    }
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
    _piHostSubscription?.cancel();
    if (widget.ownsPiHostClient) {
      unawaited(widget.piHostClient.dispose());
    }
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

  void _openSettingsCategory(SettingsCategory category) {
    setState(() {
      _route = _DesktopRoute.settings;
      _selectedSettingsCategory = category;
    });
  }

  void _backToWorkspace() {
    setState(() {
      _route = _DesktopRoute.workspace;
    });
  }

  void _discardProjectSessionRecords() {
    _sessionViewGeneration += 1;
    _sessionsByCwd.clear();
    _sessionCwdById.clear();
  }

  bool _isCurrentSessionView(int generation) {
    return mounted && generation == _sessionViewGeneration;
  }

  Future<void> _selectProject(int index) async {
    if (index < 0 || index >= _projects.length) {
      return;
    }

    final previousSessionCwd = _selectedProject?.sessionCwd;
    final project = _projects[index];
    final nextSessionCwd = project.sessionCwd;
    setState(() {
      _selectedProjectIndex = index;
      if (previousSessionCwd != nextSessionCwd) {
        _discardProjectSessionRecords();
      }
    });
    await _markProjectOpened(project);
  }

  Future<void> _markProjectOpened(WorkspaceProjectGroup project) async {
    if (!widget.enableProjectPersistence) {
      return;
    }

    final entry = _projectRegistry.entryForId(project.registryId);
    if (entry == null) {
      return;
    }

    try {
      final snapshot = await widget.projectRegistryStore.markProjectOpened(
        entry.id,
      );
      if (!mounted) {
        return;
      }
      _applyProjectSnapshot(
        snapshot,
        preferredSelectedPath: project.workspacePath,
      );
    } catch (_) {}
  }

  Future<void> _toggleProjectPinned(WorkspaceProjectGroup project) async {
    final entry = _projectRegistry.entryForId(project.registryId);
    if (entry == null || !widget.enableProjectPersistence) {
      return;
    }

    try {
      final snapshot = await widget.projectRegistryStore.setProjectPinned(
        entry.id,
        !entry.isPinned,
      );
      if (!mounted) {
        return;
      }

      _applyProjectSnapshot(
        snapshot,
        preferredSelectedPath: project.workspacePath,
      );
      _showNotice(
        entry.isPinned
            ? _copy.projectUnpinnedNotice(project.name)
            : _copy.projectPinnedNotice(project.name),
      );
    } catch (error) {
      _showNotice(_copy.projectManageFailedNotice(error.toString()));
    }
  }

  Future<void> _renameProject(
    WorkspaceProjectGroup project,
    String alias,
  ) async {
    final entry = _projectRegistry.entryForId(project.registryId);
    if (entry == null || !widget.enableProjectPersistence) {
      return;
    }

    try {
      final snapshot = await widget.projectRegistryStore.setProjectAlias(
        entry.id,
        alias,
      );
      if (!mounted) {
        return;
      }

      _applyProjectSnapshot(
        snapshot,
        preferredSelectedPath: project.workspacePath,
      );
      final updatedEntry = snapshot.entryForId(entry.id);
      _showNotice(
        _copy.projectRenamedNotice(updatedEntry?.displayName ?? project.name),
      );
    } catch (error) {
      _showNotice(_copy.projectManageFailedNotice(error.toString()));
    }
  }

  Future<void> _removeProject(WorkspaceProjectGroup project) async {
    final entry = _projectRegistry.entryForId(project.registryId);
    if (entry == null || !widget.enableProjectPersistence) {
      return;
    }

    try {
      final snapshot = await widget.projectRegistryStore.removeProject(
        entry.id,
      );
      if (!mounted) {
        return;
      }

      _applyProjectSnapshot(snapshot);
      _showNotice(_copy.projectRemovedNotice(project.name));
    } catch (error) {
      _showNotice(_copy.projectManageFailedNotice(error.toString()));
    }
  }

  Future<void> _persistPreferences(AppPreferences next) {
    return widget.onPreferencesChanged(next);
  }

  void _updatePreferences(AppPreferences next) {
    unawaited(_persistPreferences(next));
  }

  void _refreshProjects({String? preferredSelectedPath}) {
    final currentSelectedPath = _selectedProject?.workspacePath;
    _applyProjectSnapshot(
      _projectRegistry,
      preferredSelectedPath: preferredSelectedPath ?? currentSelectedPath,
    );
  }

  void _applyProjectSnapshot(
    ProjectRegistrySnapshot snapshot, {
    String? preferredSelectedPath,
  }) {
    final previousSessionCwd = _selectedProject?.sessionCwd;
    final projects = buildDesktopProjects(
      widget.workspaceRootPath,
      registeredProjects: snapshot.orderedEntries,
    );

    setState(() {
      _projectRegistry = snapshot;
      _projects = projects;
      if (_projects.isEmpty) {
        _selectedProjectIndex = 0;
        _discardProjectSessionRecords();
        return;
      }

      if (preferredSelectedPath != null) {
        final matchedIndex = _projects.indexWhere(
          (project) => project.workspacePath == preferredSelectedPath,
        );
        if (matchedIndex >= 0) {
          _selectedProjectIndex = matchedIndex;
          final nextSessionCwd = _projects[_selectedProjectIndex].sessionCwd;
          if (previousSessionCwd != nextSessionCwd) {
            _discardProjectSessionRecords();
          }
          return;
        }
      }

      if (_selectedProjectIndex >= _projects.length) {
        _selectedProjectIndex = _projects.length - 1;
      }

      final nextSessionCwd = _projects[_selectedProjectIndex].sessionCwd;
      if (previousSessionCwd != nextSessionCwd) {
        _discardProjectSessionRecords();
      }
    });
  }

  Future<void> _loadProjectRegistry() async {
    try {
      final snapshot = await widget.projectRegistryStore.loadSnapshot();
      if (!mounted) {
        return;
      }
      _applyProjectSnapshot(snapshot);
    } catch (_) {}
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

  Future<void> _installPiCore() async {
    if (_isPreparingPiCoreInstaller || _isWaitingForPiCoreInstaller) {
      return;
    }

    setState(() {
      _isPreparingPiCoreInstaller = true;
      _piCoreInstallerError = null;
      _piCoreInstallerDownloadProgress = null;
      _preparedPiCoreInstaller = null;
    });

    PiCoreInstallerBundle? installer;
    try {
      installer = await widget.piCoreInstallerClient.prepareInstaller(
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _piCoreInstallerDownloadProgress = progress;
          });
        },
      );
      final openResult = await widget.runtimeController.runScriptInTerminal(
        installer.launcherFile.path,
      );
      if (!openResult.launched) {
        throw PiCoreInstallerException(
          openResult.errorMessage ??
              'Could not open Terminal for the Pi installer launcher.',
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingPiCoreInstaller = false;
        _preparedPiCoreInstaller = installer;
      });
      unawaited(_waitForPiCoreInstaller());
    } catch (error) {
      final failedInstaller = installer;
      if (failedInstaller != null) {
        unawaited(
          widget.piCoreInstallerClient.discardInstaller(failedInstaller),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingPiCoreInstaller = false;
        _piCoreInstallerError = _messageForPiCoreInstallerError(error);
      });
    }
  }

  Future<void> _resumeWaitingForPiCoreInstaller() async {
    if (_preparedPiCoreInstaller == null || _isWaitingForPiCoreInstaller) {
      return;
    }
    unawaited(_waitForPiCoreInstaller());
  }

  Future<void> _waitForPiCoreInstaller() async {
    if (_preparedPiCoreInstaller == null) {
      return;
    }

    final waitGeneration = ++_piCoreInstallerWaitGeneration;
    setState(() {
      _isWaitingForPiCoreInstaller = true;
      _piCoreInstallerError = null;
    });

    while (mounted && waitGeneration == _piCoreInstallerWaitGeneration) {
      await widget.onRefreshPiCoreRuntime();
      if (!mounted || waitGeneration != _piCoreInstallerWaitGeneration) {
        return;
      }
      if (_currentPiCoreRuntimeSnapshot.isReady) {
        setState(() {
          _isWaitingForPiCoreInstaller = false;
        });
        return;
      }
      await Future<void>.delayed(_piCoreInstallerPollInterval);
    }
  }

  void _stopWaitingForPiCoreInstaller() {
    if (!_isWaitingForPiCoreInstaller) {
      return;
    }
    _piCoreInstallerWaitGeneration += 1;
    setState(() {
      _isWaitingForPiCoreInstaller = false;
    });
  }

  Future<void> _openPiCoreInstallerLog() async {
    final logFile = _preparedPiCoreInstaller?.logFile;
    if (logFile == null) {
      return;
    }

    final result = await widget.runtimeController.openSystemFile(logFile.path);
    if (result.launched || !mounted) {
      return;
    }

    setState(() {
      _piCoreInstallerError =
          result.errorMessage ?? 'Could not open the Pi installer log.';
    });
  }

  List<String> _hostToolsForPreferences(AppPreferences preferences) {
    if (preferences.fullAccess) {
      return const <String>[
        'read',
        'grep',
        'find',
        'ls',
        'bash',
        'edit',
        'write',
      ];
    }
    if (preferences.defaultPermissions) {
      return const <String>['read', 'grep', 'find', 'ls'];
    }
    return const <String>[];
  }

  bool _needsLegacyToolPolicyUpgrade() {
    return widget.preferences.toolPolicySource ==
        AppToolPolicySource.migratedLegacy;
  }

  Future<AppPreferences?> _resolvePreferencesForNewSession() async {
    if (!_needsLegacyToolPolicyUpgrade()) {
      return widget.preferences;
    }

    final choice = await showDialog<_ToolPolicyUpgradeChoice>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('tool-policy-upgrade-dialog'),
          title: Text(_copy.toolPolicyUpgradeTitle),
          content: Text(_copy.toolPolicyUpgradeDescription),
          actions: [
            TextButton(
              key: const Key('tool-policy-upgrade-cancel-button'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_copy.cancelActionLabel),
            ),
            TextButton(
              key: const Key('tool-policy-upgrade-keep-restricted-button'),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ToolPolicyUpgradeChoice.keepRestricted),
              child: Text(_copy.toolPolicyUpgradeKeepRestrictedActionLabel),
            ),
            FilledButton(
              key: const Key('tool-policy-upgrade-authorize-button'),
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_ToolPolicyUpgradeChoice.authorize),
              child: Text(_copy.toolPolicyUpgradeAuthorizeActionLabel),
            ),
          ],
        );
      },
    );
    if (!mounted || choice == null) {
      return null;
    }

    final updatedPreferences = switch (choice) {
      _ToolPolicyUpgradeChoice.authorize => widget.preferences.copyWith(
        toolPolicySource: AppToolPolicySource.explicit,
        defaultPermissions: true,
        fullAccess: true,
      ),
      _ToolPolicyUpgradeChoice.keepRestricted => widget.preferences.copyWith(
        toolPolicySource: AppToolPolicySource.explicit,
      ),
    };
    await _persistPreferences(updatedPreferences);
    return updatedPreferences;
  }

  Future<bool> _ensureRuntimeReadyForNewSession() async {
    if (_currentPiCoreRuntimeSnapshot.status == PiCoreRuntimeStatus.checking) {
      await widget.onRefreshPiCoreRuntime();
      if (!mounted) {
        return false;
      }
    }

    while (mounted &&
        _currentPiCoreRuntimeSnapshot.status != PiCoreRuntimeStatus.ready) {
      if (!mounted) {
        return false;
      }
      final choice = await showDialog<_PiCoreRepairChoice>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            key: const Key('pi-core-repair-dialog'),
            title: Text(_copy.piCoreRepairTitle),
            content: Text(
              _copy.piCoreRepairDescription(_currentPiCoreRuntimeSnapshot),
            ),
            actions: [
              TextButton(
                key: const Key('pi-core-repair-cancel-button'),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_copy.cancelActionLabel),
              ),
              TextButton(
                key: const Key('pi-core-repair-open-settings-button'),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PiCoreRepairChoice.openSettings),
                child: Text(_copy.openSettingsActionLabel),
              ),
              FilledButton(
                key: const Key('pi-core-repair-refresh-button'),
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_PiCoreRepairChoice.refresh),
                child: Text(_copy.piCoreRepairRefreshActionLabel),
              ),
            ],
          );
        },
      );
      if (!mounted || choice == null) {
        return false;
      }
      if (choice == _PiCoreRepairChoice.openSettings) {
        _openSettingsCategory(SettingsCategory.general);
        return false;
      }
      await widget.onRefreshPiCoreRuntime();
    }

    return mounted;
  }

  WorkspaceSessionState _sessionStateForCwd(String sessionCwd) {
    return _sessionsByCwd[sessionCwd] ??
        WorkspaceSessionState.empty(sessionCwd);
  }

  void _setSessionState(String sessionCwd, WorkspaceSessionState state) {
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionsByCwd[sessionCwd] = state;
    });
  }

  void _applyHostSession(PiHostSession session, {String? projectSessionCwd}) {
    final sessionCwd =
        projectSessionCwd ?? _sessionCwdById[session.id] ?? session.cwd;
    _sessionCwdById[session.id] = sessionCwd;
    final current = _sessionStateForCwd(sessionCwd);
    _setSessionState(
      sessionCwd,
      current.copyWith(
        sessionId: session.id,
        piSessionId: session.piSessionId,
        sessionFile: session.sessionFile,
        sessionName: session.sessionName,
        modelProvider: session.model?.provider,
        modelName: session.model?.name,
        thinkingLevel: session.thinkingLevel,
      ),
    );
  }

  void _resetHostSessions(String message, {String? sessionId}) {
    final affectedSessionCwds = _sessionsByCwd.entries
        .where(
          (entry) =>
              (sessionId == null || entry.value.sessionId == sessionId) &&
              (entry.value.sessionId != null ||
                  entry.value.status == WorkspaceRunStatus.starting ||
                  entry.value.isRunning),
        )
        .map((entry) => entry.key)
        .toList(growable: false);
    if (sessionId == null) {
      _sessionCwdById.clear();
    } else {
      _sessionCwdById.remove(sessionId);
    }
    if (affectedSessionCwds.isEmpty) {
      return;
    }

    setState(() {
      for (final sessionCwd in affectedSessionCwds) {
        final current = _sessionStateForCwd(sessionCwd);
        _sessionsByCwd[sessionCwd] = current.finishAssistantMessage().copyWith(
          clearHostSession: true,
          clearActiveTool: true,
          status: WorkspaceRunStatus.failed,
          errorMessage: message,
        );
      }
    });
    _showNotice(_copy.hostRunFailedNotice(message));
  }

  void _handlePiHostEvent(PiHostEvent event) {
    if (!mounted) {
      return;
    }

    if (event.type == PiHostEventType.hostError) {
      _resetHostSessions(
        event.message ?? 'Pi host is unavailable.',
        sessionId: event.sessionId,
      );
      return;
    }

    final eventSession = event.session;
    if (eventSession != null && _sessionCwdById.containsKey(eventSession.id)) {
      _applyHostSession(eventSession);
    }

    final sessionId = event.sessionId;
    final sessionCwd = sessionId == null ? null : _sessionCwdById[sessionId];
    if (sessionCwd == null) {
      return;
    }

    final current = _sessionStateForCwd(sessionCwd);
    final next = switch (event.type) {
      PiHostEventType.runStarted => current.copyWith(
        status: WorkspaceRunStatus.running,
        clearError: true,
      ),
      PiHostEventType.messageDelta =>
        current
            .withAssistantDelta(event.delta ?? '')
            .copyWith(status: WorkspaceRunStatus.running),
      PiHostEventType.toolStarted => current.copyWith(
        activeToolName: event.data['toolName']?.toString(),
        status: WorkspaceRunStatus.running,
      ),
      PiHostEventType.toolUpdated => current.copyWith(
        status: WorkspaceRunStatus.running,
      ),
      PiHostEventType.toolCompleted => current.copyWith(
        clearActiveTool: true,
        status: WorkspaceRunStatus.running,
      ),
      PiHostEventType.runSettled =>
        current.status == WorkspaceRunStatus.aborted
            ? current.finishAssistantMessage().copyWith(clearActiveTool: true)
            : current.finishAssistantMessage().copyWith(
                status: WorkspaceRunStatus.settled,
                clearActiveTool: true,
              ),
      PiHostEventType.runAborted => current.finishAssistantMessage().copyWith(
        status: WorkspaceRunStatus.aborted,
        clearActiveTool: true,
      ),
      PiHostEventType.runFailed => current.finishAssistantMessage().copyWith(
        status: WorkspaceRunStatus.failed,
        clearActiveTool: true,
        errorMessage: event.message ?? 'Unknown Pi host error.',
      ),
      _ => current,
    };

    if (!identical(next, current)) {
      _setSessionState(sessionCwd, next);
    }
  }

  Future<void> _addProject() async {
    try {
      final pickedPath = await widget.pickProjectDirectory();
      if (!mounted || pickedPath == null) {
        return;
      }

      final normalizedPath = Directory(pickedPath.trim()).absolute.path;
      if (normalizedPath.isEmpty) {
        return;
      }

      final existingEntry = _projectRegistry.entryForPath(normalizedPath);
      if (existingEntry != null) {
        final existingIndex = _projects.indexWhere(
          (project) => project.workspacePath == normalizedPath,
        );
        if (existingIndex >= 0) {
          await _selectProject(existingIndex);
        }
        _showNotice(_copy.projectAlreadyAddedNotice(existingEntry.name));
        return;
      }

      final snapshot = widget.enableProjectPersistence
          ? await widget.projectRegistryStore.addProject(normalizedPath)
          : ProjectRegistrySnapshot(
              entries: <ProjectRegistryEntry>[
                ..._projectRegistry.entries,
                ProjectRegistryEntry.create(normalizedPath),
              ],
            );

      if (!mounted) {
        return;
      }

      _applyProjectSnapshot(snapshot, preferredSelectedPath: normalizedPath);
      _showNotice(
        _copy.projectAddedNotice(_projectNameForPath(normalizedPath)),
      );
    } catch (error) {
      _showNotice(_copy.projectAddFailedNotice(error.toString()));
    }
  }

  Future<void> _openProject(WorkspaceProjectGroup project) async {
    await _openTarget(
      targetPath: project.workspacePath,
      workspacePath: project.workspacePath,
    );
  }

  Future<void> _submitComposerTask() async {
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

    final initialState = _sessionStateForCwd(sessionCwd);
    if (initialState.isRunning) {
      return;
    }

    final existingSessionId = initialState.sessionId;
    final sessionViewGeneration = _sessionViewGeneration;
    var sessionPreferences = widget.preferences;
    if (existingSessionId == null || existingSessionId.isEmpty) {
      final resolvedPreferences = await _resolvePreferencesForNewSession();
      if (!mounted || resolvedPreferences == null) {
        return;
      }
      sessionPreferences = resolvedPreferences;
      if (widget.enforcePiCoreRuntimeGate) {
        final runtimeReady = await _ensureRuntimeReadyForNewSession();
        if (!mounted || !runtimeReady) {
          return;
        }
      }
    }

    _setSessionState(
      sessionCwd,
      initialState
          .withUserPrompt(prompt)
          .copyWith(
            status: existingSessionId == null || existingSessionId.isEmpty
                ? WorkspaceRunStatus.starting
                : WorkspaceRunStatus.waiting,
            clearError: true,
            clearActiveTool: true,
          ),
    );
    _composerController.clear();

    try {
      PiHostSession session;
      if (existingSessionId == null || existingSessionId.isEmpty) {
        session = await widget.piHostClient.createSession(
          cwd: sessionCwd,
          tools: _hostToolsForPreferences(sessionPreferences),
        );
        if (!_isCurrentSessionView(sessionViewGeneration)) {
          return;
        }
        _applyHostSession(session, projectSessionCwd: sessionCwd);
      } else {
        session = await widget.piHostClient.getSessionState(
          sessionId: existingSessionId,
        );
        if (!_isCurrentSessionView(sessionViewGeneration)) {
          return;
        }
        _applyHostSession(session);
      }

      final currentBeforePrompt = _sessionStateForCwd(sessionCwd);
      if (currentBeforePrompt.status == WorkspaceRunStatus.starting) {
        _setSessionState(
          sessionCwd,
          currentBeforePrompt.copyWith(
            status: WorkspaceRunStatus.waiting,
            clearError: true,
          ),
        );
      }

      final accepted = await widget.piHostClient.prompt(
        sessionId: session.id,
        text: prompt,
      );
      if (!_isCurrentSessionView(sessionViewGeneration)) {
        return;
      }
      if (!accepted) {
        _setSessionState(
          sessionCwd,
          _sessionStateForCwd(sessionCwd).copyWith(
            status: WorkspaceRunStatus.failed,
            errorMessage: 'Prompt was rejected before execution.',
          ),
        );
        _showNotice(_copy.composerPromptRejectedNotice('Prompt was rejected.'));
        return;
      }

      final current = _sessionStateForCwd(sessionCwd);
      if (current.status == WorkspaceRunStatus.starting ||
          current.status == WorkspaceRunStatus.waiting) {
        _setSessionState(
          sessionCwd,
          current.copyWith(
            status: WorkspaceRunStatus.waiting,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      if (!_isCurrentSessionView(sessionViewGeneration)) {
        return;
      }
      final message = error.toString();
      _setSessionState(
        sessionCwd,
        _sessionStateForCwd(sessionCwd).copyWith(
          status: WorkspaceRunStatus.failed,
          clearActiveTool: true,
          errorMessage: message,
        ),
      );
      _showNotice(_copy.hostRunFailedNotice(message));
    }
  }

  Future<void> _abortComposerTask() async {
    final project = _selectedProject;
    final sessionCwd = project?.sessionCwd;
    final session = sessionCwd == null ? null : _sessionsByCwd[sessionCwd];
    final sessionId = session?.sessionId;
    if (sessionCwd == null || sessionId == null || !session!.isRunning) {
      return;
    }

    try {
      final updated = await widget.piHostClient.abort(sessionId: sessionId);
      if (!mounted) {
        return;
      }
      _applyHostSession(updated);
      _setSessionState(
        sessionCwd,
        _sessionStateForCwd(sessionCwd).finishAssistantMessage().copyWith(
          status: WorkspaceRunStatus.aborted,
          clearActiveTool: true,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString();
      _setSessionState(
        sessionCwd,
        _sessionStateForCwd(sessionCwd).copyWith(
          status: WorkspaceRunStatus.failed,
          errorMessage: message,
          clearActiveTool: true,
        ),
      );
      _showNotice(_copy.hostRunFailedNotice(message));
    }
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

  String _projectNameForPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final trimmed = normalized.endsWith('/') && normalized.length > 1
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
    final segments = trimmed.split('/');
    return segments.isEmpty ? trimmed : segments.last;
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
                selectedProjectSession: _visibleSession,
                onActionSelected: (index) {
                  setState(() {
                    _selectedActionIndex = index;
                  });
                },
                onProjectSelected: _selectProject,
                onRenameProject: _renameProject,
                onToggleProjectPinned: _toggleProjectPinned,
                onRemoveProject: _removeProject,
                onAddProject: _addProject,
                onOpenProject: _openProject,
                onOpenSettings: _openSettings,
                onDownloadRuntime: () {
                  _openSettingsCategory(SettingsCategory.general);
                },
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
                session: _visibleSession,
                onSubmitTask: () {
                  unawaited(_submitComposerTask());
                },
                onAbortTask: () {
                  unawaited(_abortComposerTask());
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadAppUpdateCurrentVersion() async {
    try {
      final version = await widget.appUpdateClient.getCurrentVersion();
      if (!mounted) {
        return;
      }
      setState(() {
        _appUpdateCurrentVersion = version;
      });
    } catch (_) {}
  }

  Future<void> _checkForAppUpdate() async {
    if (_isCheckingAppUpdate || _isDownloadingAppUpdate) {
      return;
    }

    setState(() {
      _isCheckingAppUpdate = true;
      _appUpdateError = null;
      _downloadedUpdateInstaller = null;
      _appUpdateDownloadProgress = null;
    });

    try {
      final check = await widget.appUpdateClient.checkForUpdate();
      if (!mounted) {
        return;
      }
      setState(() {
        _appUpdateCheck = check;
        _appUpdateCurrentVersion = check.currentVersion;
        _isCheckingAppUpdate = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCheckingAppUpdate = false;
        _appUpdateError = _messageForAppUpdateError(error);
      });
    }
  }

  Future<void> _downloadAppUpdate() async {
    final release = _appUpdateCheck?.release;
    if (release == null || _isCheckingAppUpdate || _isDownloadingAppUpdate) {
      return;
    }

    setState(() {
      _isDownloadingAppUpdate = true;
      _appUpdateError = null;
      _downloadedUpdateInstaller = null;
      _appUpdateDownloadProgress = null;
    });

    File? installer;
    try {
      installer = await widget.appUpdateClient.downloadUpdate(
        release: release,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _appUpdateDownloadProgress = progress;
          });
        },
      );
      final openResult = await widget.runtimeController.openSystemFile(
        installer.path,
      );
      if (!openResult.launched) {
        throw AppUpdateException(
          openResult.errorMessage ?? 'Could not open the downloaded installer.',
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloadingAppUpdate = false;
        _downloadedUpdateInstaller = installer;
      });
    } catch (error) {
      final failedInstaller = installer;
      if (failedInstaller != null) {
        unawaited(_deleteAppUpdateInstaller(failedInstaller));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isDownloadingAppUpdate = false;
        _appUpdateError = _messageForAppUpdateError(error);
      });
    }
  }

  Future<void> _deleteAppUpdateInstaller(File installer) async {
    try {
      await widget.appUpdateClient.discardUpdate(installer);
    } catch (_) {}
  }

  Future<void> _quitAndInstallAppUpdate() async {
    if (_downloadedUpdateInstaller == null) {
      return;
    }

    try {
      await widget.runtimeController.quitApplication();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appUpdateError = _messageForAppUpdateError(error);
      });
    }
  }

  String get _piCoreInstallerStatus {
    final error = _piCoreInstallerError;
    if (error != null) {
      return _copy.piCoreInstallerFailedDescription(error);
    }
    if (_isPreparingPiCoreInstaller) {
      return _copy.piCoreInstallerPreparingDescription(
        _piCoreInstallerProgressLabel,
      );
    }
    if (_currentPiCoreRuntimeSnapshot.isReady) {
      return _preparedPiCoreInstaller == null
          ? _copy.piCoreInstallerIdleDescription
          : _copy.piCoreInstallerReadyDescription;
    }
    if (_isWaitingForPiCoreInstaller) {
      return _copy.piCoreInstallerWaitingDescription;
    }
    if (_preparedPiCoreInstaller != null) {
      return _copy.piCoreInstallerPausedDescription;
    }
    return _copy.piCoreInstallerIdleDescription;
  }

  String? get _piCoreInstallerPrimaryActionLabel {
    if (_isPreparingPiCoreInstaller) {
      return null;
    }
    if (_isWaitingForPiCoreInstaller) {
      return _copy.piCoreInstallerStopWaitingActionLabel;
    }
    if (_currentPiCoreRuntimeSnapshot.isReady) {
      return null;
    }
    if (_preparedPiCoreInstaller != null) {
      return _copy.piCoreInstallerResumeWaitingActionLabel;
    }
    return _copy.piCoreInstallerInstallActionLabel;
  }

  VoidCallback? get _onPiCoreInstallerPrimaryAction {
    if (_isPreparingPiCoreInstaller) {
      return null;
    }
    if (_isWaitingForPiCoreInstaller) {
      return _stopWaitingForPiCoreInstaller;
    }
    if (_currentPiCoreRuntimeSnapshot.isReady) {
      return null;
    }
    if (_preparedPiCoreInstaller != null) {
      return () {
        unawaited(_resumeWaitingForPiCoreInstaller());
      };
    }
    return () {
      unawaited(_installPiCore());
    };
  }

  String? get _piCoreInstallerSecondaryActionLabel {
    return _preparedPiCoreInstaller == null
        ? null
        : _copy.piCoreInstallerOpenLogActionLabel;
  }

  VoidCallback? get _onPiCoreInstallerSecondaryAction {
    if (_preparedPiCoreInstaller == null) {
      return null;
    }
    return () {
      unawaited(_openPiCoreInstallerLog());
    };
  }

  String get _piCoreInstallerProgressLabel {
    final progress = _piCoreInstallerDownloadProgress;
    if (progress == null) {
      return _copy.isChinese ? '正在准备下载...' : 'Preparing download...';
    }
    final transferred = _formatByteCount(progress.transferredBytes);
    final total = progress.totalBytes;
    if (total == null) {
      return transferred;
    }
    return '$transferred / ${_formatByteCount(total)}';
  }

  String _messageForPiCoreInstallerError(Object error) {
    if (error is PiCoreInstallerException) {
      return error.message;
    }
    return error.toString();
  }

  String get _appUpdateStatus {
    final error = _appUpdateError;
    if (error != null) {
      return _copy.appUpdateFailedDescription(error);
    }
    if (_isCheckingAppUpdate) {
      return _copy.appUpdateCheckingDescription;
    }
    if (_isDownloadingAppUpdate) {
      return _copy.appUpdateDownloadingDescription(_appUpdateProgressLabel);
    }

    final downloadedInstaller = _downloadedUpdateInstaller;
    if (downloadedInstaller != null) {
      final version = _appUpdateCheck?.release?.version ?? '';
      return _copy.appUpdateReadyDescription(version);
    }

    final check = _appUpdateCheck;
    if (check == null) {
      final version = _appUpdateCurrentVersion;
      return version == null
          ? _copy.appUpdateIdleDescription
          : _copy.appUpdateInstalledVersionDescription(version);
    }

    return switch (check.availability) {
      AppUpdateAvailability.notSupported =>
        _copy.appUpdateUnsupportedDescription,
      AppUpdateAvailability.upToDate =>
        _copy.appUpdateCurrentVersionDescription(check.currentVersion),
      AppUpdateAvailability.available => _copy.appUpdateAvailableDescription(
        check.currentVersion,
        check.release?.version ?? check.currentVersion,
      ),
      AppUpdateAvailability.unavailable =>
        _copy.appUpdateUnavailableDescription(check.message ?? ''),
    };
  }

  String get _appUpdateProgressLabel {
    final progress = _appUpdateDownloadProgress;
    if (progress == null) {
      return _copy.isChinese ? '正在准备下载...' : 'Preparing download...';
    }
    final transferred = _formatByteCount(progress.transferredBytes);
    final total = progress.totalBytes;
    if (total == null) {
      return transferred;
    }
    return '$transferred / ${_formatByteCount(total)}';
  }

  String _messageForAppUpdateError(Object error) {
    if (error is AppUpdateException) {
      return error.message;
    }
    return error.toString();
  }

  String _formatByteCount(int value) {
    if (value < 1024) {
      return '$value B';
    }
    if (value < 1024 * 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _showLicenses() async {
    var version = _appUpdateCurrentVersion;
    if (version == null) {
      try {
        version = await widget.appUpdateClient.getCurrentVersion();
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    showLicensePage(
      context: context,
      applicationName: piAppDisplayName(),
      applicationVersion: version,
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
      piCoreRuntimeSnapshot: widget.piCoreRuntimeSnapshot,
      onRefreshPiCoreRuntime: widget.onRefreshPiCoreRuntime,
      onChoosePiCoreExecutable: widget.onChoosePiCoreExecutable,
      onClearPiCoreExecutable: widget.onClearPiCoreExecutable,
      piCoreInstallerStatus: _piCoreInstallerStatus,
      piCoreInstallerBusy: _isPreparingPiCoreInstaller,
      piCoreInstallerProgressPercent: _piCoreInstallerDownloadProgress?.percent,
      piCoreInstallerSourceUrl: OfficialPiCoreInstallerClient.sourceUri
          .toString(),
      piCoreInstallerScriptPath: _preparedPiCoreInstaller?.scriptFile.path,
      piCoreInstallerLogPath: _preparedPiCoreInstaller?.logFile.path,
      piCoreInstallerActionLabel: _piCoreInstallerPrimaryActionLabel,
      onPiCoreInstallerAction: _onPiCoreInstallerPrimaryAction,
      piCoreInstallerSecondaryActionLabel: _piCoreInstallerSecondaryActionLabel,
      onPiCoreInstallerSecondaryAction: _onPiCoreInstallerSecondaryAction,
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
          widget.preferences.copyWith(
            toolPolicySource: AppToolPolicySource.explicit,
            defaultPermissions: value,
            fullAccess: value ? widget.preferences.fullAccess : false,
          ),
        );
      },
      onAutoReviewChanged: (value) {
        _updatePreferences(widget.preferences.copyWith(autoReview: value));
      },
      onFullAccessChanged: (value) {
        _updatePreferences(
          widget.preferences.copyWith(
            toolPolicySource: AppToolPolicySource.explicit,
            defaultPermissions: value
                ? true
                : widget.preferences.defaultPermissions,
            fullAccess: value,
          ),
        );
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
      appUpdateStatus: _appUpdateStatus,
      appUpdateChecking: _isCheckingAppUpdate,
      appUpdateDownloading: _isDownloadingAppUpdate,
      appUpdateAvailable:
          _appUpdateCheck?.hasUpdate == true &&
          _downloadedUpdateInstaller == null,
      appUpdateReadyToInstall: _downloadedUpdateInstaller != null,
      appUpdateProgressPercent: _appUpdateDownloadProgress?.percent,
      onCheckForUpdate: () {
        unawaited(_checkForAppUpdate());
      },
      onDownloadUpdate: () {
        unawaited(_downloadAppUpdate());
      },
      onQuitAndInstall: () {
        unawaited(_quitAndInstallAppUpdate());
      },
      onShowLicenses: () {
        unawaited(_showLicenses());
      },
    );
  }
}
