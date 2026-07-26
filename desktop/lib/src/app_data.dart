import 'dart:io';

import 'package:flutter/material.dart';

import 'app_copy.dart';
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

List<WorkspaceProjectGroup> buildDesktopProjects(String? workspaceRootPath) {
  return [
    WorkspaceProjectGroup(
      name: 'pi-app',
      branch: 'main',
      workspacePath: workspaceRootPath,
      items: [
        WorkspaceProjectItem(
          label: 'desktop shell redesign',
          targetPath: _resolveWorkspacePath(
            workspaceRootPath,
            'docs/plans/2026-07-26-desktop-shell-redesign.md',
          ),
        ),
        WorkspaceProjectItem(
          label: 'runtime bridge',
          targetPath: _resolveWorkspacePath(
            workspaceRootPath,
            'desktop/lib/src/app_runtime.dart',
          ),
        ),
        WorkspaceProjectItem(
          label: 'branding assets',
          targetPath: _resolveWorkspacePath(
            workspaceRootPath,
            'assets/branding',
          ),
        ),
      ],
    ),
    const WorkspaceProjectGroup(
      name: 'yuance',
      branch: 'feature/ui',
      items: [
        WorkspaceProjectItem(label: 'analyze project'),
        WorkspaceProjectItem(label: 'analyze project'),
        WorkspaceProjectItem(label: 'analyze project'),
      ],
    ),
    const WorkspaceProjectGroup(
      name: 'novel-1',
      branch: 'local',
      items: [WorkspaceProjectItem(label: 'draft scene')],
    ),
  ];
}

String? _resolveWorkspacePath(String? workspaceRootPath, String relativePath) {
  if (workspaceRootPath == null || workspaceRootPath.isEmpty) {
    return null;
  }

  return Uri.directory(
    workspaceRootPath.endsWith(Platform.pathSeparator)
        ? workspaceRootPath
        : '$workspaceRootPath${Platform.pathSeparator}',
  ).resolve(relativePath).toFilePath(windows: Platform.isWindows);
}
