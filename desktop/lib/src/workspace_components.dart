part of 'workspace_feature.dart';

// Workspace primitives live here so the page file can focus on shell composition.
class _WorkspaceComponentSpec {
  static const double sidebarTileRadius = 8;
  static const double promptCardRadius = 8;
  static const double promptCardWidth = 194;
  static const double promptCardHeight = 128;
  static const double composerShellRadius = 24;
  static const double composerInputRadius = 20;
  static const double bottomPanelRadius = 18;
  static const double projectTileRadius = 12;
  static const double overviewCardRadius = 18;
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: SvgPicture.asset(piDarkMarkAsset, width: 58, height: 58),
    );
  }
}

class _PromptCardTile extends StatelessWidget {
  const _PromptCardTile({required this.card});

  final WorkspacePromptCard card;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSurface(
      color: palette.panel,
      radius: _WorkspaceComponentSpec.promptCardRadius,
      width: _WorkspaceComponentSpec.promptCardWidth,
      height: _WorkspaceComponentSpec.promptCardHeight,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(card.icon, size: 17, color: card.color),
          Text(card.title, style: DesktopTypography.promptTitle(palette)),
        ],
      ),
    );
  }
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({required this.copy, required this.promptCards});

  final WorkspaceCopy copy;
  final List<WorkspacePromptCard> promptCards;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HeroMark(),
          const SizedBox(height: 28),
          Text(
            copy.noProjectsTitle,
            textAlign: TextAlign.center,
            style: DesktopTypography.heroTitle(palette),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              copy.noProjectsDescription,
              textAlign: TextAlign.center,
              style: DesktopTypography.projectItem(palette),
            ),
          ),
          if (promptCards.isNotEmpty) ...[
            const SizedBox(height: 28),
            Wrap(
              key: const Key('workspace-suggested-prompts'),
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
              children: promptCards
                  .map((card) => _PromptCardTile(card: card))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProjectSessionCanvas extends StatelessWidget {
  const _ProjectSessionCanvas({required this.copy, required this.session});

  final WorkspaceCopy copy;
  final WorkspaceSessionState? session;

  @override
  Widget build(BuildContext context) {
    final activeSession = session;
    if (activeSession == null || !activeSession.hasActivity) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      key: const Key('workspace-session-transcript'),
      child: _ProjectSessionTranscript(copy: copy, session: activeSession),
    );
  }
}

class _ProjectSessionTranscript extends StatelessWidget {
  const _ProjectSessionTranscript({required this.copy, required this.session});

  final WorkspaceCopy copy;
  final WorkspaceSessionState session;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return _ProjectOverviewCard(
      title: copy.sessionConversationTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WorkspaceStatusPill(
                icon: _statusIcon(session.status),
                label: copy.sessionStatusLabel(session.status),
              ),
              if (session.modelLabel != null)
                _WorkspaceStatusPill(
                  icon: Icons.memory_rounded,
                  label: '${session.modelLabel} · ${session.thinkingLevel}',
                ),
              if (session.activeToolName != null)
                _WorkspaceStatusPill(
                  icon: Icons.construction_outlined,
                  label: copy.sessionToolStatusLabel(session.activeToolName!),
                ),
            ],
          ),
          if (session.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              session.errorMessage!,
              key: const Key('workspace-session-error'),
              style: DesktopTypography.projectItem(
                palette,
              ).copyWith(color: const Color(0xFFE97878)),
            ),
          ],
          if (session.messages.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (var index = 0; index < session.messages.length; index++) ...[
              _ConversationMessageRow(
                message: session.messages[index],
                palette: palette,
              ),
              if (index < session.messages.length - 1)
                const Divider(height: 18, thickness: 0.6),
            ],
          ],
        ],
      ),
    );
  }

  IconData _statusIcon(WorkspaceRunStatus status) {
    return switch (status) {
      WorkspaceRunStatus.idle => Icons.pause_circle_outline_rounded,
      WorkspaceRunStatus.starting => Icons.hourglass_top_rounded,
      WorkspaceRunStatus.running => Icons.auto_awesome_rounded,
      WorkspaceRunStatus.settled => Icons.check_circle_outline_rounded,
      WorkspaceRunStatus.aborted => Icons.cancel_outlined,
      WorkspaceRunStatus.failed => Icons.error_outline_rounded,
    };
  }
}

class _ConversationMessageRow extends StatelessWidget {
  const _ConversationMessageRow({required this.message, required this.palette});

