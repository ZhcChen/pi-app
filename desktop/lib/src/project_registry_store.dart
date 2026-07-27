import 'dart:convert';
import 'dart:io';

import 'app_persistence.dart';

class ProjectRegistryEntry {
  const ProjectRegistryEntry({
    required this.id,
    required this.path,
    required this.name,
    required this.addedAt,
    this.lastOpenedAt,
  });

  factory ProjectRegistryEntry.create(String path, {DateTime? timestamp}) {
    final normalizedPath = _normalizeProjectPath(path);
    if (normalizedPath == null) {
      throw const FormatException('Project registry entry is missing a path.');
    }

    final resolvedTimestamp = timestamp ?? DateTime.now().toUtc();
    final isoTimestamp = resolvedTimestamp.toIso8601String();

    return ProjectRegistryEntry(
      id: 'project-${resolvedTimestamp.microsecondsSinceEpoch}-${normalizedPath.hashCode.abs()}',
      path: normalizedPath,
      name: _projectNameForPath(normalizedPath),
      addedAt: isoTimestamp,
      lastOpenedAt: isoTimestamp,
    );
  }

  factory ProjectRegistryEntry.fromJson(Map<String, dynamic> json) {
    final rawPath = json['path']?.toString();
    final normalizedPath = _normalizeProjectPath(rawPath);
    if (normalizedPath == null) {
      throw const FormatException('Project registry entry is missing a path.');
    }

    final id = json['id']?.toString().trim();
    final name = json['name']?.toString().trim();
    final addedAt = json['addedAt']?.toString().trim();
    final lastOpenedAt = json['lastOpenedAt']?.toString().trim();

    return ProjectRegistryEntry(
      id: (id != null && id.isNotEmpty)
          ? id
          : 'project-${normalizedPath.hashCode}',
      path: normalizedPath,
      name: (name != null && name.isNotEmpty)
          ? name
          : _projectNameForPath(normalizedPath),
      addedAt: (addedAt != null && addedAt.isNotEmpty)
          ? addedAt
          : DateTime.now().toUtc().toIso8601String(),
      lastOpenedAt: (lastOpenedAt != null && lastOpenedAt.isNotEmpty)
          ? lastOpenedAt
          : null,
    );
  }

  final String id;
  final String path;
  final String name;
  final String addedAt;
  final String? lastOpenedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'path': path,
      'name': name,
      'addedAt': addedAt,
      'lastOpenedAt': lastOpenedAt,
    };
  }
}

class ProjectRegistrySnapshot {
  const ProjectRegistrySnapshot({
    this.entries = const <ProjectRegistryEntry>[],
  });

  final List<ProjectRegistryEntry> entries;

  List<String> get projectPaths {
    return entries.map((entry) => entry.path).toList(growable: false);
  }
}

abstract class ProjectRegistryStore {
  Future<ProjectRegistrySnapshot> loadSnapshot();

  Future<ProjectRegistrySnapshot> addProject(String path);
}

class FileProjectRegistryStore implements ProjectRegistryStore {
  FileProjectRegistryStore({
    Directory? rootDirectory,
    Map<String, String>? environment,
  }) : _rootDirectory = rootDirectory,
       _environment = environment;

  final Directory? _rootDirectory;
  final Map<String, String>? _environment;

  Directory resolveRootDirectory() {
    return resolvePiAppRootDirectory(
      rootDirectory: _rootDirectory,
      environment: _environment,
    );
  }

  Directory resolveProjectsDirectory() {
    final root = resolveRootDirectory();
    return Directory('${root.path}${Platform.pathSeparator}projects');
  }

  File resolveIndexFile() {
    final projectsDirectory = resolveProjectsDirectory();
    return File('${projectsDirectory.path}${Platform.pathSeparator}index.json');
  }

  File resolveSettingsFile() {
    final root = resolveRootDirectory();
    return File('${root.path}${Platform.pathSeparator}settings.json');
  }

  @override
  Future<ProjectRegistrySnapshot> loadSnapshot() async {
    var snapshot = await _loadIndexSnapshot();
    final legacyProjectPaths = await _loadLegacyProjectPaths();
    if (legacyProjectPaths.isEmpty) {
      return snapshot;
    }

    snapshot = _mergeProjectPaths(snapshot, legacyProjectPaths);
    await _saveSnapshot(snapshot);
    await _clearLegacyProjectPaths();
    return snapshot;
  }

