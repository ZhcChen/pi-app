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
    await tester.tap(find.byKey(const Key('show-bottom-panel-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('prevent-sleep-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggested-prompts-switch')));
    await tester.pumpAndSettle();

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
