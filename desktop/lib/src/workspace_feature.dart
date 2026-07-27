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
  String get submitTaskTooltip;
  String get executionDefaultsTitle;
  String get noProjectsTitle;
  String get noProjectsDescription;
  String get projectOverviewTitle;
  String get projectDetailsTitle;
  String get projectRecentTargetsTitle;
  String get projectSuggestionsTitle;
  String get sessionConversationTitle;
  String get projectPathLabel;
  String get projectRepositoryLabel;
  String get projectBranchLabel;
  String get projectSessionCwdLabel;
  String get projectLocalFolderLabel;
  String get projectOpenRootLabel;
  String get projectNoRecentTargetsLabel;
  String get composerNoProjectNotice;
  String get composerEmptyTaskNotice;
  String get abortTaskTooltip;
  String composerPromptRejectedNotice(String reason);
  String hostRunFailedNotice(String reason);
  String sessionStatusLabel(WorkspaceRunStatus status);
  String sessionToolStatusLabel(String toolName);
  String projectAddedNotice(String projectName);
  String projectAlreadyAddedNotice(String projectName);
  String projectAddFailedNotice(String reason);
  String get manageProjectTooltip;
  String get renameProjectLabel;
  String get renameProjectDialogTitle;
  String get projectNameFieldLabel;
  String get cancelActionLabel;
  String get saveActionLabel;
  String get pinProjectLabel;
  String get unpinProjectLabel;
  String get removeProjectLabel;
  String projectRenamedNotice(String projectName);
  String projectPinnedNotice(String projectName);
  String projectUnpinnedNotice(String projectName);
  String projectRemovedNotice(String projectName);
  String projectManageFailedNotice(String reason);
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
    this.registryId,
    this.isPinned = false,
  });

  final String name;
  final String? branch;
  final List<WorkspaceProjectItem> items;
  final String? workspacePath;
  final String? sessionCwd;
  final bool isGitRepository;
  final String? registryId;
  final bool isPinned;
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

enum WorkspaceRunStatus { idle, starting, running, settled, aborted, failed }

enum WorkspaceConversationRole { user, assistant }

class WorkspaceConversationMessage {
  const WorkspaceConversationMessage({
    required this.role,
    required this.text,
    this.isStreaming = false,
  });

  final WorkspaceConversationRole role;
  final String text;
  final bool isStreaming;

  WorkspaceConversationMessage copyWith({String? text, bool? isStreaming}) {
    return WorkspaceConversationMessage(
      role: role,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class WorkspaceSessionState {
  const WorkspaceSessionState({
    required this.sessionCwd,
    this.sessionId,
    this.piSessionId,
    this.sessionFile,
    this.modelProvider,
    this.modelName,
    this.thinkingLevel = 'off',
    this.status = WorkspaceRunStatus.idle,
    this.messages = const <WorkspaceConversationMessage>[],
    this.activeToolName,
    this.errorMessage,
  });

  factory WorkspaceSessionState.empty(String sessionCwd) {
    return WorkspaceSessionState(sessionCwd: sessionCwd);
  }

  final String sessionCwd;
  final String? sessionId;
  final String? piSessionId;
  final String? sessionFile;
  final String? modelProvider;
  final String? modelName;
  final String thinkingLevel;
  final WorkspaceRunStatus status;
  final List<WorkspaceConversationMessage> messages;
  final String? activeToolName;
  final String? errorMessage;

  bool get isRunning =>
      status == WorkspaceRunStatus.starting ||
      status == WorkspaceRunStatus.running;

  bool get hasActivity =>
      messages.isNotEmpty ||
      status != WorkspaceRunStatus.idle ||
      errorMessage != null;

  String? get modelLabel {
    if (modelName == null || modelName!.isEmpty) {
      return null;
    }
    if (modelProvider == null || modelProvider!.isEmpty) {
      return modelName;
    }
    return '$modelProvider/$modelName';
  }

  WorkspaceSessionState copyWith({
    String? sessionId,
    String? piSessionId,
    String? sessionFile,
    String? modelProvider,
    String? modelName,
    String? thinkingLevel,
    WorkspaceRunStatus? status,
    List<WorkspaceConversationMessage>? messages,
    String? activeToolName,
    bool clearActiveTool = false,
    bool clearHostSession = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkspaceSessionState(
      sessionCwd: sessionCwd,
      sessionId: clearHostSession ? null : sessionId ?? this.sessionId,
      piSessionId: clearHostSession ? null : piSessionId ?? this.piSessionId,
      sessionFile: clearHostSession ? null : sessionFile ?? this.sessionFile,
      modelProvider: modelProvider ?? this.modelProvider,
      modelName: modelName ?? this.modelName,
      thinkingLevel: thinkingLevel ?? this.thinkingLevel,
      status: status ?? this.status,
      messages: messages ?? this.messages,
      activeToolName: clearActiveTool
          ? null
          : activeToolName ?? this.activeToolName,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  WorkspaceSessionState withUserPrompt(String prompt) {
    final nextMessages = List<WorkspaceConversationMessage>.from(messages);
    final message = WorkspaceConversationMessage(
      role: WorkspaceConversationRole.user,
      text: prompt,
    );
    if (nextMessages.isNotEmpty &&
        nextMessages.last.role == WorkspaceConversationRole.assistant &&
        nextMessages.last.isStreaming) {
      nextMessages.insert(nextMessages.length - 1, message);
    } else {
      nextMessages.add(message);
    }
    return copyWith(messages: nextMessages);
  }

  WorkspaceSessionState withAssistantDelta(String delta) {
    if (delta.isEmpty) {
      return this;
    }

    final nextMessages = List<WorkspaceConversationMessage>.from(messages);
    if (nextMessages.isNotEmpty &&
        nextMessages.last.role == WorkspaceConversationRole.assistant &&
        nextMessages.last.isStreaming) {
      final previous = nextMessages.removeLast();
      nextMessages.add(
        previous.copyWith(text: '${previous.text}$delta', isStreaming: true),
      );
    } else {
      nextMessages.add(
        WorkspaceConversationMessage(
          role: WorkspaceConversationRole.assistant,
          text: delta,
          isStreaming: true,
        ),
      );
    }
    return copyWith(messages: nextMessages);
  }

  WorkspaceSessionState finishAssistantMessage() {
    if (messages.isEmpty ||
        messages.last.role != WorkspaceConversationRole.assistant ||
        !messages.last.isStreaming) {
      return this;
    }

    final nextMessages = List<WorkspaceConversationMessage>.from(messages);
    final previous = nextMessages.removeLast();
    nextMessages.add(previous.copyWith(isStreaming: false));
    return copyWith(messages: nextMessages);
  }
}