  @override
  Future<ProjectRegistrySnapshot> addProject(String path) async {
    final snapshot = await loadSnapshot();
    final normalizedPath = _normalizeProjectPath(path);
    if (normalizedPath == null) {
      return snapshot;
    }

    final normalizedKey = _projectPathKey(normalizedPath);
    final alreadyExists = snapshot.entries.any(
      (entry) => _projectPathKey(entry.path) == normalizedKey,
    );
    if (alreadyExists) {
      return snapshot;
    }

    final nextSnapshot = ProjectRegistrySnapshot(
      entries: <ProjectRegistryEntry>[
        ...snapshot.entries,
        ProjectRegistryEntry.create(normalizedPath),
      ],
    );
    await _saveSnapshot(nextSnapshot);
    return nextSnapshot;
  }

  Future<ProjectRegistrySnapshot> _loadIndexSnapshot() async {
    try {
      final file = resolveIndexFile();
      if (!await file.exists()) {
        return const ProjectRegistrySnapshot();
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const ProjectRegistrySnapshot();
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ProjectRegistrySnapshot();
      }

      final projects = decoded['projects'];
      if (projects is! List) {
        return const ProjectRegistrySnapshot();
      }

      final entries = <ProjectRegistryEntry>[];
      for (final item in projects) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        try {
          entries.add(ProjectRegistryEntry.fromJson(item));
        } catch (_) {}
      }
      return ProjectRegistrySnapshot(entries: entries);
    } catch (_) {
      return const ProjectRegistrySnapshot();
    }
  }

  Future<void> _saveSnapshot(ProjectRegistrySnapshot snapshot) async {
    final file = resolveIndexFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'projects': snapshot.entries.map((entry) => entry.toJson()).toList(),
      }),
      flush: true,
    );
  }

  Future<List<String>> _loadLegacyProjectPaths() async {
    try {
      final settingsFile = resolveSettingsFile();
      if (!await settingsFile.exists()) {
        return const <String>[];
      }

      final raw = await settingsFile.readAsString();
      if (raw.trim().isEmpty) {
        return const <String>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const <String>[];
      }

      final projectPaths = decoded['projectPaths'];
      if (projectPaths is! List) {
        return const <String>[];
      }

      return projectPaths
          .whereType<String>()
          .map(_normalizeProjectPath)
          .whereType<String>()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _clearLegacyProjectPaths() async {
    try {
      final settingsFile = resolveSettingsFile();
      if (!await settingsFile.exists()) {
        return;
      }

      final raw = await settingsFile.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (!decoded.containsKey('projectPaths')) {
        return;
      }

      decoded.remove('projectPaths');
      await settingsFile.writeAsString(jsonEncode(decoded), flush: true);
    } catch (_) {}
  }

  ProjectRegistrySnapshot _mergeProjectPaths(
    ProjectRegistrySnapshot snapshot,
    List<String> projectPaths,
  ) {
    final entries = <ProjectRegistryEntry>[...snapshot.entries];
    final seen = entries.map((entry) => _projectPathKey(entry.path)).toSet();

    for (final projectPath in projectPaths) {
      final normalizedPath = _normalizeProjectPath(projectPath);
      if (normalizedPath == null) {
        continue;
      }

      final pathKey = _projectPathKey(normalizedPath);
      if (!seen.add(pathKey)) {
        continue;
      }

      entries.add(ProjectRegistryEntry.create(normalizedPath));
    }

    return ProjectRegistrySnapshot(entries: entries);
  }
}

class MemoryProjectRegistryStore implements ProjectRegistryStore {
  MemoryProjectRegistryStore({ProjectRegistrySnapshot? initialSnapshot})
    : _snapshot = initialSnapshot ?? const ProjectRegistrySnapshot();

  ProjectRegistrySnapshot _snapshot;

  @override
  Future<ProjectRegistrySnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<ProjectRegistrySnapshot> addProject(String path) async {
    final normalizedPath = _normalizeProjectPath(path);
    if (normalizedPath == null) {
      return _snapshot;
    }

    final pathKey = _projectPathKey(normalizedPath);
    final alreadyExists = _snapshot.entries.any(
      (entry) => _projectPathKey(entry.path) == pathKey,
    );
    if (alreadyExists) {
      return _snapshot;
    }

    _snapshot = ProjectRegistrySnapshot(
      entries: <ProjectRegistryEntry>[
        ..._snapshot.entries,
        ProjectRegistryEntry.create(normalizedPath),
      ],
    );
    return _snapshot;
  }
}

String? _normalizeProjectPath(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return Directory(trimmed).absolute.path;
}

String _projectPathKey(String path) {
  return Platform.isWindows ? path.toLowerCase() : path;
}

String _projectNameForPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final trimmed = normalized.endsWith('/') && normalized.length > 1
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final segments = trimmed.split('/');
  return segments.isEmpty ? trimmed : segments.last;
}
