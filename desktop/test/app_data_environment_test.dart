import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_desktop/src/app_persistence.dart';
import 'package:pi_desktop/src/app_preferences.dart';
import 'package:pi_desktop/src/project_registry_store.dart';

void main() {
  test('resolves distinct development and production data roots', () {
    const homePath = '/home/pi-app-test';
    const environment = <String, String>{'HOME': homePath};

    final developmentRoot = resolvePiAppRootDirectory(
      environment: environment,
      isReleaseBuild: false,
    );
    final productionRoot = resolvePiAppRootDirectory(
      environment: environment,
      isReleaseBuild: true,
    );

    expect(
      developmentRoot.path,
      '$homePath${Platform.pathSeparator}.pi-app-dev',
    );
    expect(productionRoot.path, '$homePath${Platform.pathSeparator}.pi-app');
    expect(developmentRoot.path, isNot(productionRoot.path));
  });

  test(
    'isolates persisted preferences and project registry by build mode',
    () async {
      final home = await Directory.systemTemp.createTemp('pi-app-data-root-');
      addTearDown(() async {
        if (await home.exists()) {
          await home.delete(recursive: true);
        }
      });

      final environment = <String, String>{'HOME': home.path};
      final developmentPreferences = FileDesktopPreferencesStore(
        environment: environment,
        isReleaseBuild: false,
      );
      final productionPreferences = FileDesktopPreferencesStore(
        environment: environment,
        isReleaseBuild: true,
      );
      final developmentRegistry = FileProjectRegistryStore(
        environment: environment,
        isReleaseBuild: false,
      );
      final productionRegistry = FileProjectRegistryStore(
        environment: environment,
        isReleaseBuild: true,
      );
      final workspace = Directory(
        '${home.path}${Platform.pathSeparator}workspace',
      )..createSync(recursive: true);

      await developmentPreferences.savePreferences(
        const AppPreferences(language: AppLanguage.simplifiedChinese),
      );
      await developmentRegistry.addProject(workspace.path);

      expect(
        (await developmentPreferences.loadPreferences()).language,
        AppLanguage.simplifiedChinese,
      );
      expect(
        (await productionPreferences.loadPreferences()).language,
        AppLanguage.english,
      );
      expect((await developmentRegistry.loadSnapshot()).entries, hasLength(1));
      expect((await productionRegistry.loadSnapshot()).entries, isEmpty);
      expect(
        await productionPreferences.resolveSettingsFile().exists(),
        isFalse,
      );
      expect(await productionRegistry.resolveIndexFile().exists(), isFalse);
    },
  );
}
