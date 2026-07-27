import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_preferences.dart';
import 'desktop_design.dart';
import 'desktop_primitives.dart';

part 'workspace_view.dart';
part 'workspace_components.dart';

abstract interface class WorkspaceCopy {
  String get searchTooltip;
  String get projectsLabel;
  String get addProjectTooltip;
  String get tasksLabel;
  String get settingsLabel;
  String get downloadRuntimeTooltip;
  String get heroPromptPrefix;
  String get heroPromptSuffix;
  String get localLabel;
  String get composerHint;
  String get customLabel;
  String get modelPresetLabel;
  String get submitTaskTooltip;
  String get executionDefaultsTitle;
  String get noProjectsTitle;
  String get noProjectsDescription;
  String get projectOverviewTitle;
  String get projectDetailsTitle;
  String get projectRecentTargetsTitle;
  String get projectSuggestionsTitle;
  String get preparedTaskTitle;
  String get preparedTaskPromptLabel;
  String get projectPathLabel;
  String get projectRepositoryLabel;
  String get projectBranchLabel;
  String get projectSessionCwdLabel;
  String get projectLocalFolderLabel;
  String get projectOpenRootLabel;
  String get projectNoRecentTargetsLabel;
  String get composerNoProjectNotice;
  String get composerEmptyTaskNotice;
  String projectAddedNotice(String projectName);
  String projectAlreadyAddedNotice(String projectName);
  String projectAddFailedNotice(String reason);
  String get manageProjectTooltip;
  String get pinProjectLabel;
  String get unpinProjectLabel;
  String get removeProjectLabel;
  String projectPinnedNotice(String projectName);
  String projectUnpinnedNotice(String projectName);
  String projectRemovedNotice(String projectName);
  String projectManageFailedNotice(String reason);
  String composerPreparedNotice(String projectName);
  String projectRecentTargetDescription(String relativePath);
  String projectRepositoryStatus(bool isGitRepository);
  String openTargetTooltip(AppOpenDestination destination);
  String get openTargetUnavailableLabel;
  String openFailedMessage(AppOpenDestination destination, String reason);

  String composerExecutionSummary(AppPreferences preferences);
  String openDestinationSummaryLabel(AppOpenDestination destination);
  String accessModeLabel(AppPreferences preferences);
  String reviewModeLabel(bool autoReview);
  String sleepModeLabel(bool preventSleep);
  String suggestedPromptsModeLabel(bool enabled);
}

class WorkspaceAction {
  const WorkspaceAction({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

enum WorkspaceProjectItemKind { file, directory }

class WorkspaceProjectItem {
  const WorkspaceProjectItem({
    required this.label,
    this.targetPath,
    this.relativePath,
    this.kind = WorkspaceProjectItemKind.file,
  });

  final String label;
  final String? targetPath;
  final String? relativePath;
  final WorkspaceProjectItemKind kind;
}

class WorkspaceProjectGroup {
  const WorkspaceProjectGroup({
    required this.name,
    this.branch,
    required this.items,
    this.workspacePath,
    this.sessionCwd,
    this.isGitRepository = false,
  });

  final String name;
  final String? branch;
  final List<WorkspaceProjectItem> items;
  final String? workspacePath;
  final String? sessionCwd;
  final bool isGitRepository;
}

class WorkspacePromptCard {
  const WorkspacePromptCard({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final Color color;
}

class WorkspacePreparedTask {
  const WorkspacePreparedTask({
    required this.projectName,
    required this.prompt,
    required this.sessionCwd,
  });

  final String projectName;
  final String prompt;
  final String sessionCwd;
}
