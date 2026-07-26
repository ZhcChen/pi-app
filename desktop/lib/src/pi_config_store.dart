import 'dart:convert';
import 'dart:io';

const List<String> piThinkingLevels = <String>[
  'off',
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
];

enum PiConfigRootSource { defaultHome, environmentOverride, injected }

enum PiPromptFileKind { system, appendSystem, agents }

class PiPromptFileDocument {
  const PiPromptFileDocument({
    required this.kind,
    required this.path,
    required this.exists,
    required this.content,
  });

  final PiPromptFileKind kind;
  final String path;
  final bool exists;
  final String content;
}

class PiModelPreferences {
  const PiModelPreferences({
    this.defaultProvider,
    this.defaultModel,
    this.defaultThinkingLevel,
    this.enabledModels = const <String>[],
  });

  final String? defaultProvider;
  final String? defaultModel;
  final String? defaultThinkingLevel;
  final List<String> enabledModels;
}

class PiModelsSummary {
  const PiModelsSummary({
    required this.providerCount,
    required this.customModelCount,
  });

  final int providerCount;
  final int customModelCount;
}

class PiConfigSnapshot {
  const PiConfigSnapshot({
    required this.rootPath,
    required this.rootSource,
    required this.settingsFilePath,
    required this.modelsFilePath,
    required this.authFilePath,
    required this.systemPrompt,
    required this.appendSystemPrompt,
    required this.globalAgents,
    required this.modelPreferences,
    required this.modelsJsonContent,
    required this.modelsSummary,
    required this.authFileExists,
    required this.authProviderCount,
    this.settingsJsonParseError,
    this.modelsJsonParseError,
    this.authJsonParseError,
  });

  final String rootPath;
  final PiConfigRootSource rootSource;
  final String settingsFilePath;
  final String modelsFilePath;
  final String authFilePath;
  final PiPromptFileDocument systemPrompt;
  final PiPromptFileDocument appendSystemPrompt;
  final PiPromptFileDocument globalAgents;
  final PiModelPreferences modelPreferences;
  final String modelsJsonContent;
  final PiModelsSummary modelsSummary;
  final bool authFileExists;
  final int authProviderCount;
  final String? settingsJsonParseError;
  final String? modelsJsonParseError;
  final String? authJsonParseError;

  bool get usesEnvironmentOverride =>
      rootSource == PiConfigRootSource.environmentOverride;
}

abstract class PiConfigStore {
  Future<PiConfigSnapshot> loadSnapshot();

  Future<PiConfigSnapshot> savePromptFile(
    PiPromptFileKind kind,
    String content,
  );

  Future<PiConfigSnapshot> saveModelPreferences(PiModelPreferences preferences);

  Future<PiConfigSnapshot> saveModelsJson(String content);
}

class FilePiConfigStore implements PiConfigStore {
  FilePiConfigStore({
    Directory? rootDirectory,
    Map<String, String>? environment,
  }) : _rootDirectory = rootDirectory,
       _environment = environment;

  final Directory? _rootDirectory;
  final Map<String, String>? _environment;

  Map<String, String> get _resolvedEnvironment =>
      _environment ?? Platform.environment;

  ({Directory directory, PiConfigRootSource source}) resolveRootDirectory() {
    if (_rootDirectory != null) {
      return (directory: _rootDirectory, source: PiConfigRootSource.injected);
    }

    final environmentPath = _resolvedEnvironment['PI_CODING_AGENT_DIR']?.trim();
    if (environmentPath != null && environmentPath.isNotEmpty) {
      return (
        directory: Directory(_expandTilde(environmentPath)),
        source: PiConfigRootSource.environmentOverride,
      );
    }

    final homeDirectory = _resolveHomeDirectory();
    if (homeDirectory == null) {
      throw StateError('Unable to resolve Pi config home directory.');
    }

    return (
      directory: Directory(
        '$homeDirectory.path${Platform.pathSeparator}.pi${Platform.pathSeparator}agent',
      ),
      source: PiConfigRootSource.defaultHome,
    );
  }

