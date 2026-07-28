import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Directory resolveDesktopDirectory() {
    final current = Directory.current.absolute;
    final candidates = <Directory>[
      current,
      Directory('${current.path}${Platform.pathSeparator}desktop'),
      current.parent,
      Directory('${current.parent.path}${Platform.pathSeparator}desktop'),
    ];

    return candidates.firstWhere(
      (candidate) => Directory(
        '${candidate.path}${Platform.pathSeparator}macos',
      ).existsSync(),
      orElse: () =>
          throw StateError('Unable to resolve the desktop directory.'),
    );
  }

  final desktopDirectory = resolveDesktopDirectory();
  final repositoryDirectory = desktopDirectory.parent;

  String desktopPath(String relativePath) =>
      '${desktopDirectory.path}${Platform.pathSeparator}$relativePath';

  String repositoryPath(String relativePath) =>
      '${repositoryDirectory.path}${Platform.pathSeparator}$relativePath';

  test(
    'macOS build configurations use distinct development and release identities',
    () {
      final project = File(
        desktopPath('macos/Runner.xcodeproj/project.pbxproj'),
      ).readAsStringSync();
      final appInfo = File(
        desktopPath('macos/Runner/Configs/AppInfo.xcconfig'),
      ).readAsStringSync();

      expect(
        RegExp(
          r'ASSETCATALOG_COMPILER_APPICON_NAME = AppIconDev;',
        ).allMatches(project),
        hasLength(2),
      );
      expect(
        RegExp(
          r'PRODUCT_BUNDLE_IDENTIFIER = dev\.pi\.piDesktop\.dev;',
        ).allMatches(project),
        hasLength(2),
      );
      expect(
        RegExp(r'PRODUCT_NAME = "Pi App Dev";').allMatches(project),
        hasLength(2),
      );
      expect(
        project,
        contains(
          'TEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Pi App Dev.app/'
          '\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Pi App Dev";',
        ),
      );
      expect(
        RegExp(
          r'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
        ).allMatches(project),
        hasLength(1),
      );
      expect(appInfo, contains('PRODUCT_NAME = Pi App'));
      expect(appInfo, contains('PRODUCT_BUNDLE_IDENTIFIER = dev.pi.piDesktop'));
      expect(
        project,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Release.entitlements;'),
      );
      expect(
        project,
        contains(
          'TEST_HOST = "\$(BUILT_PRODUCTS_DIR)/Pi App.app/'
          '\$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Pi App";',
        ),
      );
    },
  );

  test('macOS development icon set is complete and distinct', () {
    final sourceDirectory = Directory(
      repositoryPath('assets/branding/export/macos/AppIcon.appiconset'),
    );
    final developmentDirectory = Directory(
      repositoryPath('assets/branding/export/macos/AppIconDev.appiconset'),
    );
    final runnerDirectory = Directory(
      desktopPath('macos/Runner/Assets.xcassets/AppIconDev.appiconset'),
    );
    const filenames = <String>[
      'Contents.json',
      'app_icon_16.png',
      'app_icon_32.png',
      'app_icon_64.png',
      'app_icon_128.png',
      'app_icon_256.png',
      'app_icon_512.png',
      'app_icon_1024.png',
    ];

    for (final filename in filenames) {
      final releaseFile = File(
        '${sourceDirectory.path}${Platform.pathSeparator}$filename',
      );
      final developmentFile = File(
        '${developmentDirectory.path}${Platform.pathSeparator}$filename',
      );
      final runnerFile = File(
        '${runnerDirectory.path}${Platform.pathSeparator}$filename',
      );

      expect(releaseFile.existsSync(), isTrue, reason: releaseFile.path);
      expect(
        developmentFile.existsSync(),
        isTrue,
        reason: developmentFile.path,
      );
      expect(runnerFile.existsSync(), isTrue, reason: runnerFile.path);
      expect(runnerFile.readAsBytesSync(), developmentFile.readAsBytesSync());
    }

    expect(
      File(
        '${sourceDirectory.path}${Platform.pathSeparator}app_icon_1024.png',
      ).readAsBytesSync(),
      isNot(
        File(
          '${developmentDirectory.path}${Platform.pathSeparator}'
          'app_icon_1024.png',
        ).readAsBytesSync(),
      ),
    );
  });

  test('macOS runtime resolves the icon declared by its app bundle', () {
    final appDelegate = File(
      desktopPath('macos/Runner/AppDelegate.swift'),
    ).readAsStringSync();
    final verifier = File(desktopPath('scripts/verify-macos-app-identity.sh'));

    expect(appDelegate, contains('CFBundleIconFile'));
    expect(
      appDelegate,
      contains('path(forResource: iconName, ofType: "icns")'),
    );
    expect(verifier.existsSync(), isTrue);
    expect(verifier.readAsStringSync(), contains('AppIconDev'));
    expect(verifier.readAsStringSync(), contains('dev.pi.piDesktop.dev'));
  });
}
