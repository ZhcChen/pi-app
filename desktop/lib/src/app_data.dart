import 'dart:io';

import 'package:flutter/material.dart';

import 'app_copy.dart';
import 'project_registry_store.dart';
import 'workspace_feature.dart';

List<WorkspaceAction> buildPrimaryActions(AppCopy copy) {
  return [
    WorkspaceAction(
      label: copy.isChinese ? '新任务' : 'New task',
      icon: Icons.edit_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '计划任务' : 'Scheduled',
      icon: Icons.schedule_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '插件' : 'Plugins',
      icon: Icons.extension_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '拉取请求' : 'Pull requests',
      icon: Icons.call_split_outlined,
    ),
  ];
}

List<WorkspacePromptCard> buildPromptCards(AppCopy copy) {
  return [
    WorkspacePromptCard(
      title: copy.promptExplore,
      icon: Icons.travel_explore_outlined,
      color: const Color(0xFF3CA4FF),
    ),
    WorkspacePromptCard(
      title: copy.promptBuild,
      icon: Icons.auto_fix_high_outlined,
      color: const Color(0xFFB57BFF),
    ),
    WorkspacePromptCard(
      title: copy.promptReview,
      icon: Icons.sync_alt_rounded,
      color: const Color(0xFF39D273),
    ),
    WorkspacePromptCard(
      title: copy.promptFix,
      icon: Icons.local_fire_department_outlined,
      color: const Color(0xFFFF8A3C),
    ),
  ];
}

List<WorkspaceProjectGroup> buildDesktopProjects(
  String? workspaceRootPath, {
  List<ProjectRegistryEntry> registeredProjects =
      const <ProjectRegistryEntry>[],
}) {
  final projectRoots = _resolveProjectRoots(
    workspaceRootPath,
    registeredProjects,
  );
  if (projectRoots.isEmpty) {
    return const <WorkspaceProjectGroup>[];
  }

  final projects = <WorkspaceProjectGroup>[];
  for (final root in projectRoots) {
    final project = _buildWorkspaceProject(
      root.path,
      registryEntry: root.registryEntry,
    );
    if (project != null) {
      projects.add(project);
    }
  }
  return projects;
}

class _WorkspaceProjectRoot {
  const _WorkspaceProjectRoot({required this.path, this.registryEntry});

  final String path;
  final ProjectRegistryEntry? registryEntry;
}

List<_WorkspaceProjectRoot> _resolveProjectRoots(
  String? workspaceRootPath,
  List<ProjectRegistryEntry> registeredProjects,
) {
  final roots = <_WorkspaceProjectRoot>[];
  final indicesByPath = <String, int>{};

  void addRoot(String? rawPath, {ProjectRegistryEntry? registryEntry}) {
    final normalized = _normalizeProjectRoot(rawPath);
    if (normalized == null) {
      return;
    }

    final pathKey = _projectRootKey(normalized);
    final existingIndex = indicesByPath[pathKey];
    if (existingIndex == null) {
      indicesByPath[pathKey] = roots.length;
      roots.add(
        _WorkspaceProjectRoot(path: normalized, registryEntry: registryEntry),
      );
      return;
    }

    if (registryEntry != null && roots[existingIndex].registryEntry == null) {
      roots[existingIndex] = _WorkspaceProjectRoot(
        path: normalized,
        registryEntry: registryEntry,
      );
    }
  }

  addRoot(_resolveWorkspaceRoot(workspaceRootPath));
  for (final project in registeredProjects) {
    addRoot(project.path, registryEntry: project);
  }

  return roots;
}

WorkspaceProjectGroup? _buildWorkspaceProject(
  String rootPath, {
  ProjectRegistryEntry? registryEntry,
}) {
  final rootDirectory = Directory(rootPath);
  if (!rootDirectory.existsSync()) {
    return null;
  }

  final gitInfo = _resolveGitInfo(rootDirectory);
  final recentTargets = _buildRecentTargets(rootDirectory);

  return WorkspaceProjectGroup(
    name: registryEntry?.displayName ?? _basename(rootDirectory.path),
    branch: gitInfo.branch,
    items: recentTargets,
    workspacePath: rootDirectory.path,
    sessionCwd: rootDirectory.path,
    isGitRepository: gitInfo.isGitRepository,
    registryId: registryEntry?.id,
    isPinned: registryEntry?.isPinned ?? false,
  );
}

String? _resolveWorkspaceRoot(String? workspaceRootPath) {
  return _normalizeProjectRoot(workspaceRootPath);
}