  @override
  Future<PiConfigSnapshot> loadSnapshot() async {
    final resolved = resolveRootDirectory();
    return _buildSnapshot(
      rootDirectory: resolved.directory,
      rootSource: resolved.source,
      readFile: (file) async {
        if (!await file.exists()) {
          return null;
        }
        return file.readAsString();
      },
    );
  }

  @override
  Future<PiConfigSnapshot> savePromptFile(
    PiPromptFileKind kind,
    String content,
  ) async {
    final resolved = resolveRootDirectory();
    final file = _promptFileForKind(resolved.directory, kind);
    await _writeOptionalTextFile(file, content);
    return loadSnapshot();
  }

  @override
  Future<PiConfigSnapshot> saveModelPreferences(
    PiModelPreferences preferences,
  ) async {
    final resolved = resolveRootDirectory();
    final settingsFile = _settingsFile(resolved.directory);
    final existingContent = await settingsFile.exists()
        ? await settingsFile.readAsString()
        : null;
    final nextContent = _mergeModelPreferencesIntoSettings(
      existingContent,
      preferences,
    );
    await _writeOptionalTextFile(settingsFile, nextContent);
    return loadSnapshot();
  }

  @override
  Future<PiConfigSnapshot> saveModelsJson(String content) async {
    final resolved = resolveRootDirectory();
    final modelsFile = _modelsFile(resolved.directory);
    final normalized = _normalizeJsonDocument(content);
    await _writeOptionalTextFile(modelsFile, normalized);
    return loadSnapshot();
  }

  Future<void> _writeOptionalTextFile(File file, String? content) async {
    final normalized = content ?? '';
    if (normalized.trim().isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    await file.parent.create(recursive: true);
    await file.writeAsString(normalized, flush: true);
  }

  Directory? _resolveHomeDirectory() {
    final home = _resolvedEnvironment['HOME']?.trim();
    if (home != null && home.isNotEmpty) {
      return Directory(home);
    }

    final userProfile = _resolvedEnvironment['USERPROFILE']?.trim();
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory(userProfile);
    }

    return null;
  }

  String _expandTilde(String rawPath) {
    if (!rawPath.startsWith('~')) {
      return rawPath;
    }

    final homeDirectory = _resolveHomeDirectory();
    if (homeDirectory == null) {
      return rawPath;
    }

    final suffix = rawPath.substring(1);
    return '$homeDirectory.path$suffix';
  }
}

class MemoryPiConfigStore implements PiConfigStore {
  MemoryPiConfigStore({
    this.rootPath = '/mock/.pi/agent',
    this.rootSource = PiConfigRootSource.injected,
    Map<PiPromptFileKind, String>? promptContents,
    String? settingsJsonContent,
    String? modelsJsonContent,
    String? authJsonContent,
  }) : _promptContents = Map<PiPromptFileKind, String>.from(
         promptContents ?? const <PiPromptFileKind, String>{},
       ),
       _settingsJsonContent = settingsJsonContent,
       _modelsJsonContent = modelsJsonContent,
       _authJsonContent = authJsonContent;

  final String rootPath;
  final PiConfigRootSource rootSource;
  final Map<PiPromptFileKind, String> _promptContents;
  String? _settingsJsonContent;
  String? _modelsJsonContent;
  final String? _authJsonContent;

  PiModelPreferences? lastSavedModelPreferences;
  PiPromptFileKind? lastSavedPromptKind;
  String? lastSavedPromptContent;
  String? lastSavedModelsJsonContent;

  @override
  Future<PiConfigSnapshot> loadSnapshot() async {
    final directory = Directory(rootPath);
    return _buildSnapshot(
      rootDirectory: directory,
      rootSource: rootSource,
      readFile: (file) async {
        if (file.path == _settingsFile(directory).path) {
          return _settingsJsonContent;
        }
        if (file.path == _modelsFile(directory).path) {
          return _modelsJsonContent;
        }
        if (file.path == _authFile(directory).path) {
          return _authJsonContent;
        }
        for (final entry in _promptContents.entries) {
          if (file.path == _promptFileForKind(directory, entry.key).path) {
            return entry.value;
          }
        }
        return null;
      },
    );
  }

