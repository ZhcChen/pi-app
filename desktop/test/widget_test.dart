import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_desktop/main.dart';

class _MemoryAppUpdateClient implements AppUpdateClient {
  _MemoryAppUpdateClient({required this.check, required this.installer});

  final AppUpdateCheck check;
  final File installer;
  int checkCount = 0;
  int downloadCount = 0;
  int discardCount = 0;

  @override
  Future<String> getCurrentVersion() async => check.currentVersion;

  @override
  Future<void> discardUpdate(File installer) async {
    discardCount += 1;
  }

  @override
  Future<AppUpdateCheck> checkForUpdate() async {
    checkCount += 1;
    return check;
  }

  @override
  Future<File> downloadUpdate({
    required AppUpdateRelease release,
    AppUpdateProgressListener? onProgress,
  }) async {
    downloadCount += 1;
    onProgress?.call(
      const AppUpdateDownloadProgress(transferredBytes: 4, totalBytes: 4),
    );
    return installer;
  }
}

class _MemoryPiCoreInstallerClient implements PiCoreInstallerClient {
  _MemoryPiCoreInstallerClient({required this.bundle, this.prepareError});

  final PiCoreInstallerBundle bundle;
  final Object? prepareError;
  int prepareCount = 0;
  int discardCount = 0;
  final List<PiCoreInstallerDownloadProgress> progressUpdates =
      <PiCoreInstallerDownloadProgress>[];

  @override
  Future<PiCoreInstallerBundle> prepareInstaller({
    PiCoreInstallerProgressListener? onProgress,
  }) async {
    prepareCount += 1;
    final error = prepareError;
    if (error != null) {
      throw error;
    }
    const progress = PiCoreInstallerDownloadProgress(
      transferredBytes: 4,
      totalBytes: 4,
    );
    progressUpdates.add(progress);
    onProgress?.call(progress);
    return bundle;
  }

  @override
  Future<void> discardInstaller(PiCoreInstallerBundle bundle) async {
    discardCount += 1;
  }
}

class _DelayedPreferencesStore implements DesktopPreferencesStore {
  final Completer<AppPreferences> _loadCompleter = Completer<AppPreferences>();

  AppPreferences? savedPreferences;

  void completeLoad(AppPreferences preferences) {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete(preferences);
    }
  }

  @override
  Future<AppPreferences> loadPreferences() => _loadCompleter.future;

  @override
  Future<void> savePreferences(AppPreferences preferences) async {
    savedPreferences = preferences;
  }
}

