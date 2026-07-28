import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
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
    'platform runtime controller delegates system file and quit actions',
    () async {
      String? openedPath;
      var quitCount = 0;
      final controller = PlatformDesktopRuntimeController(
        openSystemFile: (targetPath) async {
          openedPath = targetPath;
          return const DesktopOpenResult.success();
        },
        quitApplication: () async {
          quitCount += 1;
        },
      );

      final result = await controller.openSystemFile('/tmp/Pi App.dmg');
      await controller.quitApplication();

      expect(result.launched, true);
      expect(openedPath, '/tmp/Pi App.dmg');
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

    expect(
      find.byKey(const Key('workspace-suggested-prompts')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('workspace-bottom-panel')), findsNothing);
    expect(find.text('VS Code · Coding tools · Auto-review'), findsOneWidget);
    expect(runtimeController.lastSyncedPreferences?.showInMenuBar, true);
    expect(runtimeController.lastSyncedPreferences?.preventSleep, false);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const Key('open-destination-dropdown')));
    await settleUi(tester);
    await tester.tap(find.text('Terminal').last);
    await settleUi(tester);
    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await settleUi(tester);

    await tester.tap(
      find.byKey(const Key('open-project-overview-item-button-desktop')),
    );
    await settleUi(tester);

    expect(
      runtimeController.lastOpenRequest?.destination,
      AppOpenDestination.terminal,
    );
    expect(
      runtimeController.lastOpenRequest?.targetPath,
      '$workspacePath${Platform.pathSeparator}desktop',
    );
    expect(runtimeController.openCount, 2);
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
    'workspace overview uses real project data instead of seed items',
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

      expect(find.byKey(const Key('project-overview-title')), findsOneWidget);
      expect(find.text('yuance'), findsNothing);
      expect(find.text('novel-1'), findsNothing);
      expect(find.text('Project overview'), findsOneWidget);
      expect(find.text('docs'), findsWidgets);
      expect(find.text('desktop'), findsWidgets);
      expect(find.text('assets'), findsWidgets);
      expect(find.byKey(const Key('composer-session-cwd')), findsOneWidget);
      expect(find.text(workspacePath), findsWidgets);
    },
  );

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
      expect(
        find.text('Review the current desktop workspace shell.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('abort-composer-task-button')),
        findsOneWidget,
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

      await tester.tap(find.byKey(const Key('abort-composer-task-button')));
      await settleUi(tester);

      expect(piHostClient.abortedSessionIds, <String>[
        piHostClient.promptRequests.single.sessionId,
      ]);
      expect(find.text('Task aborted'), findsWidgets);
      expect(
        find.byKey(const Key('submit-composer-task-button')),
        findsOneWidget,
      );
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