  @override
  Future<PiConfigSnapshot> savePromptFile(
    PiPromptFileKind kind,
    String content,
  ) async {
    lastSavedPromptKind = kind;
    lastSavedPromptContent = content;
    if (content.trim().isEmpty) {
      _promptContents.remove(kind);
    } else {
      _promptContents[kind] = content;
    }
    return loadSnapshot();
  }

  @override
  Future<PiConfigSnapshot> saveModelPreferences(
    PiModelPreferences preferences,
  ) async {
    lastSavedModelPreferences = preferences;
    _settingsJsonContent = _mergeModelPreferencesIntoSettings(
      _settingsJsonContent,
      preferences,
    );
    return loadSnapshot();
  }

  @override
  Future<PiConfigSnapshot> saveModelsJson(String content) async {
    lastSavedModelsJsonContent = content;
    _modelsJsonContent = _normalizeJsonDocument(content);
    return loadSnapshot();
  }
}

Future<PiConfigSnapshot> _buildSnapshot({
  required Directory rootDirectory,
  required PiConfigRootSource rootSource,
  required Future<String?> Function(File file) readFile,
}) async {
  final settingsFile = _settingsFile(rootDirectory);
  final modelsFile = _modelsFile(rootDirectory);
  final authFile = _authFile(rootDirectory);
  final systemFile = _promptFileForKind(rootDirectory, PiPromptFileKind.system);
  final appendSystemFile = _promptFileForKind(
    rootDirectory,
    PiPromptFileKind.appendSystem,
  );
  final agentsFile = _promptFileForKind(rootDirectory, PiPromptFileKind.agents);

  final settingsContent = await readFile(settingsFile);
  final modelsContent = await readFile(modelsFile);
  final authContent = await readFile(authFile);
  final systemContent = await readFile(systemFile);
  final appendSystemContent = await readFile(appendSystemFile);
  final agentsContent = await readFile(agentsFile);

  final settingsParse = _parseSettingsJson(settingsContent);
  final modelsParse = _parseModelsJson(modelsContent);
  final authParse = _parseAuthJson(authContent);

  return PiConfigSnapshot(
    rootPath: rootDirectory.path,
    rootSource: rootSource,
    settingsFilePath: settingsFile.path,
    modelsFilePath: modelsFile.path,
    authFilePath: authFile.path,
    systemPrompt: PiPromptFileDocument(
      kind: PiPromptFileKind.system,
      path: systemFile.path,
      exists: systemContent != null,
      content: systemContent ?? '',
    ),
    appendSystemPrompt: PiPromptFileDocument(
      kind: PiPromptFileKind.appendSystem,
      path: appendSystemFile.path,
      exists: appendSystemContent != null,
      content: appendSystemContent ?? '',
    ),
    globalAgents: PiPromptFileDocument(
      kind: PiPromptFileKind.agents,
      path: agentsFile.path,
      exists: agentsContent != null,
      content: agentsContent ?? '',
    ),
    modelPreferences: settingsParse.preferences,
    modelsJsonContent: modelsContent ?? '',
    modelsSummary: modelsParse.summary,
    authFileExists: authContent != null,
    authProviderCount: authParse.providerCount,
    settingsJsonParseError: settingsParse.error,
    modelsJsonParseError: modelsParse.error,
    authJsonParseError: authParse.error,
  );
}

File _settingsFile(Directory rootDirectory) {
  return File('${rootDirectory.path}${Platform.pathSeparator}settings.json');
}

File _modelsFile(Directory rootDirectory) {
  return File('${rootDirectory.path}${Platform.pathSeparator}models.json');
}

File _authFile(Directory rootDirectory) {
  return File('${rootDirectory.path}${Platform.pathSeparator}auth.json');
}

File _promptFileForKind(Directory rootDirectory, PiPromptFileKind kind) {
  final fileName = switch (kind) {
    PiPromptFileKind.system => 'SYSTEM.md',
    PiPromptFileKind.appendSystem => 'APPEND_SYSTEM.md',
    PiPromptFileKind.agents => 'AGENTS.md',
  };

  return File('${rootDirectory.path}${Platform.pathSeparator}$fileName');
}

