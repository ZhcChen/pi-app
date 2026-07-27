import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pi_desktop/main.dart';

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
    expect(loaded.defaultPermissions, false);
    expect(loaded.autoReview, false);
    expect(loaded.fullAccess, false);
    expect(loaded.showInMenuBar, false);
    expect(loaded.showBottomPanel, true);
    expect(loaded.preventSleep, true);
    expect(loaded.suggestedPrompts, true);
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

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('workspace-suggested-prompts')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('workspace-bottom-panel')), findsNothing);
    expect(find.text('VS Code · Full access · Auto-review'), findsOneWidget);
    expect(runtimeController.lastSyncedPreferences?.showInMenuBar, true);
    expect(runtimeController.lastSyncedPreferences?.preventSleep, false);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-destination-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('full-access-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('default-permissions-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('auto-review-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-in-menu-bar-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-bottom-panel-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prevent-sleep-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggested-prompts-switch')));
    await tester.pumpAndSettle();

    expect(runtimeController.lastSyncedPreferences?.showInMenuBar, false);
    expect(runtimeController.lastSyncedPreferences?.preventSleep, true);

    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-suggested-prompts')), findsNothing);
    expect(find.byKey(const Key('workspace-bottom-panel')), findsOneWidget);
    expect(find.text('Terminal · Ask first · Manual review'), findsOneWidget);
    expect(find.text('Open: Terminal'), findsOneWidget);
    expect(find.text('Keep awake'), findsOneWidget);
    expect(find.text('Suggested prompts off'), findsOneWidget);
  });

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

    await tester.tap(find.byKey(const Key('open-project-item-button-desktop')));
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
    'composer submit binds task to the selected project session cwd',
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

      await tester.enterText(
        find.byKey(const Key('workspace-composer-input')),
        'Review the current desktop workspace shell.',
      );
      await tester.tap(find.byKey(const Key('submit-composer-task-button')));
      await settleUi(tester);

      expect(find.text('Prepared task'), findsOneWidget);
      expect(
        find.text('Review the current desktop workspace shell.'),
        findsOneWidget,
      );
      expect(find.text(workspacePath), findsWidgets);
      expect(
        find.text('Task is now bound to the session cwd for pi-app.'),
        findsOneWidget,
      );
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
      PiDesktopApp(enablePersistence: true, preferencesStore: store),
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