  final WorkspaceConversationMessage message;
  final DesktopPalette palette;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == WorkspaceConversationRole.user;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isUser ? Icons.person_outline_rounded : Icons.auto_awesome_rounded,
            size: 16,
            color: isUser ? palette.textSecondary : palette.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            message.text,
            key: isUser
                ? const Key('workspace-user-message')
                : const Key('workspace-assistant-message'),
            style: DesktopTypography.sidebarItem(palette),
          ),
        ),
        if (message.isStreaming) ...[
          const SizedBox(width: 8),
          Icon(Icons.more_horiz_rounded, size: 16, color: palette.textMuted),
        ],
      ],
    );
  }
}

class _ProjectOverviewCard extends StatelessWidget {
  const _ProjectOverviewCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSurface(
      color: palette.panel,
      radius: _WorkspaceComponentSpec.overviewCardRadius,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: DesktopTypography.settingsGroupLabel(palette)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Primary task composer shown at the bottom of the workspace.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.copy,
    required this.preferences,
    required this.project,
    required this.session,
    required this.controller,
    required this.onSubmit,
    required this.onAbort,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup? project;
  final WorkspaceSessionState? session;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback? onAbort;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final density = preferences.interfaceDensity;
    final isRunning = session?.isRunning == true;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: DesktopSurface(
        color: palette.composerShell,
        radius: _WorkspaceComponentSpec.composerShellRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                desktopDensityValue(density, compact: 10, comfortable: 12),
                18,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: desktopDensityValue(
                    density,
                    compact: 12,
                    comfortable: 16,
                  ),
                  runSpacing: 8,
                  children: [
                    _ComposerTag(
                      icon: Icons.folder_outlined,
                      label: project?.name ?? copy.noProjectsTitle,
                    ),
                    _ComposerTag(
                      icon: Icons.computer_outlined,
                      label: copy.localLabel,
                    ),
                    if (project?.branch != null && project!.branch!.isNotEmpty)
                      _ComposerTag(
                        icon: Icons.merge_type_outlined,
                        label: project!.branch!,
                      ),
                    if (session?.modelLabel != null)
                      _ComposerTag(
                        icon: Icons.memory_rounded,
                        label:
                            '${session!.modelLabel} · ${session!.thinkingLevel}',
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                desktopDensityValue(density, compact: 8, comfortable: 10),
                14,
                0,
              ),
              child: DesktopSurface(
                color: palette.composerInput,
                radius: _WorkspaceComponentSpec.composerInputRadius,
                borderColor: Colors.transparent,
                padding: EdgeInsets.fromLTRB(
                  16,
                  desktopDensityValue(density, compact: 14, comfortable: 16),
                  16,
                  desktopDensityValue(density, compact: 10, comfortable: 12),
                ),
                child: Column(
                  children: [
                    TextField(
                      key: const Key('workspace-composer-input'),
                      controller: controller,
                      enabled: !isRunning,
                      minLines: 3,
                      maxLines: 3,
                      style: desktopWithCodeFont(
                        DesktopTypography.composerInput(palette),
                        preferences.codeFont,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: copy.composerHint,
                        hintStyle: desktopWithCodeFont(
                          DesktopTypography.composerHint(palette),
                          preferences.codeFont,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 14,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            project?.sessionCwd ?? copy.composerNoProjectNotice,
                            key: const Key('composer-session-cwd'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DesktopTypography.sectionLabel(palette),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session?.activeToolName != null
                                ? copy.sessionToolStatusLabel(
                                    session!.activeToolName!,
                                  )
                                : session == null
                                ? copy.composerExecutionSummary(preferences)
                                : copy.sessionStatusLabel(session!.status),
                            key: const Key('composer-execution-summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: DesktopTypography.sectionLabel(palette),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isRunning && onAbort != null)
                          DesktopIconActionButton(
                            key: const Key('abort-composer-task-button'),
                            onPressed: onAbort!,
                            tooltip: copy.abortTaskTooltip,
                            icon: const Icon(Icons.stop_rounded),
                            backgroundColor: const Color(0xFF8D3B3B),
                            buttonSize: const Size(40, 40),
                          )
                        else
                          DesktopIconActionButton(
                            key: const Key('submit-composer-task-button'),
                            onPressed: onSubmit,
                            tooltip: copy.submitTaskTooltip,
                            icon: const Icon(Icons.arrow_upward_rounded),
                            backgroundColor: const Color(0xFF767676),
                            buttonSize: const Size(40, 40),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: desktopDensityValue(
                density,
                compact: 12,
                comfortable: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerTag extends StatelessWidget {
  const _ComposerTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: palette.textPrimary),
        const SizedBox(width: 6),
        Text(label, style: DesktopTypography.composerTag(palette)),
      ],
    );
  }
}

/// Secondary bottom panel that summarizes current execution defaults.
class _WorkspaceBottomPanel extends StatelessWidget {
  const _WorkspaceBottomPanel({required this.copy, required this.preferences});

  final WorkspaceCopy copy;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: DesktopSurface(
        key: const Key('workspace-bottom-panel'),
        color: palette.panel,
        radius: _WorkspaceComponentSpec.bottomPanelRadius,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.executionDefaultsTitle,
              style: DesktopTypography.settingsGroupLabel(palette),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WorkspaceStatusPill(
                  icon: Icons.open_in_new_rounded,
                  label: copy.openDestinationSummaryLabel(
                    preferences.openDestination,
                  ),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.shield_outlined,
                  label: copy.accessModeLabel(preferences),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.fact_check_outlined,
                  label: copy.reviewModeLabel(preferences.autoReview),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.bedtime_outlined,
                  label: copy.sleepModeLabel(preferences.preventSleep),
                ),
                _WorkspaceStatusPill(
                  icon: Icons.auto_awesome_outlined,
                  label: copy.suggestedPromptsModeLabel(
                    preferences.suggestedPrompts,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceStatusPill extends StatelessWidget {
  const _WorkspaceStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DesktopStatusPill(icon: icon, label: label);
  }
}

/// Primary action tile for the left workspace sidebar.
class _SidebarActionTile extends StatelessWidget {
  const _SidebarActionTile({
    required this.action,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceAction action;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DesktopSelectionTile(
        selected: selected,
        onTap: onTap,
        height: desktopDensityValue(
          interfaceDensity,
          compact: 34,
          comfortable: 38,
        ),
        radius: _WorkspaceComponentSpec.sidebarTileRadius,
        animated: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(action.icon, size: 17, color: palette.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  style: DesktopTypography.sidebarItem(palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Expandable project tile in the workspace sidebar.
enum _ProjectMenuAction { rename, togglePin, remove }

class _ProjectTile extends StatefulWidget {
  const _ProjectTile({
    required this.copy,
    required this.project,
    required this.interfaceDensity,
    required this.openDestination,
    required this.selected,
    required this.isManaged,
    required this.isPinned,
    required this.onTap,
    required this.onOpenProject,
    required this.onRename,
    required this.onTogglePinned,
    required this.onRemove,
  });

  final WorkspaceCopy copy;
  final WorkspaceProjectGroup project;
  final AppInterfaceDensity interfaceDensity;
  final AppOpenDestination openDestination;
  final bool selected;
  final bool isManaged;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onOpenProject;
  final Future<void> Function(String alias) onRename;
  final Future<void> Function() onTogglePinned;
  final Future<void> Function() onRemove;

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  bool _isHovered = false;

  Future<void> _showRenameProjectDialog() async {
    final alias = await showDialog<String>(
      context: context,
      builder: (context) {
        return _ProjectRenameDialog(
          copy: widget.copy,
          initialName: widget.project.name,
        );
      },
    );

    if (alias != null) {
      await widget.onRename(alias);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: DesktopSelectionTile(
        selected: widget.selected,
        onTap: widget.onTap,
        height: desktopDensityValue(
          widget.interfaceDensity,
          compact: 36,
          comfortable: 40,
        ),
        radius: _WorkspaceComponentSpec.projectTileRadius,
        animated: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DesktopTypography.sidebarItem(palette),
                ),
              ),
              if (widget.isPinned) ...[
                const SizedBox(width: 6),
                Icon(Icons.push_pin_outlined, size: 13, color: palette.accent),
              ],
              if ((_isHovered || widget.selected) &&
                  widget.project.workspacePath != null) ...[
                const SizedBox(width: 8),
                DesktopIconActionButton(
                  key: Key('open-project-button-${widget.project.name}'),
                  onPressed: widget.onOpenProject,
                  tooltip: widget.copy.openTargetTooltip(
                    widget.openDestination,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  backgroundColor: palette.settingsField,
                  foregroundColor: palette.textSecondary,
                  buttonSize: const Size(24, 24),
                ),
              ],
              if (widget.isManaged && (_isHovered || widget.selected)) ...[
                const SizedBox(width: 6),
                PopupMenuButton<_ProjectMenuAction>(
                  key: Key('manage-project-button-${widget.project.name}'),
                  tooltip: widget.copy.manageProjectTooltip,
                  icon: const Icon(Icons.more_horiz_rounded, size: 16),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  color: palette.panelRaised,
                  position: PopupMenuPosition.under,
                  style: IconButton.styleFrom(
                    backgroundColor: palette.settingsField,
                    foregroundColor: palette.textSecondary,
                    minimumSize: const Size(24, 24),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onSelected: (action) async {
                    switch (action) {
                      case _ProjectMenuAction.rename:
                        await _showRenameProjectDialog();
                        break;
                      case _ProjectMenuAction.togglePin:
                        await widget.onTogglePinned();
                        break;
                      case _ProjectMenuAction.remove:
                        await widget.onRemove();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<_ProjectMenuAction>(
                      key: const Key('rename-project-menu-item'),
                      value: _ProjectMenuAction.rename,
                      child: Row(
                        children: [
                          Icon(
                            Icons.drive_file_rename_outline_rounded,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.copy.renameProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<_ProjectMenuAction>(
                      value: _ProjectMenuAction.togglePin,
                      child: Row(
                        children: [
                          Icon(
                            widget.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            size: 16,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.isPinned
                                  ? widget.copy.unpinProjectLabel
                                  : widget.copy.pinProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(palette),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ProjectMenuAction>(
                      value: _ProjectMenuAction.remove,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 16,
                            color: Color(0xFFE97878),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.copy.removeProjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesktopTypography.sidebarItem(
                                palette,
                              ).copyWith(color: const Color(0xFFE97878)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectRenameDialog extends StatefulWidget {
  const _ProjectRenameDialog({required this.copy, required this.initialName});

  final WorkspaceCopy copy;
  final String initialName;

  @override
  State<_ProjectRenameDialog> createState() => _ProjectRenameDialogState();
}

class _ProjectRenameDialogState extends State<_ProjectRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return AlertDialog(
      backgroundColor: palette.panelRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        widget.copy.renameProjectDialogTitle,
        style: DesktopTypography.settingsGroupLabel(palette),
      ),
      content: SizedBox(
        width: 320,
        child: TextField(
          key: const Key('project-rename-input'),
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: InputDecoration(
            labelText: widget.copy.projectNameFieldLabel,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.copy.cancelActionLabel),
        ),
        FilledButton(
          key: const Key('save-project-rename-button'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.copy.saveActionLabel),
        ),
      ],
    );
  }
}

class _ProjectSectionHeader extends StatefulWidget {
  const _ProjectSectionHeader({
    required this.label,
    required this.addTooltip,
    required this.onAddProject,
  });

  final String label;
  final String addTooltip;
  final Future<void> Function() onAddProject;

  @override
  State<_ProjectSectionHeader> createState() => _ProjectSectionHeaderState();
}

class _ProjectSectionHeaderState extends State<_ProjectSectionHeader> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return MouseRegion(
      key: const Key('projects-section-header'),
      onEnter: (_) {
        if (!_isHovered) {
          setState(() {
            _isHovered = true;
          });
        }
      },
      onExit: (_) {
        if (_isHovered) {
          setState(() {
            _isHovered = false;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _SidebarSectionLabel(
                    label: widget.label,
                    icon: Icons.expand_more_rounded,
                    labelKey: const Key('projects-section-label'),
                  ),
                ),
              ),
              SizedBox(
                width: 24,
                height: 24,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IgnorePointer(
                    ignoring: !_isHovered,
                    child: AnimatedOpacity(
                      key: const Key('add-project-button-visibility'),
                      duration: const Duration(milliseconds: 120),
                      opacity: _isHovered ? 1 : 0,
                      child: DesktopIconActionButton(
                        key: const Key('add-project-button'),
                        onPressed: () {
                          widget.onAddProject();
                        },
                        tooltip: widget.addTooltip,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        backgroundColor: Colors.transparent,
                        foregroundColor: palette.textMuted,
                        buttonSize: const Size(20, 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({
    required this.label,
    required this.icon,
    required this.labelKey,
  });

  final String label;
  final IconData icon;
  final Key labelKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return SizedBox(
      key: labelKey,
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: DesktopTypography.sectionLabel(palette),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 16,
            height: 16,
            child: Center(
              child: Icon(icon, size: 16, color: palette.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedSectionRow extends StatelessWidget {
  const _CollapsedSectionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _SidebarSectionLabel(
          label: label,
          icon: Icons.chevron_right_rounded,
          labelKey: const Key('tasks-section-label'),
        ),
      ),
    );
  }
}