({PiModelPreferences preferences, String? error}) _parseSettingsJson(
  String? rawContent,
) {
  if (rawContent == null || rawContent.trim().isEmpty) {
    return (preferences: const PiModelPreferences(), error: null);
  }

  try {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map<String, dynamic>) {
      return (
        preferences: const PiModelPreferences(),
        error: 'settings.json must contain a JSON object.',
      );
    }

    final enabledModelsRaw = decoded['enabledModels'];
    final enabledModels = enabledModelsRaw is List
        ? enabledModelsRaw
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    return (
      preferences: PiModelPreferences(
        defaultProvider: _trimmedOrNull(decoded['defaultProvider']),
        defaultModel: _trimmedOrNull(decoded['defaultModel']),
        defaultThinkingLevel: _trimmedOrNull(decoded['defaultThinkingLevel']),
        enabledModels: enabledModels,
      ),
      error: null,
    );
  } catch (error) {
    return (preferences: const PiModelPreferences(), error: error.toString());
  }
}

({PiModelsSummary summary, String? error}) _parseModelsJson(
  String? rawContent,
) {
  if (rawContent == null || rawContent.trim().isEmpty) {
    return (
      summary: const PiModelsSummary(providerCount: 0, customModelCount: 0),
      error: null,
    );
  }

  try {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map<String, dynamic>) {
      return (
        summary: const PiModelsSummary(providerCount: 0, customModelCount: 0),
        error: 'models.json must contain a JSON object.',
      );
    }

    final providers = decoded['providers'];
    if (providers is! Map) {
      return (
        summary: const PiModelsSummary(providerCount: 0, customModelCount: 0),
        error: null,
      );
    }

    var customModelCount = 0;
    for (final value in providers.values) {
      if (value is! Map) {
        continue;
      }
      final models = value['models'];
      if (models is List) {
        customModelCount += models.length;
      }
    }

    return (
      summary: PiModelsSummary(
        providerCount: providers.length,
        customModelCount: customModelCount,
      ),
      error: null,
    );
  } catch (error) {
    return (
      summary: const PiModelsSummary(providerCount: 0, customModelCount: 0),
      error: error.toString(),
    );
  }
}

({int providerCount, String? error}) _parseAuthJson(String? rawContent) {
  if (rawContent == null || rawContent.trim().isEmpty) {
    return (providerCount: 0, error: null);
  }

  try {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      return (providerCount: 0, error: 'auth.json must contain a JSON object.');
    }
    return (providerCount: decoded.length, error: null);
  } catch (error) {
    return (providerCount: 0, error: error.toString());
  }
}

String? _trimmedOrNull(Object? raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

String? _mergeModelPreferencesIntoSettings(
  String? existingContent,
  PiModelPreferences preferences,
) {
  Map<String, dynamic> decoded = <String, dynamic>{};
  if (existingContent != null && existingContent.trim().isNotEmpty) {
    final parsed = jsonDecode(existingContent);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('settings.json must contain a JSON object.');
    }
    decoded = Map<String, dynamic>.from(parsed);
  }

  _setOrRemoveString(decoded, 'defaultProvider', preferences.defaultProvider);
  _setOrRemoveString(decoded, 'defaultModel', preferences.defaultModel);
  _setOrRemoveString(
    decoded,
    'defaultThinkingLevel',
    _validatedThinkingLevel(preferences.defaultThinkingLevel),
  );

  if (preferences.enabledModels.isEmpty) {
    decoded.remove('enabledModels');
  } else {
    decoded['enabledModels'] = preferences.enabledModels;
  }

  if (decoded.isEmpty) {
    return null;
  }

  return const JsonEncoder.withIndent('  ').convert(decoded);
}

void _setOrRemoveString(Map<String, dynamic> map, String key, String? value) {
  final normalized = _trimmedOrNull(value);
  if (normalized == null) {
    map.remove(key);
    return;
  }
  map[key] = normalized;
}

String? _validatedThinkingLevel(String? value) {
  final normalized = _trimmedOrNull(value);
  if (normalized == null) {
    return null;
  }
  if (!piThinkingLevels.contains(normalized)) {
    throw FormatException('Unsupported thinking level: $normalized');
  }
  return normalized;
}

String? _normalizeJsonDocument(String content) {
  if (content.trim().isEmpty) {
    return null;
  }

  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'JSON document must contain a top-level object.',
    );
  }
  return content;
}