String? _normalizeProjectRoot(String? rawPath) {
  final trimmed = rawPath?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  return Directory(trimmed).absolute.path;
}

String _projectRootKey(String path) {
  return Platform.isWindows ? path.toLowerCase() : path;
}

List<WorkspaceProjectItem> _buildRecentTargets(Directory rootDirectory) {
  final items = <WorkspaceProjectItem>[];
  final candidatePaths = <String>['README.md', 'docs', 'desktop', 'assets'];

  for (final relativePath in candidatePaths) {
    final targetPath = _resolveWorkspacePath(rootDirectory.path, relativePath);
    if (targetPath == null) {
      continue;
    }

    final file = File(targetPath);
    final directory = Directory(targetPath);
    final exists = file.existsSync() || directory.existsSync();
    if (!exists) {
      continue;
    }

    items.add(
      WorkspaceProjectItem(
        label: _basename(relativePath),
        targetPath: targetPath,
        relativePath: relativePath,
        kind: directory.existsSync()
            ? WorkspaceProjectItemKind.directory
            : WorkspaceProjectItemKind.file,
      ),
    );
  }

  if (items.isNotEmpty) {
    return items;
  }

  final fallbackEntries =
      rootDirectory
          .listSync(followLinks: false)
          .where((entry) => !_basename(entry.path).startsWith('.'))
          .toList()
        ..sort((a, b) => _basename(a.path).compareTo(_basename(b.path)));

  for (final entry in fallbackEntries.take(4)) {
    items.add(
      WorkspaceProjectItem(
        label: _basename(entry.path),
        targetPath: entry.path,
        relativePath: _basename(entry.path),
        kind: entry is Directory
            ? WorkspaceProjectItemKind.directory
            : WorkspaceProjectItemKind.file,
      ),
    );
  }

  return items;
}

({String? branch, bool isGitRepository}) _resolveGitInfo(
  Directory rootDirectory,
) {
  final gitMetadataDirectory = _resolveGitMetadataDirectory(rootDirectory);
  if (gitMetadataDirectory == null) {
    return (branch: null, isGitRepository: false);
  }

  final headFile = File(
    '${gitMetadataDirectory.path}${Platform.pathSeparator}HEAD',
  );
  if (!headFile.existsSync()) {
    return (branch: null, isGitRepository: true);
  }

  try {
    final rawHead = headFile.readAsStringSync().trim();
    if (rawHead.startsWith('ref: ')) {
      final reference = rawHead.substring(5).trim();
      return (branch: reference.split('/').last, isGitRepository: true);
    }

    final detachedHead = rawHead.length > 7 ? rawHead.substring(0, 7) : rawHead;
    return (branch: detachedHead, isGitRepository: true);
  } catch (_) {
    return (branch: null, isGitRepository: true);
  }
}

Directory? _resolveGitMetadataDirectory(Directory rootDirectory) {
  final gitDirectory = Directory(
    '${rootDirectory.path}${Platform.pathSeparator}.git',
  );
  if (gitDirectory.existsSync()) {
    return gitDirectory;
  }

  final gitFile = File('${rootDirectory.path}${Platform.pathSeparator}.git');
  if (!gitFile.existsSync()) {
    return null;
  }

  try {
    final rawContent = gitFile.readAsStringSync().trim();
    if (!rawContent.startsWith('gitdir:')) {
      return null;
    }

    final relativeGitPath = rawContent.substring('gitdir:'.length).trim();
    final resolvedPath = Uri.directory(
      rootDirectory.path.endsWith(Platform.pathSeparator)
          ? rootDirectory.path
          : '${rootDirectory.path}${Platform.pathSeparator}',
    ).resolve(relativeGitPath).toFilePath(windows: Platform.isWindows);

    final metadataDirectory = Directory(resolvedPath);
    if (!metadataDirectory.existsSync()) {
      return null;
    }
    return metadataDirectory;
  } catch (_) {
    return null;
  }
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  final trimmed = normalized.endsWith('/') && normalized.length > 1
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
  final segments = trimmed.split('/');
  return segments.isEmpty ? trimmed : segments.last;
}

String? _resolveWorkspacePath(String workspaceRootPath, String relativePath) {
  if (workspaceRootPath.isEmpty) {
    return null;
  }

  return Uri.directory(
    workspaceRootPath.endsWith(Platform.pathSeparator)
        ? workspaceRootPath
        : '$workspaceRootPath${Platform.pathSeparator}',
  ).resolve(relativePath).toFilePath(windows: Platform.isWindows);
}
