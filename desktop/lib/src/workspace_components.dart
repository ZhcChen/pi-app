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

/// Prompt suggestion card used in the empty-state workspace canvas.
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
  const _WorkspaceEmptyState({required this.copy});

  final WorkspaceCopy copy;

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
        ],
      ),
    );
  }
}

class _ProjectOverview extends StatelessWidget {
  const _ProjectOverview({
    required this.copy,
    required this.preferences,
    required this.project,
    required this.promptCards,
    required this.preparedTask,
    required this.onOpenProject,
    required this.onOpenProjectItem,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup project;
  final List<WorkspacePromptCard> promptCards;
  final WorkspacePreparedTask? preparedTask;
  final VoidCallback? onOpenProject;
  final ValueChanged<WorkspaceProjectItem>? onOpenProjectItem;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.projectOverviewTitle,
            key: const Key('project-overview-title'),
            style: DesktopTypography.sectionLabel(palette),
          ),
          const SizedBox(height: 10),
          Text(project.name, style: DesktopTypography.heroTitle(palette)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WorkspaceStatusPill(
                icon: Icons.folder_open_outlined,
                label: copy.projectRepositoryStatus(project.isGitRepository),
              ),
              if (project.branch != null && project.branch!.isNotEmpty)
                _WorkspaceStatusPill(
                  icon: Icons.merge_type_outlined,
                  label: project.branch!,
                ),
              if (project.items.isNotEmpty)
                _WorkspaceStatusPill(
                  icon: Icons.layers_outlined,
                  label: '${project.items.length}',
                ),
            ],
          ),
          const SizedBox(height: 18),
          _ProjectOverviewCard(
            title: copy.projectDetailsTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProjectDetailLine(
                  label: copy.projectPathLabel,
                  value:
                      project.workspacePath ?? copy.openTargetUnavailableLabel,
                ),
                if (project.branch != null && project.branch!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ProjectDetailLine(
                    label: copy.projectBranchLabel,
                    value: project.branch!,
                  ),
                ],
                const SizedBox(height: 12),
                _ProjectDetailLine(
                  label: copy.projectRepositoryLabel,
                  value: copy.projectRepositoryStatus(project.isGitRepository),
                ),
                if (project.sessionCwd != null) ...[
                  const SizedBox(height: 12),
                  _ProjectDetailLine(
                    label: copy.projectSessionCwdLabel,
                    value: project.sessionCwd!,
                  ),
                ],
                if (project.workspacePath != null && onOpenProject != null) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DesktopTextActionButton(
                      buttonKey: const Key('open-project-overview-button'),
                      onPressed: onOpenProject!,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: copy.projectOpenRootLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (preparedTask != null) ...[
            const SizedBox(height: 18),
            _ProjectOverviewCard(
              title: copy.preparedTaskTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProjectDetailLine(
                    label: copy.preparedTaskPromptLabel,
                    value: preparedTask!.prompt,
                  ),
                  const SizedBox(height: 12),
                  _ProjectDetailLine(
                    label: copy.projectSessionCwdLabel,
                    value: preparedTask!.sessionCwd,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          _ProjectOverviewCard(
            title: copy.projectRecentTargetsTitle,
            child: project.items.isEmpty
                ? Text(
                    copy.projectNoRecentTargetsLabel,
                    style: DesktopTypography.projectItem(palette),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < project.items.length; i++) ...[
                        _ProjectOverviewTargetRow(
                          copy: copy,
                          openDestination: preferences.openDestination,
                          item: project.items[i],
                          onOpen:
                              project.items[i].targetPath == null ||
                                  onOpenProjectItem == null
                              ? null
                              : () => onOpenProjectItem!(project.items[i]),
                        ),
                        if (i < project.items.length - 1)
                          const Divider(height: 18, thickness: 0.6),
                      ],
                    ],
                  ),
          ),
          if (promptCards.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              copy.projectSuggestionsTitle,
              style: DesktopTypography.sectionLabel(palette),
            ),
            const SizedBox(height: 10),
            Wrap(
              key: const Key('workspace-suggested-prompts'),
              alignment: WrapAlignment.start,
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

class _ProjectDetailLine extends StatelessWidget {
  const _ProjectDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesktopTypography.sectionLabel(palette)),
        const SizedBox(height: 3),
        SelectableText(value, style: DesktopTypography.sidebarItem(palette)),
      ],
    );
  }
}

class _ProjectOverviewTargetRow extends StatelessWidget {
  const _ProjectOverviewTargetRow({
    required this.copy,
    required this.openDestination,
    required this.item,
    this.onOpen,
  });

  final WorkspaceCopy copy;
  final AppOpenDestination openDestination;
  final WorkspaceProjectItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            item.kind == WorkspaceProjectItemKind.directory
                ? Icons.folder_outlined
                : Icons.description_outlined,
            size: 16,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.label, style: DesktopTypography.sidebarItem(palette)),
              if (item.relativePath != null) ...[
                const SizedBox(height: 4),
                Text(
                  copy.projectRecentTargetDescription(item.relativePath!),
                  style: DesktopTypography.projectItem(palette),
                ),
              ],
            ],
          ),
        ),
        if (onOpen != null) ...[
          const SizedBox(width: 10),
          DesktopIconActionButton(
            key: Key('open-project-overview-item-button-${item.label}'),
            onPressed: onOpen!,
            tooltip: copy.openTargetTooltip(openDestination),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            backgroundColor: palette.settingsField,
            foregroundColor: palette.textSecondary,
          ),
        ],
      ],
    );
  }
}

/// Primary task composer shown at the bottom of the workspace.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.copy,
    required this.preferences,
    required this.project,
    required this.controller,
    required this.onSubmit,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup? project;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final density = preferences.interfaceDensity;

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
                        DesktopTextActionButton(
                          onPressed: () {},
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: copy.customLabel,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            copy.composerExecutionSummary(preferences),
                            key: const Key('composer-execution-summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: DesktopTypography.sectionLabel(palette),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DesktopTextActionButton(
                          onPressed: () {},
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          label: copy.modelPresetLabel,
                        ),
                        const SizedBox(width: 8),
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
class _ProjectTile extends StatefulWidget {
  const _ProjectTile({
    required this.copy,
    required this.project,
    required this.interfaceDensity,
    required this.openDestination,
    required this.selected,
    required this.onTap,
    required this.onOpenProject,
  });

  final WorkspaceCopy copy;
  final WorkspaceProjectGroup project;
  final AppInterfaceDensity interfaceDensity;
  final AppOpenDestination openDestination;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOpenProject;

  @override
  State<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<_ProjectTile> {
  bool _isHovered = false;

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
            ],
          ),
        ),
      ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: DesktopTypography.sectionLabel(palette),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: palette.textMuted,
                    ),
                  ],
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

class _CollapsedSectionRow extends StatelessWidget {
  const _CollapsedSectionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(label, style: DesktopTypography.sectionLabel(palette)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: palette.textMuted),
        ],
      ),
    );
  }
}
