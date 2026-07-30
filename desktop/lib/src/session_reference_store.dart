import 'dart:convert';
import 'dart:io';

import 'app_persistence.dart';

class PiSessionReference {
  const PiSessionReference({
    required this.projectPath,
    required this.sessionFile,
    required this.lastOpenedAt,
    this.projectId,
    this.lastKnownSessionId,
    this.sessionName,
    this.pinned = false,
    this.hiddenInPiApp = false,
  });

  factory PiSessionReference.fromJson(Map<String, dynamic> json) {
    final projectPath = _normalizeProjectPath(json['projectPath']?.toString());
    final sessionFile = _normalizeSessionFile(json['sessionFile']?.toString());
    if (projectPath == null || sessionFile == null) {
      throw const FormatException(
        'Pi session reference is missing a project path or session file.',
      );
    }

    final lastOpenedAt = json['lastOpenedAt']?.toString().trim();
    return PiSessionReference(
      projectId: _normalizeProjectId(json['projectId']?.toString()),
      projectPath: projectPath,
      sessionFile: sessionFile,
      lastKnownSessionId: _normalizeNonEmptyString(
        json['lastKnownSessionId']?.toString(),
      ),
      sessionName: _normalizeNonEmptyString(json['sessionName']?.toString()),
      lastOpenedAt: (lastOpenedAt != null && lastOpenedAt.isNotEmpty)
          ? lastOpenedAt
          : DateTime.now().toUtc().toIso8601String(),
      pinned: json['pinned'] == true,
      hiddenInPiApp: json['hiddenInPiApp'] == true,
    );
  }

  final String? projectId;
  final String projectPath;
  final String sessionFile;
  final String? lastKnownSessionId;
  final String? sessionName;
  final String lastOpenedAt;
  final bool pinned;
  final bool hiddenInPiApp;

  String get displayTitle {
    final name = sessionName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final nativeId = lastKnownSessionId?.trim();
    if (nativeId != null && nativeId.isNotEmpty) {
      final shortId = nativeId.length <= 12
          ? nativeId
          : nativeId.substring(nativeId.length - 12);
      return 'Session $shortId';
    }

    final basename = _sessionBasename(sessionFile);
    return basename.isEmpty ? 'Session' : basename;
  }

  PiSessionReference copyWith({
    String? projectId,
    String? projectPath,
    String? sessionFile,
    String? lastKnownSessionId,
    String? sessionName,
    String? lastOpenedAt,
    bool? pinned,
    bool? hiddenInPiApp,
  }) {
    return PiSessionReference(
      projectId: projectId ?? this.projectId,
      projectPath: projectPath ?? this.projectPath,
      sessionFile: sessionFile ?? this.sessionFile,
      lastKnownSessionId: lastKnownSessionId ?? this.lastKnownSessionId,
      sessionName: sessionName ?? this.sessionName,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pinned: pinned ?? this.pinned,
      hiddenInPiApp: hiddenInPiApp ?? this.hiddenInPiApp,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (projectId != null) 'projectId': projectId,
      'projectPath': projectPath,
      'sessionFile': sessionFile,
      if (lastKnownSessionId != null) 'lastKnownSessionId': lastKnownSessionId,
      if (sessionName != null) 'sessionName': sessionName,
      'lastOpenedAt': lastOpenedAt,
      'pinned': pinned,
      'hiddenInPiApp': hiddenInPiApp,
    };
  }
}

class PiSessionReferenceSnapshot {
  const PiSessionReferenceSnapshot({
    this.references = const <PiSessionReference>[],
  });

  final List<PiSessionReference> references;

  List<PiSessionReference> referencesForProject({
    String? projectId,
    required String projectPath,
  }) {
    final matches =
        references
            .where(
              (reference) => _matchesProjectReference(
                reference,
                projectId: projectId,
                projectPath: projectPath,
              ),
            )
            .where((reference) => !reference.hiddenInPiApp)
            .toList(growable: false)
          ..sort(_compareSessionReferences);
    return matches;
  }

  PiSessionReferenceSnapshot upsertReference(PiSessionReference reference) {
    final nextReferences = List<PiSessionReference>.of(references);
    final existingIndex = nextReferences.indexWhere(
      (entry) =>
          _matchesProjectReference(
            entry,
            projectId: reference.projectId,
            projectPath: reference.projectPath,
          ) &&
          _sessionPathKey(entry.sessionFile) ==
              _sessionPathKey(reference.sessionFile),
    );

    if (existingIndex >= 0) {
      nextReferences[existingIndex] = reference;
    } else {
      nextReferences.add(reference);
    }

    return PiSessionReferenceSnapshot(references: nextReferences);
  }