void main() {
  void configureWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1.0;
  }

  void resetWindow(WidgetTester tester) {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  Future<void> settleUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
  }

  String resolveRepoWorkspacePath() {
    final currentDirectory = Directory.current;
    if (currentDirectory.path.endsWith('${Platform.pathSeparator}desktop')) {
      return currentDirectory.parent.path;
    }
    return currentDirectory.path;
  }

  test('memory preferences store saves and loads full preferences', () async {
    final store = MemoryDesktopPreferencesStore();
    const expected = AppPreferences(
      language: AppLanguage.simplifiedChinese,
      themeMode: AppThemeMode.light,
      uiScale: AppUiScale.small,
      interfaceDensity: AppInterfaceDensity.compact,
      codeFont: AppCodeFont.systemMono,
      openDestination: AppOpenDestination.terminal,
      piCoreExecutablePath: '/mock/pi',
      defaultPermissions: false,
      autoReview: false,
      fullAccess: false,
      showInMenuBar: false,
      showBottomPanel: true,
      preventSleep: true,
      suggestedPrompts: true,
    );

    await store.savePreferences(expected);
    final loaded = await store.loadPreferences();

    expect(loaded.language, AppLanguage.simplifiedChinese);
    expect(loaded.themeMode, AppThemeMode.light);
    expect(loaded.uiScale, AppUiScale.small);
    expect(loaded.interfaceDensity, AppInterfaceDensity.compact);
    expect(loaded.codeFont, AppCodeFont.systemMono);
    expect(loaded.openDestination, AppOpenDestination.terminal);
    expect(loaded.piCoreExecutablePath, '/mock/pi');
    expect(loaded.defaultPermissions, false);
    expect(loaded.autoReview, false);
    expect(loaded.fullAccess, false);
    expect(loaded.showInMenuBar, false);
    expect(loaded.showBottomPanel, true);
    expect(loaded.preventSleep, true);
    expect(loaded.suggestedPrompts, true);
  });

  test(
    'file preferences disable unversioned tool permissions before migration',
    () async {
      final root = await Directory.systemTemp.createTemp('pi-preferences-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });
      final store = FileDesktopPreferencesStore(rootDirectory: root);
      final settingsFile = store.resolveSettingsFile();
      await settingsFile.parent.create(recursive: true);
      await settingsFile.writeAsString(
        '{"defaultPermissions":true,"fullAccess":true}',
      );

      final migrated = await store.loadPreferences();
      expect(migrated.toolPolicySource, AppToolPolicySource.migratedLegacy);
      expect(migrated.defaultPermissions, false);
      expect(migrated.fullAccess, false);

      await store.savePreferences(
        const AppPreferences(
          piCoreExecutablePath: '/mock/pi',
          defaultPermissions: true,
          fullAccess: true,
        ),
      );
      final saved =
          jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
      final reloaded = await store.loadPreferences();

      expect(saved['toolPolicyVersion'], 1);
      expect(saved['piCoreExecutablePath'], '/mock/pi');
      expect(reloaded.piCoreExecutablePath, '/mock/pi');
      expect(reloaded.toolPolicySource, AppToolPolicySource.explicit);
      expect(reloaded.defaultPermissions, true);
      expect(reloaded.fullAccess, true);
    },
  );

  test(
    'new preferences default to the complete coding tool allowlist',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'pi-preferences-default-',
      );
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final preferences = await FileDesktopPreferencesStore(
        rootDirectory: root,
      ).loadPreferences();

      expect(preferences.toolPolicySource, AppToolPolicySource.explicit);
      expect(preferences.defaultPermissions, true);
      expect(preferences.fullAccess, true);
    },
  );

  test(
    'workspace session state keeps the user prompt before early stream output',
    () {
      final state = WorkspaceSessionState.empty(
        '/workspace/pi-app',
      ).withAssistantDelta('Streaming reply').withUserPrompt('Original prompt');

      expect(
        state.messages.map((message) => message.role),
        <WorkspaceConversationRole>[
          WorkspaceConversationRole.user,
          WorkspaceConversationRole.assistant,
        ],
      );
      expect(state.messages.first.text, 'Original prompt');
      expect(state.messages.last.text, 'Streaming reply');
    },
  );
  test('memory Pi host client manages a session contract', () async {
    final client = MemoryPiHostClient();
    final events = <PiHostEvent>[];
    final subscription = client.events.listen(events.add);
    addTearDown(subscription.cancel);

    final health = await client.ensureStarted();
    final session = await client.createSession(cwd: '/workspace/pi-app');
    await Future<void>.delayed(Duration.zero);
    final accepted = await client.prompt(
      sessionId: session.id,
      text: 'Inspect this workspace.',
    );
    final updated = await client.setThinkingLevel(
      sessionId: session.id,
      level: 'high',
    );
    await client.abort(sessionId: session.id);

    expect(health.protocolVersion, 1);
    expect(session.cwd, '/workspace/pi-app');
    expect(accepted, true);
    expect(client.promptRequests.single.text, 'Inspect this workspace.');
    expect(updated.thinkingLevel, 'high');
    expect(client.abortedSessionIds, <String>[session.id]);
    expect(events.map((event) => event.type), <PiHostEventType>[
      PiHostEventType.sessionCreated,
      PiHostEventType.runStarted,
    ]);
  });
  test(
    'local Pi host client ignores stale sidecar exit after a replacement starts',
    () async {
      String scriptFor({required bool emitInvalidRecord}) {
        return '''
let buffer = '';
function write(value) {
  process.stdout.write(JSON.stringify(value) + '\\n');
}
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  while (true) {
    const newline = buffer.indexOf('\\n');
    if (newline < 0) break;
    const line = buffer.slice(0, newline);
    buffer = buffer.slice(newline + 1);
    if (!line) continue;
    const request = JSON.parse(line);
    if (request.method === 'host.health') {
      write({
        type: 'response',
        id: request.id,
        ok: true,
        result: { protocolVersion: 1, sdkVersion: 'test', agentDir: '/mock' },
      });
      ${emitInvalidRecord ? "setTimeout(() => process.stdout.write('not-json\\n'), 20);" : ''}
    } else if (request.method === 'session.create') {
      write({
        type: 'response',
        id: request.id,
        ok: true,
        result: {
          id: 'replacement-session',
          cwd: request.params.cwd,
          piSessionId: 'replacement-pi-session',
          thinkingLevel: 'off',
          availableThinkingLevels: ['off'],
          isStreaming: false,
          isProjectTrusted: false,
        },
      });
    }
  }
});
''';
      }

      var startCount = 0;
      final hostErrors = <PiHostEvent>[];
      Future<PiHostHealth>? replacementStart;
      late final LocalPiHostClient client;
      client = LocalPiHostClient(
        startProcess: (_) {
          final script = scriptFor(emitInvalidRecord: startCount++ == 0);
          return Process.start('node', <String>[
            '--input-type=module',
            '--eval',
            script,
          ]);
        },
      );
      final subscription = client.events.listen((event) {
        if (event.type == PiHostEventType.hostError) {
          hostErrors.add(event);
          replacementStart ??= client.ensureStarted();
        }
      });
      addTearDown(subscription.cancel);
      addTearDown(client.dispose);

      await client.ensureStarted();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await replacementStart;
      final replacementSession = await client.createSession(
        cwd: '/workspace/pi-app',
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(startCount, 2);
      expect(hostErrors, hasLength(1));
      expect(replacementSession.id, 'replacement-session');
    },
  );

  test('memory project registry store manages project lifecycle', () async {
    final store = MemoryProjectRegistryStore();

    final added = await store.addProject('/workspace/pi-app');
    final addedEntry = added.entries.single;
    await store.addProject('/workspace/notes');
    final pinned = await store.setProjectPinned(addedEntry.id, true);
    final opened = await store.markProjectOpened(addedEntry.id);
    final removed = await store.removeProject(addedEntry.id);

    expect(added.projectPaths, <String>['/workspace/pi-app']);
    expect(addedEntry.name, 'pi-app');
    expect(
      pinned.entries.singleWhere((entry) => entry.id == addedEntry.id).isPinned,
      true,
    );
    expect(pinned.orderedEntries.first.id, addedEntry.id);
    expect(
      opened.entries
          .singleWhere((entry) => entry.id == addedEntry.id)
          .lastOpenedAt,
      isNotNull,
    );
    expect(removed.projectPaths, <String>['/workspace/notes']);
  });

  test('file project registry store persists project metadata', () async {
    final root = await Directory.systemTemp.createTemp('pi-project-metadata-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final source = Directory(
      '${root.path}${Platform.pathSeparator}workspace-alpha',
    )..createSync(recursive: true);
    final store = FileProjectRegistryStore(rootDirectory: root);

    final added = await store.addProject(source.path);
    final entry = added.entries.single;
    final metadataFile = store.resolveProjectMetadataFile(entry.id);
    final renamed = await store.setProjectAlias(entry.id, 'Alpha workspace');
    final reloaded = await store.loadSnapshot();
    final metadata = jsonDecode(await metadataFile.readAsString());

    expect(await metadataFile.exists(), true);
    expect(renamed.entries.single.displayName, 'Alpha workspace');
    expect(reloaded.entries.single.alias, 'Alpha workspace');
    expect(metadata['projectId'], entry.id);
    expect(metadata['path'], source.path);
    expect(metadata['alias'], 'Alpha workspace');

    await store.removeProject(entry.id);
    expect(await store.resolveProjectDirectory(entry.id).exists(), false);
  });

  test('file project registry store migrates legacy project paths', () async {
    final root = await Directory.systemTemp.createTemp('pi-project-store-');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final projectA = Directory(
      '${root.path}${Platform.pathSeparator}workspace-a',
    )..createSync(recursive: true);
    final projectB = Directory(
      '${root.path}${Platform.pathSeparator}workspace-b',
    )..createSync(recursive: true);
    final settingsFile = File(
      '${root.path}${Platform.pathSeparator}settings.json',
    );
    await settingsFile.writeAsString(
      '{"language":"english","projectPaths":["${projectA.path}","${projectB.path}"]}',
    );

    final store = FileProjectRegistryStore(rootDirectory: root);
    final snapshot = await store.loadSnapshot();
    final indexFile = store.resolveIndexFile();
    final savedSettingsContent = await settingsFile.readAsString();

    expect(
      snapshot.projectPaths,
      unorderedEquals(<String>[projectA.path, projectB.path]),
    );
    expect(await indexFile.exists(), true);
    expect(savedSettingsContent.contains('projectPaths'), false);
  });

  test(
    'file pi config store resolves environment override and merges model settings',
    () async {
      final root = await Directory.systemTemp.createTemp('pi-config-store-');
      addTearDown(() async {
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      final settingsFile = File(
        '${root.path}${Platform.pathSeparator}settings.json',
      );
      final authFile = File('${root.path}${Platform.pathSeparator}auth.json');

      await settingsFile.writeAsString(
        '{"theme":"dark","defaultModel":"old-model"}',
      );
      await authFile.writeAsString('{"anthropic":{"type":"apiKey"}}');

      final store = FilePiConfigStore(
        environment: <String, String>{
          'PI_CODING_AGENT_DIR': root.path,
          'HOME': '/unused-home',
        },
      );

      final initial = await store.loadSnapshot();
      expect(initial.rootPath, root.path);
      expect(initial.usesEnvironmentOverride, true);
      expect(initial.modelPreferences.defaultModel, 'old-model');
      expect(initial.authProviderCount, 1);

      final savedPreferences = await store.saveModelPreferences(
        const PiModelPreferences(
          defaultProvider: 'openai',
          defaultModel: 'gpt-4o',
          defaultThinkingLevel: 'high',
          enabledModels: <String>['gpt-4o', 'claude-*'],
        ),
      );

      final savedSettingsContent = await settingsFile.readAsString();
      expect(savedSettingsContent.contains('"theme": "dark"'), true);
      expect(savedPreferences.modelPreferences.defaultProvider, 'openai');
      expect(savedPreferences.modelPreferences.defaultModel, 'gpt-4o');
      expect(savedPreferences.modelPreferences.defaultThinkingLevel, 'high');
      expect(savedPreferences.modelPreferences.enabledModels, <String>[
        'gpt-4o',
        'claude-*',
      ]);

      await store.savePromptFile(PiPromptFileKind.system, 'You are Pi.');
      final systemFile = File('${root.path}${Platform.pathSeparator}SYSTEM.md');
      expect(await systemFile.readAsString(), 'You are Pi.');

      final savedModels = await store.saveModelsJson(
        '{"providers":{"ollama":{"models":[{"id":"qwen2.5-coder:7b"}]}}}',
      );
      expect(savedModels.modelsSummary.providerCount, 1);
      expect(savedModels.modelsSummary.customModelCount, 1);
    },
  );

  test('platform runtime controller syncs supported capabilities', () async {
    final menuBarCalls = <bool>[];
    final preventSleepCalls = <bool>[];
    final controller = PlatformDesktopRuntimeController(
      capabilities: const DesktopRuntimeCapabilities(
        supportsShowInMenuBar: true,
      ),
      setShowInMenuBar: (enabled) async {
        menuBarCalls.add(enabled);
      },
      setPreventSleep: (enabled) async {
        preventSleepCalls.add(enabled);
      },
    );

    await controller.sync(const AppPreferences());
    await controller.sync(
      const AppPreferences(showInMenuBar: false, preventSleep: true),
    );
    await controller.sync(
      const AppPreferences(showInMenuBar: false, preventSleep: true),
    );

    expect(menuBarCalls, <bool>[true, false]);
    expect(preventSleepCalls, <bool>[false, true]);
  });

  test(
    'platform runtime controller skips unsupported show-in-menu-bar sync',
    () async {
      final menuBarCalls = <bool>[];
      final controller = PlatformDesktopRuntimeController(
        capabilities: const DesktopRuntimeCapabilities(
          supportsShowInMenuBar: false,
        ),
        setShowInMenuBar: (enabled) async {
          menuBarCalls.add(enabled);
        },
      );

      await controller.sync(const AppPreferences());
      await controller.sync(const AppPreferences(showInMenuBar: false));

      expect(menuBarCalls, isEmpty);
    },
  );

  test('platform runtime controller delegates open target requests', () async {
    DesktopOpenRequest? capturedRequest;
    final controller = PlatformDesktopRuntimeController(
      openTarget: (request) async {
        capturedRequest = request;
        return const DesktopOpenResult.success();
      },
    );

    const request = DesktopOpenRequest(
      destination: AppOpenDestination.cursor,
      targetPath: '/workspace/pi-app',
      workspacePath: '/workspace/pi-app',
    );

    final result = await controller.openTarget(request);

    expect(result.launched, true);
    expect(capturedRequest?.destination, AppOpenDestination.cursor);
    expect(capturedRequest?.targetPath, '/workspace/pi-app');
    expect(capturedRequest?.workspacePath, '/workspace/pi-app');
  });

  test(
    'platform runtime controller delegates system file, terminal script, and quit actions',
    () async {
      String? openedPath;
      String? terminalScriptPath;
      var quitCount = 0;
      final controller = PlatformDesktopRuntimeController(
        openSystemFile: (targetPath) async {
          openedPath = targetPath;
          return const DesktopOpenResult.success();
        },
        runScriptInTerminal: (scriptPath) async {
          terminalScriptPath = scriptPath;
          return const DesktopOpenResult.success();
        },
        quitApplication: () async {
          quitCount += 1;
        },
      );

      final systemFileResult = await controller.openSystemFile(
        '/tmp/Pi App.dmg',
      );
      final terminalResult = await controller.runScriptInTerminal(
        '/tmp/run-pi-core-installer.command',
      );
      await controller.quitApplication();

      expect(systemFileResult.launched, true);
      expect(terminalResult.launched, true);
      expect(openedPath, '/tmp/Pi App.dmg');
      expect(terminalScriptPath, '/tmp/run-pi-core-installer.command');
      expect(quitCount, 1);
    },
  );

  testWidgets('settings downloads and prepares a manual app update', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final release = AppUpdateRelease(
      tag: 'v1.0.1',
      version: '1.0.1',
      releaseUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/tag/v1.0.1',
      ),
      downloadUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/download/v1.0.1/Pi-App-1.0.1-macos-universal.dmg',
      ),
      assetName: 'Pi-App-1.0.1-macos-universal.dmg',
      releaseNotes: '',
    );
    final updateClient = _MemoryAppUpdateClient(
      check: AppUpdateCheck(
        availability: AppUpdateAvailability.available,
        currentVersion: '1.0.0',
        release: release,
      ),
      installer: File('/tmp/Pi-App-1.0.1-macos-universal.dmg'),
    );
    final runtimeController = MemoryDesktopRuntimeController();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        appUpdateClient: updateClient,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    expect(updateClient.checkCount, 0);
    expect(find.text('Installed version: 1.0.0.'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('app-update-action-button')),
    );

    await tester.tap(find.byKey(const Key('app-update-action-button')));
    await tester.pumpAndSettle();

    expect(updateClient.checkCount, 1);
    expect(find.text('Download update'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-update-action-button')));
    await tester.pumpAndSettle();

    expect(updateClient.downloadCount, 1);
    expect(runtimeController.lastSystemFilePath, updateClient.installer.path);
    expect(find.text('Quit and install'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-update-action-button')));
    await tester.pumpAndSettle();

    expect(runtimeController.quitCount, 1);
  });

  testWidgets('settings keeps the app running when the DMG cannot open', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final installer = File('/tmp/Pi-App-1.0.1-macos-universal.dmg');
    final release = AppUpdateRelease(
      tag: 'v1.0.1',
      version: '1.0.1',
      releaseUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/tag/v1.0.1',
      ),
      downloadUri: Uri.parse(
        'https://github.com/ZhcChen/pi-app/releases/download/v1.0.1/Pi-App-1.0.1-macos-universal.dmg',
      ),
      assetName: 'Pi-App-1.0.1-macos-universal.dmg',
      releaseNotes: '',
    );
    final updateClient = _MemoryAppUpdateClient(
      check: AppUpdateCheck(
        availability: AppUpdateAvailability.available,
        currentVersion: '1.0.0',
        release: release,
      ),
      installer: installer,
    );
    final runtimeController = MemoryDesktopRuntimeController(
      systemFileOpenResult: const DesktopOpenResult.failure('DMG open failed.'),
    );

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        appUpdateClient: updateClient,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('app-update-action-button')),
    );
    await tester.tap(find.byKey(const Key('app-update-action-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-update-action-button')));
    await tester.pumpAndSettle();

    expect(find.text('Update failed: DMG open failed.'), findsOneWidget);
    expect(runtimeController.quitCount, 0);
    expect(updateClient.discardCount, 1);
  });

  testWidgets(
    'settings launches the Pi Core installer in Terminal and waits for runtime readiness',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final runtimeController = MemoryDesktopRuntimeController();
      final installerBundle = PiCoreInstallerBundle(
        sourceUri: OfficialPiCoreInstallerClient.sourceUri,
        rootDirectory: Directory('/tmp/pi-core-installer'),
        scriptFile: File('/tmp/pi-core-installer/install.sh'),
        launcherFile: File(
          '/tmp/pi-core-installer/run-pi-core-installer.command',
        ),
        logFile: File('/tmp/pi-core-installer/pi-core-installer.log'),
      );
      final installerClient = _MemoryPiCoreInstallerClient(
        bundle: installerBundle,
      );

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          runtimeController: runtimeController,
          piCoreRuntimeController: piCoreRuntimeController,
          piCoreInstallerClient: installerClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pi-core-installer-action-button')),
      );

      await tester.tap(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await settleUi(tester);

      expect(installerClient.prepareCount, 1);
      expect(
        runtimeController.lastTerminalScriptPath,
        installerBundle.launcherFile.path,
      );
      expect(find.text('Stop waiting'), findsOneWidget);

      detector.setSnapshot(
        const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.ready,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          version: '0.82.0',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pi-core-runtime-status')), findsOneWidget);
      expect(find.text('Ready'), findsWidgets);
      expect(
        find.text(
          'Pi Core is now ready. The installer log remains available at the path below.',
        ),
        findsOneWidget,
      );
      expect(find.text('Open log'), findsOneWidget);
    },
  );

  testWidgets(
    'settings can stop waiting for the Pi Core installer and open the log',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final runtimeController = MemoryDesktopRuntimeController();
      final installerBundle = PiCoreInstallerBundle(
        sourceUri: OfficialPiCoreInstallerClient.sourceUri,
        rootDirectory: Directory('/tmp/pi-core-installer'),
        scriptFile: File('/tmp/pi-core-installer/install.sh'),
        launcherFile: File(
          '/tmp/pi-core-installer/run-pi-core-installer.command',
        ),
        logFile: File('/tmp/pi-core-installer/pi-core-installer.log'),
      );
      final installerClient = _MemoryPiCoreInstallerClient(
        bundle: installerBundle,
      );

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          runtimeController: runtimeController,
          piCoreRuntimeController: piCoreRuntimeController,
          piCoreInstallerClient: installerClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pi-core-installer-action-button')),
      );

      await tester.tap(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await settleUi(tester);
      await tester.ensureVisible(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await tester.tap(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await settleUi(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Resume waiting'), findsOneWidget);
      expect(find.text('Open log'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('pi-core-installer-secondary-action-button')),
      );
      await settleUi(tester);

      expect(
        runtimeController.lastSystemFilePath,
        installerBundle.logFile.path,
      );
      expect(
        runtimeController.lastTerminalScriptPath,
        installerBundle.launcherFile.path,
      );
    },
  );

  testWidgets(
    'settings surfaces Pi Core installer preparation failures without entering the wait state',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final runtimeController = MemoryDesktopRuntimeController();
      final installerBundle = PiCoreInstallerBundle(
        sourceUri: OfficialPiCoreInstallerClient.sourceUri,
        rootDirectory: Directory('/tmp/pi-core-installer'),
        scriptFile: File('/tmp/pi-core-installer/install.sh'),
        launcherFile: File(
          '/tmp/pi-core-installer/run-pi-core-installer.command',
        ),
        logFile: File('/tmp/pi-core-installer/pi-core-installer.log'),
      );
      final installerClient = _MemoryPiCoreInstallerClient(
        bundle: installerBundle,
        prepareError: const PiCoreInstallerException(
          'Could not download the official Pi installer.',
        ),
      );

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          runtimeController: runtimeController,
          piCoreRuntimeController: piCoreRuntimeController,
          piCoreInstallerClient: installerClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pi-core-installer-action-button')),
      );

      await tester.tap(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await settleUi(tester);

      expect(
        find.text(
          'Installer failed: Could not download the official Pi installer.',
        ),
        findsOneWidget,
      );
      expect(runtimeController.lastTerminalScriptPath, isNull);
      expect(find.text('Stop waiting'), findsNothing);
      expect(find.text('Install Pi Core'), findsOneWidget);
    },
  );

  testWidgets(
    'settings surfaces Pi Core installer launch failures and discards the prepared bundle',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final runtimeController = MemoryDesktopRuntimeController(
        terminalScriptOpenResult: const DesktopOpenResult.failure(
          'Terminal launch failed.',
        ),
      );
      final installerBundle = PiCoreInstallerBundle(
        sourceUri: OfficialPiCoreInstallerClient.sourceUri,
        rootDirectory: Directory('/tmp/pi-core-installer'),
        scriptFile: File('/tmp/pi-core-installer/install.sh'),
        launcherFile: File(
          '/tmp/pi-core-installer/run-pi-core-installer.command',
        ),
        logFile: File('/tmp/pi-core-installer/pi-core-installer.log'),
      );
      final installerClient = _MemoryPiCoreInstallerClient(
        bundle: installerBundle,
      );

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          runtimeController: runtimeController,
          piCoreRuntimeController: piCoreRuntimeController,
          piCoreInstallerClient: installerClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('pi-core-installer-action-button')),
      );

      await tester.tap(
        find.byKey(const Key('pi-core-installer-action-button')),
      );
      await settleUi(tester);

      expect(
        find.text('Installer failed: Terminal launch failed.'),
        findsOneWidget,
      );
      expect(installerClient.discardCount, 1);
      expect(find.text('Install Pi Core'), findsOneWidget);
    },
  );

  testWidgets('sidebar download runtime shortcut opens the settings page', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(const PiDesktopApp(enablePersistence: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download-runtime-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page-title')), findsOneWidget);
    expect(find.text('Pi Core runtime'), findsOneWidget);
  });

  testWidgets('app starts without an implicit project root', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(const PiDesktopApp(enablePersistence: false));
    await tester.pumpAndSettle();

    expect(find.text('No projects available'), findsWidgets);
    expect(
      find.text(
        'No local project path could be resolved for the current workspace.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('project-overview-title')), findsNothing);
    expect(
      find.byKey(const Key('workspace-suggested-prompts')),
      findsOneWidget,
    );
  });

  testWidgets('projectless workspace respects suggested prompts setting', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(const PiDesktopApp(enablePersistence: false));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('workspace-suggested-prompts')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('suggested-prompts-switch')),
    );
    await tester.tap(find.byKey(const Key('suggested-prompts-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-suggested-prompts')), findsNothing);
  });

  testWidgets(
    'delayed persisted restrictions remain effective before the first composer task',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final preferencesStore = _DelayedPreferencesStore();
      final piHostClient = MemoryPiHostClient();
      final workspacePath = resolveRepoWorkspacePath();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: preferencesStore,
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: MemoryProjectRegistryStore(),
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Keep the delayed legacy policy restricted.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.createdSessions.single.tools, isEmpty);

      preferencesStore.completeLoad(
        const AppPreferences(defaultPermissions: false, fullAccess: false),
      );
      await settleUi(tester);
    },
  );

  testWidgets(
    'legacy restricted preferences can authorize coding tools before a new session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final preferencesStore = MemoryDesktopPreferencesStore(
        initialPreferences: const AppPreferences(
          toolPolicySource: AppToolPolicySource.migratedLegacy,
          defaultPermissions: false,
          fullAccess: false,
        ),
      );
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: preferencesStore,
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: MemoryProjectRegistryStore(),
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Authorize the full coding toolset.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(
        find.byKey(const Key('tool-policy-upgrade-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('tool-policy-upgrade-authorize-button')),
      );
      await settleUi(tester);

      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.createdSessions.single.tools, <String>[
        'read',
        'grep',
        'find',
        'ls',
        'bash',
        'edit',
        'write',
      ]);

      final savedPreferences = await preferencesStore.loadPreferences();
      expect(savedPreferences.toolPolicySource, AppToolPolicySource.explicit);
      expect(savedPreferences.defaultPermissions, true);
      expect(savedPreferences.fullAccess, true);
    },
  );

  testWidgets(
    'legacy restricted preferences can stay restricted for a new session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final preferencesStore = MemoryDesktopPreferencesStore(
        initialPreferences: const AppPreferences(
          toolPolicySource: AppToolPolicySource.migratedLegacy,
          defaultPermissions: false,
          fullAccess: false,
        ),
      );
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: preferencesStore,
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: MemoryProjectRegistryStore(),
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Keep the session restricted.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(
        find.byKey(const Key('tool-policy-upgrade-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('tool-policy-upgrade-keep-restricted-button')),
      );
      await settleUi(tester);

      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.createdSessions.single.tools, isEmpty);

      final savedPreferences = await preferencesStore.loadPreferences();
      expect(savedPreferences.toolPolicySource, AppToolPolicySource.explicit);
      expect(savedPreferences.defaultPermissions, false);
      expect(savedPreferences.fullAccess, false);
    },
  );

  testWidgets(
    'legacy restricted preferences can cancel before creating a new session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final preferencesStore = MemoryDesktopPreferencesStore(
        initialPreferences: const AppPreferences(
          toolPolicySource: AppToolPolicySource.migratedLegacy,
          defaultPermissions: false,
          fullAccess: false,
        ),
      );
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: preferencesStore,
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: MemoryProjectRegistryStore(),
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Cancel the migration prompt.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(
        find.byKey(const Key('tool-policy-upgrade-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('tool-policy-upgrade-cancel-button')),
      );
      await settleUi(tester);

      expect(piHostClient.createdSessions, isEmpty);
      expect(piHostClient.promptRequests, isEmpty);
      expect(find.text('Cancel the migration prompt.'), findsOneWidget);

      final savedPreferences = await preferencesStore.loadPreferences();
      expect(
        savedPreferences.toolPolicySource,
        AppToolPolicySource.migratedLegacy,
      );
    },
  );

  testWidgets(
    'runtime repair dialog can open settings instead of creating a new session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          enforcePiCoreRuntimeGate: true,
          piCoreRuntimeController: piCoreRuntimeController,
          piHostClient: piHostClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Open settings to repair Pi Core.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.byKey(const Key('pi-core-repair-dialog')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('pi-core-repair-open-settings-button')),
      );
      await settleUi(tester);

      expect(find.byKey(const Key('settings-page-title')), findsOneWidget);
      expect(piHostClient.createdSessions, isEmpty);
    },
  );

  testWidgets(
    'runtime repair dialog can refresh and continue creating a new session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          enforcePiCoreRuntimeGate: true,
          piCoreRuntimeController: piCoreRuntimeController,
          piHostClient: piHostClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Refresh Pi Core and continue.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.byKey(const Key('pi-core-repair-dialog')), findsOneWidget);

      detector.setSnapshot(
        const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.ready,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          version: '0.82.0',
        ),
      );
      await tester.tap(find.byKey(const Key('pi-core-repair-refresh-button')));
      await settleUi(tester);

      expect(find.byKey(const Key('pi-core-repair-dialog')), findsNothing);
      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.promptRequests, hasLength(1));
      expect(piHostClient.createdSessions.single.tools, <String>[
        'read',
        'grep',
        'find',
        'ls',
        'bash',
        'edit',
        'write',
      ]);
    },
  );

  testWidgets(
    'runtime repair dialog stays off for injected hosts unless the gate is forced',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          piCoreRuntimeController: piCoreRuntimeController,
          piHostClient: piHostClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Use the injected host without runtime gating.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.byKey(const Key('pi-core-repair-dialog')), findsNothing);
      expect(piHostClient.createdSessions, hasLength(1));
    },
  );

  testWidgets(
    'runtime degradation does not block follow-up prompts on an existing session',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.ready,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          version: '0.82.0',
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          enforcePiCoreRuntimeGate: true,
          piCoreRuntimeController: piCoreRuntimeController,
          piHostClient: piHostClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Create the first gated session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.promptRequests, hasLength(1));
      final firstSessionId = piHostClient.promptRequests.single.sessionId;

      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.runSettled,
          sessionId: firstSessionId,
        ),
      );
      await settleUi(tester);

      detector.setSnapshot(
        const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.healthCheckFailed,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
          diagnosticCode: PiCoreRuntimeDiagnosticCode.rpcTimedOut,
        ),
      );
      await piCoreRuntimeController.refresh();
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Send a follow-up through the existing session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.byKey(const Key('pi-core-repair-dialog')), findsNothing);
      expect(piHostClient.createdSessions, hasLength(1));
      expect(piHostClient.promptRequests, hasLength(2));
      expect(piHostClient.promptRequests.last.sessionId, firstSessionId);
    },
  );

  testWidgets('renders settings views and switches language', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(const PiDesktopApp(enablePersistence: false));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Do anything'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Default file open destination'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('language-dropdown')));
    await tester.tap(find.byKey(const Key('language-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简体中文').last);
    await tester.pumpAndSettle();

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('默认打开方式'), findsOneWidget);

    await tester.tap(find.text('外观').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appearance-page-title')), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('界面文字大小'), findsOneWidget);
    expect(find.text('代码字体'), findsOneWidget);
    expect(find.text('界面预览'), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await tester.pumpAndSettle();

    expect(find.text('新任务'), findsOneWidget);
    expect(find.text('交给 Pi 处理'), findsOneWidget);
  });

  testWidgets('general settings bridge workspace behavior and runtime', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final runtimeController = MemoryDesktopRuntimeController();
    final workspacePath = resolveRepoWorkspacePath();

    Future<void> tapSettingsControl(Key key) async {
      final finder = find.byKey(key);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        workspaceRootPath: workspacePath,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-suggested-prompts')), findsNothing);
    expect(find.byKey(const Key('workspace-bottom-panel')), findsNothing);
    expect(find.text('VS Code · Coding tools · Auto-review'), findsOneWidget);
    expect(runtimeController.lastSyncedPreferences?.showInMenuBar, true);
    expect(runtimeController.lastSyncedPreferences?.preventSleep, false);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('open-destination-dropdown')),
    );
    await tester.tap(find.byKey(const Key('open-destination-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();

    await tapSettingsControl(const Key('full-access-switch'));
    await tapSettingsControl(const Key('default-permissions-switch'));
    await tapSettingsControl(const Key('auto-review-switch'));
    await tapSettingsControl(const Key('show-in-menu-bar-switch'));
    await tapSettingsControl(const Key('show-bottom-panel-switch'));
    await tapSettingsControl(const Key('prevent-sleep-switch'));
    await tapSettingsControl(const Key('suggested-prompts-switch'));

    expect(runtimeController.lastSyncedPreferences?.showInMenuBar, false);
    expect(runtimeController.lastSyncedPreferences?.preventSleep, true);

    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-suggested-prompts')), findsNothing);
    expect(find.byKey(const Key('workspace-bottom-panel')), findsOneWidget);
    expect(
      find.text('Terminal · No built-in tools · Manual review'),
      findsOneWidget,
    );
    expect(find.text('Open: Terminal'), findsOneWidget);
    expect(find.text('Keep awake'), findsOneWidget);
    expect(find.text('Suggested prompts off'), findsOneWidget);
  });

  testWidgets(
    'Pi Core runtime card persists and clears a selected executable',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final preferencesStore = MemoryDesktopPreferencesStore();
      final detector = MemoryPiCoreRuntimeDetector(
        snapshot: const PiCoreRuntimeSnapshot(
          status: PiCoreRuntimeStatus.ready,
          source: PiCoreRuntimeSource.path,
          executablePath: '/mock/pi',
        ),
      );
      final piCoreRuntimeController = PiCoreRuntimeController(
        detector: detector,
      );
      addTearDown(piCoreRuntimeController.dispose);

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: preferencesStore,
          runtimeController: MemoryDesktopRuntimeController(),
          piCoreRuntimeController: piCoreRuntimeController,
          pickPiCoreExecutable: () async => '/mock/selected-pi',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open-settings-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pi-core-runtime-card')), findsOneWidget);
      expect(find.text('Checking'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pi-core-runtime-refresh-button')));
      await tester.pumpAndSettle();

      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('/mock/pi'), findsOneWidget);
      expect(find.text('Reported version'), findsOneWidget);
      expect(find.text('Not detected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pi-core-runtime-choose-button')));
      await tester.pumpAndSettle();

      expect(detector.lastSelectedExecutablePath, '/mock/selected-pi');
      expect(
        (await preferencesStore.loadPreferences()).piCoreExecutablePath,
        '/mock/selected-pi',
      );
      expect(
        find.byKey(const Key('pi-core-runtime-clear-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('pi-core-runtime-clear-button')));
      await tester.pumpAndSettle();

      expect(detector.lastSelectedExecutablePath, isNull);
      expect(
        (await preferencesStore.loadPreferences()).piCoreExecutablePath,
        isNull,
      );
    },
  );

  testWidgets('show in menu bar is disabled when runtime lacks support', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final runtimeController = MemoryDesktopRuntimeController(
      capabilities: const DesktopRuntimeCapabilities(
        supportsShowInMenuBar: false,
      ),
    );

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    final menuBarSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-in-menu-bar-switch')),
    );
    expect(menuBarSwitch.onChanged, isNull);
    expect(
      find.text('This behavior is currently supported only on macOS.'),
      findsOneWidget,
    );
  });

  testWidgets('workspace open actions follow the current open destination', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final runtimeController = MemoryDesktopRuntimeController();
    final workspacePath = resolveRepoWorkspacePath();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        workspaceRootPath: workspacePath,
      ),
    );
    await settleUi(tester);

    await tester.tap(find.byKey(const Key('open-project-button-pi-app')));
    await settleUi(tester);

    expect(
      runtimeController.lastOpenRequest?.destination,
      AppOpenDestination.vscode,
    );
    expect(runtimeController.lastOpenRequest?.targetPath, workspacePath);
    expect(runtimeController.lastOpenRequest?.workspacePath, workspacePath);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await settleUi(tester);
    await tester.ensureVisible(
      find.byKey(const Key('open-destination-dropdown')),
    );
    await tester.tap(find.byKey(const Key('open-destination-dropdown')));
    await settleUi(tester);
    await tester.tap(find.text('Terminal').last);
    await settleUi(tester);
    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await settleUi(tester);

    expect(
      find.byKey(const Key('open-project-overview-item-button-desktop')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('open-project-button-pi-app')));
    await settleUi(tester);

    expect(
      runtimeController.lastOpenRequest?.destination,
      AppOpenDestination.terminal,
    );
    expect(runtimeController.lastOpenRequest?.targetPath, workspacePath);
    expect(runtimeController.openCount, 2);
  });

  testWidgets('sidebar section labels keep text and icons centered', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        workspaceRootPath: resolveRepoWorkspacePath(),
      ),
    );
    await settleUi(tester);

    void expectCenteredLabel({
      required Key key,
      required String text,
      required IconData icon,
    }) {
      final labelFinder = find.byKey(key);
      final labelCenter = tester.getCenter(labelFinder);
      final textCenter = tester.getCenter(find.text(text).first);
      final iconCenter = tester.getCenter(find.byIcon(icon).first);

      expect(tester.getSize(labelFinder).height, 24);
      expect(textCenter.dy, closeTo(labelCenter.dy, 0.5));
      expect(iconCenter.dy, closeTo(labelCenter.dy, 0.5));
    }

    expectCenteredLabel(
      key: const Key('projects-section-label'),
      text: 'Projects',
      icon: Icons.expand_more_rounded,
    );
    expect(find.byKey(const Key('tasks-section-label')), findsNothing);
    expect(find.byKey(const Key('sessions-section-label')), findsNothing);
  });

  testWidgets('project tiles keep hover overlay transparent', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        workspaceRootPath: resolveRepoWorkspacePath(),
      ),
    );
    await settleUi(tester);

    final projectTile = find.byKey(const Key('sidebar-project-tile-0'));
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: projectTile, matching: find.byType(InkWell)).first,
    );

    expect(
      inkWell.overlayColor?.resolve(const <WidgetState>{WidgetState.hovered}),
      Colors.transparent,
    );
    expect(
      inkWell.overlayColor?.resolve(const <WidgetState>{WidgetState.pressed}),
      Colors.transparent,
    );
  });

  testWidgets(
    'selected project nests the active session directly beneath the project',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final piHostClient = MemoryPiHostClient(settleWithoutRunOnPrompt: true);

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: resolveRepoWorkspacePath(),
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      expect(
        find.byKey(const Key('sidebar-project-session-list')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Start a session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      final sessionTile = find.byKey(
        const Key('sidebar-project-session-tile-0'),
      );
      expect(sessionTile, findsOneWidget);
      expect(find.byKey(const Key('sessions-section-label')), findsNothing);
      expect(
        find.descendant(
          of: sessionTile,
          matching: find.text('Start a session.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Task completed'), findsWidgets);
    },
  );

  testWidgets(
    'selected project prefers Pi sessionName over the local prompt title',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final piHostClient = MemoryPiHostClient(emitRunStartedOnPrompt: true);

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: resolveRepoWorkspacePath(),
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Analyze project structure and summarize it.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      final sessionId = piHostClient.promptRequests.single.sessionId;
      final sessionTile = find.byKey(
        const Key('sidebar-project-session-tile-0'),
      );
      expect(
        find.descendant(
          of: sessionTile,
          matching: find.text('Analyze project structure and summar...'),
        ),
        findsOneWidget,
      );

      piHostClient.setSessionNameForTesting(
        sessionId: sessionId,
        sessionName: '分析项目',
      );
      piHostClient.emit(
        PiHostEvent(type: PiHostEventType.runSettled, sessionId: sessionId),
      );
      await settleUi(tester);

      expect(
        find.descendant(of: sessionTile, matching: find.text('分析项目')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sessionTile,
          matching: find.text('Analyze project structure and summar...'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'selected project loads known session shortcuts from the local reference store',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final projectRoot = Directory.systemTemp.createTempSync(
        'pi-known-session-project-',
      );
      addTearDown(() {
        projectRoot.deleteSync(recursive: true);
      });
      final projectEntry = ProjectRegistryEntry.create(projectRoot.path);
      final projectRegistryStore = MemoryProjectRegistryStore(
        initialSnapshot: ProjectRegistrySnapshot(
          entries: <ProjectRegistryEntry>[projectEntry],
        ),
      );
      final sessionReferenceStore = MemoryPiSessionReferenceStore(
        initialSnapshot: PiSessionReferenceSnapshot(
          references: <PiSessionReference>[
            PiSessionReference(
              projectId: projectEntry.id,
              projectPath: projectRoot.path,
              sessionFile:
                  '${projectRoot.path}${Platform.pathSeparator}.pi-session-known.jsonl',
              sessionName: '最近会话',
              lastKnownSessionId: 'pi-known-session-1',
              lastOpenedAt: '2026-07-30T12:00:00.000Z',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: MemoryDesktopPreferencesStore(),
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          projectRegistryStore: projectRegistryStore,
          sessionReferenceStore: sessionReferenceStore,
          workspaceRootPath: null,
        ),
      );
      await settleUi(tester);

      expect(
        find.byKey(const Key('workspace-session-transcript')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('sidebar-project-session-list')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('sidebar-project-session-list')),
          matching: find.text('最近会话'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selected project can switch the current controller to a known session shortcut',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final projectRoot = Directory.systemTemp.createTempSync(
        'pi-switch-known-session-project-',
      );
      addTearDown(() {
        projectRoot.deleteSync(recursive: true);
      });
      final projectEntry = ProjectRegistryEntry.create(projectRoot.path);
      final rememberedSessionPath =
          '${projectRoot.path}${Platform.pathSeparator}.pi-session-remembered.jsonl';
      final projectRegistryStore = MemoryProjectRegistryStore(
        initialSnapshot: ProjectRegistrySnapshot(
          entries: <ProjectRegistryEntry>[projectEntry],
        ),
      );
      final sessionReferenceStore = MemoryPiSessionReferenceStore(
        initialSnapshot: PiSessionReferenceSnapshot(
          references: <PiSessionReference>[
            PiSessionReference(
              projectId: projectEntry.id,
              projectPath: projectRoot.path,
              sessionFile: rememberedSessionPath,
              sessionName: '最近会话',
              lastKnownSessionId: 'pi-known-session-2',
              lastOpenedAt: '2026-07-30T12:30:00.000Z',
            ),
          ],
        ),
      );
      final piHostClient = MemoryPiHostClient(settleWithoutRunOnPrompt: true);

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: MemoryDesktopPreferencesStore(),
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: projectRegistryStore,
          sessionReferenceStore: sessionReferenceStore,
          workspaceRootPath: null,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Start the current session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      final currentSessionId = piHostClient.promptRequests.single.sessionId;
      expect(
        find.descendant(
          of: find.byKey(const Key('sidebar-project-session-tile-1')),
          matching: find.text('最近会话'),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('sidebar-project-session-tile-1')),
      );
      await tester.tap(
        find
            .ancestor(
              of: find.byKey(const Key('sidebar-project-session-tile-1')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await settleUi(tester);

      expect(piHostClient.switchedSessions, hasLength(1));
      expect(piHostClient.switchedSessions.single.sessionId, currentSessionId);
      expect(
        piHostClient.switchedSessions.single.sessionPath,
        rememberedSessionPath,
      );
      expect(
        find.byKey(const Key('workspace-session-transcript')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('sidebar-project-session-tile-0')),
          matching: find.text('最近会话'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Continue the remembered session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.promptRequests, hasLength(2));
      expect(piHostClient.promptRequests.last.sessionId, currentSessionId);
      expect(
        piHostClient.promptRequests.last.text,
        'Continue the remembered session.',
      );
    },
  );

  testWidgets('projects section can collapse and expand its project list', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        workspaceRootPath: resolveRepoWorkspacePath(),
      ),
    );
    await settleUi(tester);

    final toggleButton = find.byKey(
      const Key('toggle-projects-section-button'),
    );
    final toggleIcon = find.byKey(const Key('projects-section-toggle-icon'));
    final label = find.byKey(const Key('projects-section-label'));

    expect(
      tester.getCenter(toggleButton).dx,
      greaterThan(tester.getRect(label).right),
    );
    expect(tester.getSemantics(toggleButton).flagsCollection.isButton, isTrue);
    expect(
      tester.getSemantics(toggleButton).flagsCollection.isExpanded,
      Tristate.isTrue,
    );
    expect(
      find.byKey(const Key('projects-section-project-list')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sidebar-project-tile-0')), findsOneWidget);
    expect(tester.widget<Icon>(toggleIcon).icon, Icons.expand_more_rounded);

    await tester.tap(toggleButton);
    await settleUi(tester);

    expect(
      find.byKey(const Key('projects-section-project-list')),
      findsNothing,
    );
    expect(find.byKey(const Key('sidebar-project-tile-0')), findsNothing);
    expect(tester.widget<Icon>(toggleIcon).icon, Icons.chevron_right_rounded);
    expect(
      tester.getSemantics(toggleButton).flagsCollection.isExpanded,
      Tristate.isFalse,
    );

    await tester.tap(toggleButton);
    await settleUi(tester);

    expect(
      find.byKey(const Key('projects-section-project-list')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sidebar-project-tile-0')), findsOneWidget);
    expect(tester.widget<Icon>(toggleIcon).icon, Icons.expand_more_rounded);
    semantics.dispose();
  });

  testWidgets('projects header adds and manages a registry project', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final workspacePath = resolveRepoWorkspacePath();
    final preferencesStore = MemoryDesktopPreferencesStore();
    final projectRegistryStore = MemoryProjectRegistryStore();
    final runtimeController = MemoryDesktopRuntimeController();
    final addedProject = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}pi-desktop-added-project-test',
    )..createSync(recursive: true);
    addTearDown(() async {
      if (await addedProject.exists()) {
        await addedProject.delete(recursive: true);
      }
    });

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: true,
        preferencesStore: preferencesStore,
        projectRegistryStore: projectRegistryStore,
        runtimeController: runtimeController,
        workspaceRootPath: workspacePath,
        pickProjectDirectory: () async => addedProject.path,
      ),
    );
    await settleUi(tester);

    expect(find.byKey(const Key('add-project-button')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('add-project-button-visibility')),
          )
          .opacity,
      0,
    );

    await tester.tap(find.byKey(const Key('toggle-projects-section-button')));
    await settleUi(tester);
    expect(
      find.byKey(const Key('projects-section-project-list')),
      findsNothing,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('projects-section-header'))),
    );
    await settleUi(tester);

    expect(find.byKey(const Key('add-project-button')), findsOneWidget);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('add-project-button-visibility')),
          )
          .opacity,
      1,
    );

    await tester.tap(find.byKey(const Key('add-project-button')));
    await settleUi(tester);

    expect(
      find.byKey(const Key('projects-section-project-list')),
      findsOneWidget,
    );
    expect(find.text(addedProject.path), findsWidgets);
    expect(
      find.text(
        'Added project: ${addedProject.uri.pathSegments.where((segment) => segment.isNotEmpty).last}',
      ),
      findsOneWidget,
    );

    final savedRegistry = await projectRegistryStore.loadSnapshot();
    expect(savedRegistry.projectPaths, <String>[addedProject.path]);

    final projectName = addedProject.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    final manageButton = Key('manage-project-button-$projectName');

    await tester.tap(find.byKey(manageButton));
    await settleUi(tester);
    await tester.tap(find.byKey(const Key('rename-project-menu-item')));
    await settleUi(tester);
    await tester.enterText(
      find.byKey(const Key('project-rename-input')),
      'Workspace Alpha',
    );
    await tester.tap(find.byKey(const Key('save-project-rename-button')));
    await settleUi(tester);

    var updatedRegistry = await projectRegistryStore.loadSnapshot();
    expect(updatedRegistry.entries.single.alias, 'Workspace Alpha');
    expect(find.text('Workspace Alpha'), findsWidgets);

    final renamedManageButton = const Key(
      'manage-project-button-Workspace Alpha',
    );
    await tester.tap(find.byKey(renamedManageButton));
    await settleUi(tester);
    await tester.tap(find.text('Pin project').last);
    await settleUi(tester);

    updatedRegistry = await projectRegistryStore.loadSnapshot();
    expect(updatedRegistry.entries.single.isPinned, true);
    expect(find.byIcon(Icons.push_pin_outlined), findsWidgets);

    await tester.tap(find.byKey(renamedManageButton));
    await settleUi(tester);
    await tester.tap(find.text('Remove from projects').last);
    await settleUi(tester);

    updatedRegistry = await projectRegistryStore.loadSnapshot();
    expect(updatedRegistry.entries, isEmpty);
    expect(find.text(addedProject.path), findsNothing);
  });

  testWidgets(
    'switching projects discards local session echo instead of restoring it later',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final projectA = Directory.systemTemp.createTempSync('pi-workspace-a-');
      final projectB = Directory.systemTemp.createTempSync('pi-workspace-b-');
      addTearDown(() {
        projectA.deleteSync(recursive: true);
        projectB.deleteSync(recursive: true);
      });
      final projectAName = projectA.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      final projectBName = projectB.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .last;
      final registryStore = MemoryProjectRegistryStore(
        initialSnapshot: ProjectRegistrySnapshot(
          entries: <ProjectRegistryEntry>[
            ProjectRegistryEntry.create(projectB.path),
          ],
        ),
      );
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: MemoryDesktopPreferencesStore(),
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          projectRegistryStore: registryStore,
          workspaceRootPath: projectA.path,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Keep this session with project A.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);
      final firstSessionId = piHostClient.promptRequests.single.sessionId;
      piHostClient.setSessionNameForTesting(
        sessionId: firstSessionId,
        sessionName: '分析项目A',
      );
      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.runSettled,
          sessionId: firstSessionId,
        ),
      );
      await settleUi(tester);

      final transcriptFinder = find.byKey(
        const Key('workspace-session-transcript'),
      );
      expect(transcriptFinder, findsOneWidget);
      expect(
        find.descendant(
          of: transcriptFinder,
          matching: find.text('Keep this session with project A.'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(projectBName).first);
      await settleUi(tester);

      expect(
        find.byKey(const Key('workspace-session-transcript')),
        findsNothing,
      );
      expect(find.text('Keep this session with project A.'), findsNothing);
      expect(find.text(projectBName), findsWidgets);

      await tester.tap(find.text(projectAName).first);
      await settleUi(tester);

      expect(
        find.byKey(const Key('workspace-session-transcript')),
        findsNothing,
      );
      expect(find.text('Keep this session with project A.'), findsNothing);
      expect(
        find.byKey(const Key('sidebar-project-session-list')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('sidebar-project-session-list')),
          matching: find.text('分析项目A'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Start a fresh session for project A.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.promptRequests, hasLength(2));
      expect(piHostClient.promptRequests.last.sessionId, isNot(firstSessionId));
      expect(
        piHostClient.promptRequests.last.text,
        'Start a fresh session for project A.',
      );
    },
  );

  testWidgets(
    'selected project hides overview content until a session has activity',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      expect(find.byKey(const Key('project-overview-title')), findsNothing);
      expect(
        find.byKey(const Key('workspace-suggested-prompts')),
        findsNothing,
      );
      expect(find.text('Project details'), findsNothing);
      expect(find.text('Recent targets'), findsNothing);
      expect(find.text('yuance'), findsNothing);
      expect(find.text('novel-1'), findsNothing);
      expect(find.byKey(const Key('composer-session-cwd')), findsOneWidget);
      expect(find.text(workspacePath), findsWidgets);
    },
  );

  testWidgets(
    'composer echoes the prompt immediately while waiting for Pi acceptance',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final promptResponseCompleter = Completer<bool>();
      final piHostClient = MemoryPiHostClient(
        emitRunStartedOnPrompt: false,
        promptResponseCompleter: promptResponseCompleter,
      );
      addTearDown(() {
        if (!promptResponseCompleter.isCompleted) {
          promptResponseCompleter.complete(true);
        }
      });

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: workspacePath,
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      final composerFinder = find.byKey(const Key('workspace-composer-input'));
      await tester.enterText(composerFinder, 'Render this immediately.');
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await tester.pump();

      final transcriptFinder = find.byKey(
        const Key('workspace-session-transcript'),
      );
      expect(
        find.descendant(
          of: transcriptFinder,
          matching: find.text('Render this immediately.'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('workspace-user-message')), findsOneWidget);
      expect(
        find.byKey(const Key('workspace-assistant-pending-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-assistant-pending-dots')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-assistant-message')),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(composerFinder).controller?.text,
        isEmpty,
      );
      expect(find.text('Waiting for Pi'), findsWidgets);
      expect(piHostClient.promptRequests, hasLength(1));

      promptResponseCompleter.complete(true);
      await settleUi(tester);
    },
  );

  testWidgets('composer submits the prompt on Enter', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final workspacePath = resolveRepoWorkspacePath();
    final piHostClient = MemoryPiHostClient();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        workspaceRootPath: workspacePath,
        piHostClient: piHostClient,
      ),
    );
    await settleUi(tester);

    final composerFinder = find.byKey(const Key('workspace-composer-input'));
    await tester.tap(composerFinder);
    await tester.pump();
    await tester.enterText(
      composerFinder,
      'Summarize the current workspace state.',
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleUi(tester);

    expect(piHostClient.promptRequests, hasLength(1));
    expect(
      piHostClient.promptRequests.single.text,
      'Summarize the current workspace state.',
    );
    expect(find.byKey(const Key('abort-composer-task-button')), findsOneWidget);
    expect(tester.widget<TextField>(composerFinder).controller?.text, isEmpty);
  });

  testWidgets('composer inserts a newline on Shift+Enter', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final workspacePath = resolveRepoWorkspacePath();
    final piHostClient = MemoryPiHostClient();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        workspaceRootPath: workspacePath,
        piHostClient: piHostClient,
      ),
    );
    await settleUi(tester);

    final composerFinder = find.byKey(const Key('workspace-composer-input'));
    await tester.tap(composerFinder);
    await tester.pump();
    await tester.enterText(composerFinder, 'Line 1');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(piHostClient.promptRequests, isEmpty);
    expect(
      tester.widget<TextField>(composerFinder).controller?.text,
      'Line 1\n',
    );
  });

  testWidgets(
    'composer sends the selected project cwd to Pi host and renders stream events',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: workspacePath,
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      await tester.tap(find.byKey(const Key('open-settings-button')));
      await settleUi(tester);
      await tester.tap(find.byKey(const Key('full-access-switch')));
      await settleUi(tester);
      await tester.tap(find.byKey(const Key('back-to-app-button')));
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Review the current desktop workspace shell.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.promptRequests, hasLength(1));
      expect(
        piHostClient.promptRequests.single.text,
        'Review the current desktop workspace shell.',
      );
      expect(piHostClient.createdSessions.single.tools, <String>[
        'read',
        'grep',
        'find',
        'ls',
      ]);
      final hostSession = await piHostClient.getSessionState(
        sessionId: piHostClient.promptRequests.single.sessionId,
      );
      expect(hostSession.cwd, workspacePath);
      expect(find.text('Pi session'), findsOneWidget);
      expect(find.byKey(const Key('workspace-session-header')), findsOneWidget);
      expect(
        find.byKey(const Key('workspace-session-transcript')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('workspace-user-message')), findsOneWidget);
      expect(
        find.text('Review the current desktop workspace shell.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('abort-composer-task-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-assistant-pending-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-assistant-message')),
        findsNothing,
      );

      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.messageDelta,
          sessionId: piHostClient.promptRequests.single.sessionId,
          data: const <String, dynamic>{
            'delta': 'The host stream is connected.',
          },
        ),
      );
      await settleUi(tester);

      expect(find.text('The host stream is connected.'), findsOneWidget);
      expect(
        find.byKey(const Key('workspace-assistant-message')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-streaming-indicator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-assistant-pending-message')),
        findsNothing,
      );

      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.toolStarted,
          sessionId: piHostClient.promptRequests.single.sessionId,
          data: const <String, dynamic>{'toolName': 'read'},
        ),
      );
      await settleUi(tester);

      expect(
        find.byKey(const Key('workspace-session-active-tool')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('workspace-session-active-tool')),
          matching: find.text('Running read'),
        ),
        findsOneWidget,
      );

      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.toolCompleted,
          sessionId: piHostClient.promptRequests.single.sessionId,
        ),
      );
      await settleUi(tester);

      expect(
        find.byKey(const Key('workspace-session-active-tool')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('abort-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.abortedSessionIds, <String>[
        piHostClient.promptRequests.single.sessionId,
      ]);
      expect(find.text('Task aborted'), findsWidgets);
      expect(
        find.byKey(const Key('workspace-streaming-indicator')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('submit-composer-task-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'conversation transcript keeps message bubbles within a narrow light workspace',
    (tester) async {
      tester.view.physicalSize = const Size(760, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          preferencesStore: MemoryDesktopPreferencesStore(
            initialPreferences: const AppPreferences(
              themeMode: AppThemeMode.light,
              interfaceDensity: AppInterfaceDensity.compact,
            ),
          ),
          runtimeController: MemoryDesktopRuntimeController(),
          piConfigStore: MemoryPiConfigStore(),
          piHostClient: piHostClient,
          workspaceRootPath: workspacePath,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Inspect https://example.com/a-very-long-unbroken-workspace-reference-that-must-stay-contained.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);
      piHostClient.emit(
        PiHostEvent(
          type: PiHostEventType.messageDelta,
          sessionId: piHostClient.promptRequests.single.sessionId,
          data: const <String, dynamic>{
            'delta':
                'The response keeps a readable line height while a long path such as /Users/chen/code/pi-app/desktop/lib/src/workspace_components.dart remains inside the transcript.',
          },
        ),
      );
      await settleUi(tester);

      final transcript = find.byKey(const Key('workspace-session-transcript'));
      final userBubble = find.byKey(const Key('workspace-message-0'));
      final assistantMessage = find.byKey(const Key('workspace-message-1'));
      final transcriptRect = tester.getRect(transcript);
      final userBubbleRect = tester.getRect(userBubble);
      final assistantRect = tester.getRect(assistantMessage);
      final sessionStatus = find.descendant(
        of: find.byKey(const Key('workspace-session-header')),
        matching: find.text('Pi is running'),
      );
      final assistantRole = find.descendant(
        of: assistantMessage,
        matching: find.text('Pi'),
      );

      expect(Theme.of(tester.element(transcript)).brightness, Brightness.light);
      expect(
        userBubbleRect.width,
        lessThanOrEqualTo(transcriptRect.width * 0.83),
      );
      expect(userBubbleRect.left, greaterThanOrEqualTo(transcriptRect.left));
      expect(userBubbleRect.right, lessThanOrEqualTo(transcriptRect.right));
      expect(assistantRect.left, greaterThanOrEqualTo(transcriptRect.left));
      expect(assistantRect.right, lessThanOrEqualTo(transcriptRect.right));
      expect(
        tester.widget<Text>(sessionStatus).style?.color,
        const Color(0xFF5D6774),
      );
      expect(
        tester.widget<Text>(assistantRole).style?.color,
        const Color(0xFF232831),
      );
      expect(
        tester.widget<Text>(find.text('Generating')).style?.color,
        const Color(0xFF5D6774),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'host failure clears stale sessions so the next task creates a new one',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final piHostClient = MemoryPiHostClient();

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: workspacePath,
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Start the first task.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);
      final firstSessionId = piHostClient.promptRequests.single.sessionId;
      expect(piHostClient.createdSessions.single.tools, <String>[
        'read',
        'grep',
        'find',
        'ls',
        'bash',
        'edit',
        'write',
      ]);

      piHostClient.emit(
        const PiHostEvent(
          type: PiHostEventType.hostError,
          data: <String, dynamic>{'message': 'Pi host exited unexpectedly.'},
        ),
      );
      await settleUi(tester);

      expect(
        find.byKey(const Key('submit-composer-task-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('abort-composer-task-button')), findsNothing);
      expect(find.byKey(const Key('workspace-session-error')), findsOneWidget);
      expect(find.text('Pi host exited unexpectedly.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Create a replacement session.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.promptRequests, hasLength(2));
      expect(piHostClient.promptRequests.last.sessionId, isNot(firstSessionId));
    },
  );

  testWidgets(
    'extension-handled prompt settles without leaving composer running',
    (tester) async {
      configureWindow(tester);
      addTearDown(() => resetWindow(tester));
      final workspacePath = resolveRepoWorkspacePath();
      final piHostClient = MemoryPiHostClient(
        emitRunStartedOnPrompt: false,
        settleWithoutRunOnPrompt: true,
      );

      await tester.pumpWidget(
        PiDesktopApp(
          enablePersistence: false,
          workspaceRootPath: workspacePath,
          piHostClient: piHostClient,
        ),
      );
      await settleUi(tester);

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        '/local-extension-command',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.text('Task completed'), findsWidgets);
      expect(
        find.byKey(const Key('submit-composer-task-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('abort-composer-task-button')), findsNothing);
    },
  );

  testWidgets('pi config settings edit prompts and model preferences', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final piConfigStore = MemoryPiConfigStore(
      rootPath: '/mock/.pi/agent',
      settingsJsonContent:
          '{"defaultProvider":"anthropic","defaultModel":"claude-sonnet-4-20250514"}',
      modelsJsonContent:
          '{"providers":{"ollama":{"models":[{"id":"qwen2.5-coder:7b"}]}}}',
      authJsonContent: '{"anthropic":{"type":"apiKey"}}',
      promptContents: const <PiPromptFileKind, String>{
        PiPromptFileKind.system: 'Base system prompt',
        PiPromptFileKind.agents: 'Always cite files.',
      },
    );

    await tester.pumpWidget(
      PiDesktopApp(enablePersistence: false, piConfigStore: piConfigStore),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pi Models').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pi-models-page-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('pi-default-provider-field')),
      'openai',
    );
    await tester.enterText(
      find.byKey(const Key('pi-default-model-field')),
      'gpt-4o',
    );
    await tester.tap(find.byKey(const Key('pi-thinking-level-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pi-enabled-models-field')),
      'gpt-4o\nclaude-*',
    );
    await tester.ensureVisible(
      find.byKey(const Key('save-pi-model-settings-button')),
    );
    await tester.tap(find.byKey(const Key('save-pi-model-settings-button')));
    await tester.pumpAndSettle();

    expect(piConfigStore.lastSavedModelPreferences?.defaultProvider, 'openai');
    expect(piConfigStore.lastSavedModelPreferences?.defaultModel, 'gpt-4o');
    expect(
      piConfigStore.lastSavedModelPreferences?.defaultThinkingLevel,
      'high',
    );
    expect(piConfigStore.lastSavedModelPreferences?.enabledModels, <String>[
      'gpt-4o',
      'claude-*',
    ]);

    await tester.enterText(
      find.byKey(const Key('pi-models-json-editor')),
      '{"providers":{"local":{"models":[{"id":"gpt-oss:20b"}]}}}',
    );
    await tester.ensureVisible(
      find.byKey(const Key('save-pi-models-json-button')),
    );
    await tester.tap(find.byKey(const Key('save-pi-models-json-button')));
    await tester.pumpAndSettle();

    expect(
      piConfigStore.lastSavedModelsJsonContent,
      '{"providers":{"local":{"models":[{"id":"gpt-oss:20b"}]}}}',
    );

    await tester.tap(find.text('Pi Prompts').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pi-prompts-page-title')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('pi-agents-prompt-editor')),
      'Use AGENTS globally.',
    );
    await tester.ensureVisible(
      find.byKey(const Key('save-pi-agents-prompt-button')),
    );
    await tester.tap(find.byKey(const Key('save-pi-agents-prompt-button')));
    await tester.pumpAndSettle();

    expect(piConfigStore.lastSavedPromptKind, PiPromptFileKind.agents);
    expect(piConfigStore.lastSavedPromptContent, 'Use AGENTS globally.');
  });

  testWidgets('workspace open action shows failure feedback', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final runtimeController = MemoryDesktopRuntimeController(
      openResult: const DesktopOpenResult.failure('boom'),
    );
    final workspacePath = resolveRepoWorkspacePath();

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        workspaceRootPath: workspacePath,
      ),
    );
    await settleUi(tester);

    await tester.tap(find.byKey(const Key('open-project-button-pi-app')));
    await settleUi(tester);

    expect(find.text('Could not open in VS Code: boom'), findsOneWidget);
  });

  testWidgets('theme mode switch updates material app theme mode', (
    tester,
  ) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));

    await tester.pumpWidget(const PiDesktopApp(enablePersistence: false));
    await tester.pumpAndSettle();

    MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').first);
    await tester.pumpAndSettle();

    app = tester.widget(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('restores persisted preferences from store', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final store = MemoryDesktopPreferencesStore(
      initialPreferences: const AppPreferences(
        language: AppLanguage.simplifiedChinese,
        themeMode: AppThemeMode.light,
        uiScale: AppUiScale.small,
        interfaceDensity: AppInterfaceDensity.compact,
        codeFont: AppCodeFont.systemMono,
        openDestination: AppOpenDestination.terminal,
        defaultPermissions: false,
        autoReview: false,
        fullAccess: false,
        showInMenuBar: false,
        showBottomPanel: true,
        preventSleep: true,
        suggestedPrompts: true,
      ),
    );

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: true,
        preferencesStore: store,
        projectRegistryStore: MemoryProjectRegistryStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新任务'), findsOneWidget);
    expect(find.text('交给 Pi 处理'), findsOneWidget);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('终端'), findsOneWidget);

    await tester.tap(find.text('外观').first);
    await tester.pumpAndSettle();

    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('系统等宽'), findsOneWidget);
  });
}
