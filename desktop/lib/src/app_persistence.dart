import 'dart:convert';
import 'dart:io';

import 'app_preferences.dart';

abstract class DesktopPreferencesStore {
  Future<AppPreferences> loadPreferences();

  Future<void> savePreferences(AppPreferences preferences);
}

class FileDesktopPreferencesStore implements DesktopPreferencesStore {
  FileDesktopPreferencesStore({Directory? rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  Directory resolveRootDirectory() {
    if (_rootDirectory != null) {
      return _rootDirectory;
    }

    final home = Platform.environment['HOME']?.trim();
    final userProfile = Platform.environment['USERPROFILE']?.trim();
    final basePath = (home != null && home.isNotEmpty)
        ? home
        : (userProfile != null && userProfile.isNotEmpty ? userProfile : null);

    if (basePath == null) {
      throw StateError('Unable to resolve home directory for ~/.pi-app');
    }

    return Directory('$basePath${Platform.pathSeparator}.pi-app');
  }

  File resolveSettingsFile() {
    final root = resolveRootDirectory();
    return File('${root.path}${Platform.pathSeparator}settings.json');
  }

  @override
  Future<AppPreferences> loadPreferences() async {
    const defaults = AppPreferences();

    try {
      final file = resolveSettingsFile();
      if (!await file.exists()) {
        return defaults;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return defaults;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return defaults;
      }

      return AppPreferences(
        language:
            _deserializeLanguage(decoded['language']?.toString()) ??
            defaults.language,
        themeMode:
            _deserializeThemeMode(decoded['themeMode']?.toString()) ??
            defaults.themeMode,
        uiScale:
            _deserializeUiScale(decoded['uiScale']?.toString()) ??
            defaults.uiScale,
        interfaceDensity:
            _deserializeInterfaceDensity(
              decoded['interfaceDensity']?.toString(),
            ) ??
            defaults.interfaceDensity,
        codeFont:
            _deserializeCodeFont(decoded['codeFont']?.toString()) ??
            defaults.codeFont,
        openDestination:
            _deserializeOpenDestination(
              decoded['openDestination']?.toString(),
            ) ??
            defaults.openDestination,
        defaultPermissions:
            _decodeBool(decoded['defaultPermissions']) ??
            defaults.defaultPermissions,
        autoReview: _decodeBool(decoded['autoReview']) ?? defaults.autoReview,
        fullAccess: _decodeBool(decoded['fullAccess']) ?? defaults.fullAccess,
        showInMenuBar:
            _decodeBool(decoded['showInMenuBar']) ?? defaults.showInMenuBar,
        showBottomPanel:
            _decodeBool(decoded['showBottomPanel']) ?? defaults.showBottomPanel,
        preventSleep:
            _decodeBool(decoded['preventSleep']) ?? defaults.preventSleep,
        suggestedPrompts:
            _decodeBool(decoded['suggestedPrompts']) ??
            defaults.suggestedPrompts,
      );
    } catch (_) {
      return defaults;
    }
  }

  @override
  Future<void> savePreferences(AppPreferences preferences) async {
    final file = resolveSettingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'language': _serializeLanguage(preferences.language),
        'themeMode': _serializeThemeMode(preferences.themeMode),
        'uiScale': _serializeUiScale(preferences.uiScale),
        'interfaceDensity': _serializeInterfaceDensity(
          preferences.interfaceDensity,
        ),
        'codeFont': _serializeCodeFont(preferences.codeFont),
        'openDestination': _serializeOpenDestination(
          preferences.openDestination,
        ),
        'defaultPermissions': preferences.defaultPermissions,
        'autoReview': preferences.autoReview,
        'fullAccess': preferences.fullAccess,
        'showInMenuBar': preferences.showInMenuBar,
        'showBottomPanel': preferences.showBottomPanel,
        'preventSleep': preferences.preventSleep,
        'suggestedPrompts': preferences.suggestedPrompts,
      }),
      flush: true,
    );
  }
}

class MemoryDesktopPreferencesStore implements DesktopPreferencesStore {
  MemoryDesktopPreferencesStore({AppPreferences? initialPreferences})
    : _preferences = initialPreferences ?? const AppPreferences();

  AppPreferences _preferences;

  @override
  Future<AppPreferences> loadPreferences() async => _preferences;

  @override
  Future<void> savePreferences(AppPreferences preferences) async {
    _preferences = preferences;
  }
}

bool? _decodeBool(Object? value) => value is bool ? value : null;

String _serializeLanguage(AppLanguage language) {
  return switch (language) {
    AppLanguage.english => 'english',
    AppLanguage.simplifiedChinese => 'simplifiedChinese',
  };
}

AppLanguage? _deserializeLanguage(String? raw) {
  return switch (raw) {
    'english' => AppLanguage.english,
    'simplifiedChinese' => AppLanguage.simplifiedChinese,
    _ => null,
  };
}

String _serializeThemeMode(AppThemeMode mode) {
  return switch (mode) {
    AppThemeMode.dark => 'dark',
    AppThemeMode.light => 'light',
    AppThemeMode.system => 'system',
  };
}

AppThemeMode? _deserializeThemeMode(String? raw) {
  return switch (raw) {
    'dark' => AppThemeMode.dark,
    'light' => AppThemeMode.light,
    'system' => AppThemeMode.system,
    _ => null,
  };
}

String _serializeUiScale(AppUiScale scale) {
  return switch (scale) {
    AppUiScale.small => 'small',
    AppUiScale.regular => 'regular',
    AppUiScale.large => 'large',
  };
}

AppUiScale? _deserializeUiScale(String? raw) {
  return switch (raw) {
    'small' => AppUiScale.small,
    'regular' => AppUiScale.regular,
    'large' => AppUiScale.large,
    _ => null,
  };
}

String _serializeInterfaceDensity(AppInterfaceDensity density) {
  return switch (density) {
    AppInterfaceDensity.compact => 'compact',
    AppInterfaceDensity.comfortable => 'comfortable',
  };
}

AppInterfaceDensity? _deserializeInterfaceDensity(String? raw) {
  return switch (raw) {
    'compact' => AppInterfaceDensity.compact,
    'comfortable' => AppInterfaceDensity.comfortable,
    _ => null,
  };
}

String _serializeCodeFont(AppCodeFont codeFont) {
  return switch (codeFont) {
    AppCodeFont.jetBrainsMono => 'jetBrainsMono',
    AppCodeFont.systemMono => 'systemMono',
  };
}

AppCodeFont? _deserializeCodeFont(String? raw) {
  return switch (raw) {
    'jetBrainsMono' => AppCodeFont.jetBrainsMono,
    'systemMono' => AppCodeFont.systemMono,
    _ => null,
  };
}

String _serializeOpenDestination(AppOpenDestination destination) {
  return switch (destination) {
    AppOpenDestination.vscode => 'vscode',
    AppOpenDestination.cursor => 'cursor',
    AppOpenDestination.terminal => 'terminal',
  };
}

AppOpenDestination? _deserializeOpenDestination(String? raw) {
  return switch (raw) {
    'vscode' => AppOpenDestination.vscode,
    'cursor' => AppOpenDestination.cursor,
    'terminal' => AppOpenDestination.terminal,
    _ => null,
  };
}