  PiSessionReferenceSnapshot mergedWith(PiSessionReferenceSnapshot other) {
    var merged = PiSessionReferenceSnapshot(
      references: List<PiSessionReference>.of(references),
    );

    for (final reference in other.references) {
      final existing = merged.references.firstWhere(
        (entry) =>
            _matchesProjectReference(
              entry,
              projectId: reference.projectId,
              projectPath: reference.projectPath,
            ) &&
            _sessionPathKey(entry.sessionFile) ==
                _sessionPathKey(reference.sessionFile),
        orElse: () => const PiSessionReference(
          projectPath: '',
          sessionFile: '',
          lastOpenedAt: '',
        ),
      );

      if (existing.projectPath.isEmpty ||
          existing.lastOpenedAt.compareTo(reference.lastOpenedAt) <= 0) {
        merged = merged.upsertReference(reference);
      }
    }

    return merged;
  }
}

abstract class PiSessionReferenceStore {
  Future<PiSessionReferenceSnapshot> loadSnapshot();

  Future<void> saveSnapshot(PiSessionReferenceSnapshot snapshot);
}

class FilePiSessionReferenceStore implements PiSessionReferenceStore {
  FilePiSessionReferenceStore({
    Directory? rootDirectory,
    Map<String, String>? environment,
    bool? isReleaseBuild,
  }) : _rootDirectory = rootDirectory,
       _environment = environment,
       _isReleaseBuild = isReleaseBuild;

  final Directory? _rootDirectory;
  final Map<String, String>? _environment;
  final bool? _isReleaseBuild;

  Directory resolveRootDirectory() {
    return resolvePiAppRootDirectory(
      rootDirectory: _rootDirectory,
      environment: _environment,
      isReleaseBuild: _isReleaseBuild,
    );
  }

  Directory resolveSessionsDirectory() {
    final root = resolveRootDirectory();
    return Directory('${root.path}${Platform.pathSeparator}sessions');
  }

  File resolveIndexFile() {
    final sessionsDirectory = resolveSessionsDirectory();
    return File('${sessionsDirectory.path}${Platform.pathSeparator}index.json');
  }

  @override
  Future<PiSessionReferenceSnapshot> loadSnapshot() async {
    try {
      final file = resolveIndexFile();
      if (!await file.exists()) {
        return const PiSessionReferenceSnapshot();
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const PiSessionReferenceSnapshot();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const PiSessionReferenceSnapshot();
      }

      final items = decoded['references'];
      if (items is! List) {
        return const PiSessionReferenceSnapshot();
      }

      final references = <PiSessionReference>[];
      for (final item in items) {
        if (item is! Map) {
          continue;
        }
        try {
          references.add(
            PiSessionReference.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {}
      }

      return PiSessionReferenceSnapshot(references: references);
    } catch (_) {
      return const PiSessionReferenceSnapshot();
    }
  }

  @override
  Future<void> saveSnapshot(PiSessionReferenceSnapshot snapshot) async {
    final file = resolveIndexFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'references': snapshot.references
            .map((reference) => reference.toJson())
            .toList(growable: false),
      }),
      flush: true,
    );
  }
}

class MemoryPiSessionReferenceStore implements PiSessionReferenceStore {
  MemoryPiSessionReferenceStore({PiSessionReferenceSnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? const PiSessionReferenceSnapshot();

  PiSessionReferenceSnapshot _snapshot;

  @override
  Future<PiSessionReferenceSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(PiSessionReferenceSnapshot snapshot) async {
    _snapshot = snapshot;
  }
}

int _compareSessionReferences(
  PiSessionReference left,
  PiSessionReference right,
) {
  if (left.pinned != right.pinned) {
    return left.pinned ? -1 : 1;
  }

  final openedOrder = right.lastOpenedAt.compareTo(left.lastOpenedAt);
  if (openedOrder != 0) {
    return openedOrder;
  }

  return left.displayTitle.compareTo(right.displayTitle);
}

bool _matchesProjectReference(
  PiSessionReference reference, {
  String? projectId,
  required String projectPath,
}) {
  final normalizedProjectId = _normalizeProjectId(projectId);
  if (reference.projectId != null && normalizedProjectId != null) {
    return reference.projectId == normalizedProjectId;
  }

  return _projectPathKey(reference.projectPath) == _projectPathKey(projectPath);
}

String? _normalizeProjectId(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _normalizeProjectPath(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return Directory(trimmed).absolute.path;
}

String? _normalizeSessionFile(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return File(trimmed).absolute.path;
}

String? _normalizeNonEmptyString(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String _projectPathKey(String path) {
  return Platform.isWindows ? path.toLowerCase() : path;
}

String _sessionPathKey(String path) {
  return Platform.isWindows ? path.toLowerCase() : path;
}

String _sessionBasename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final basename = normalized.split('/').last;
  return basename.replaceFirst(RegExp(r'\.(jsonl|ndjson)$'), '');
}
