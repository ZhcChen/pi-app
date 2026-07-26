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

class WorkspaceProjectGroup {
  const WorkspaceProjectGroup({
    required this.name,
    required this.branch,
    required this.items,
  });

  final String name;
  final String branch;
  final List<String> items;
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
