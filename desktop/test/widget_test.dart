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

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        workspaceRootPath: '/workspace/pi-app',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-project-button-pi-app')));
    await tester.pumpAndSettle();

    expect(
      runtimeController.lastOpenRequest?.destination,
      AppOpenDestination.vscode,
    );
    expect(runtimeController.lastOpenRequest?.targetPath, '/workspace/pi-app');
    expect(
      runtimeController.lastOpenRequest?.workspacePath,
      '/workspace/pi-app',
    );

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-destination-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back-to-app-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('open-project-item-button-runtime bridge')),
    );
    await tester.pumpAndSettle();

    expect(
      runtimeController.lastOpenRequest?.destination,
      AppOpenDestination.terminal,
    );
    expect(
      runtimeController.lastOpenRequest?.targetPath,
      '/workspace/pi-app/desktop/lib/src/app_runtime.dart',
    );
    expect(runtimeController.openCount, 2);
  });

  testWidgets('workspace open action shows failure feedback', (tester) async {
    configureWindow(tester);
    addTearDown(() => resetWindow(tester));
    final runtimeController = MemoryDesktopRuntimeController(
      openResult: const DesktopOpenResult.failure('boom'),
    );

    await tester.pumpWidget(
      PiDesktopApp(
        enablePersistence: false,
        runtimeController: runtimeController,
        workspaceRootPath: '/workspace/pi-app',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open-project-button-pi-app')));
    await tester.pumpAndSettle();

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
