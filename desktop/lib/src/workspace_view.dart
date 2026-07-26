part of '../main.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.copy,
    required this.preferences,
    required this.selectedActionIndex,
    required this.selectedProjectIndex,
    required this.onActionSelected,
    required this.onProjectSelected,
    required this.onOpenSettings,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final int selectedActionIndex;
  final int selectedProjectIndex;
  final ValueChanged<int> onActionSelected;
  final ValueChanged<int> onProjectSelected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final actions = _buildPrimaryActions(copy);
    final density = preferences.interfaceDensity;

    return Container(
      color: palette.sidebar,
      padding: EdgeInsets.fromLTRB(
        10,
        _densityValue(density, compact: 14, comfortable: 18),
        10,
        _densityValue(density, compact: 8, comfortable: 10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Pi ',
                        style: _AppTypography.brandTitle(palette),
                      ),
                      TextSpan(
                        text: 'App',
                        style: _AppTypography.brandAccentTitle(palette),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message: copy.searchTooltip,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(
            height: _densityValue(density, compact: 12, comfortable: 14),
          ),
          for (var i = 0; i < actions.length; i++)
            _SidebarActionTile(
              action: actions[i],
              interfaceDensity: density,
              selected: i == selectedActionIndex,
              onTap: () => onActionSelected(i),
            ),
          SizedBox(
            height: _densityValue(density, compact: 14, comfortable: 18),
          ),
          _SectionLabel(label: copy.projectsLabel),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < _projects.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: _densityValue(
                        density,
                        compact: 6,
                        comfortable: 8,
                      ),
                    ),
                    child: _ProjectTile(
                      project: _projects[i],
                      interfaceDensity: density,
                      selected: i == selectedProjectIndex,
                      onTap: () => onProjectSelected(i),
                    ),
                  ),
                const SizedBox(height: 12),
                _CollapsedSectionRow(label: copy.tasksLabel),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: palette.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const Key('open-settings-button'),
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: Text(copy.settingsLabel),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: palette.textSecondary,
                    textStyle: _AppTypography.controlLabel(palette),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: _densityValue(
                        density,
                        compact: 10,
                        comfortable: 12,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                tooltip: copy.downloadRuntimeTooltip,
                icon: const Icon(Icons.download_rounded, size: 18),
                color: const Color(0xFF98C4FF),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5E9B),
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCanvas extends StatelessWidget {
  const _WorkspaceCanvas({
    required this.copy,
    required this.preferences,
    required this.project,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final _ProjectGroup project;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final promptCards = preferences.suggestedPrompts
        ? _buildPromptCards(copy)
        : const <_PromptCard>[];

    return ColoredBox(
      color: palette.canvas,
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final contentWidth = constraints.maxWidth > 848
                            ? 848.0
                            : constraints.maxWidth;

                        return Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: contentWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const _HeroMark(),
                                  const SizedBox(height: 28),
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: copy.heroPromptPrefix),
                                        TextSpan(
                                          text: project.name,
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: palette.textMuted,
                                          ),
                                        ),
                                        TextSpan(text: copy.heroPromptSuffix),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                    style: _AppTypography.heroTitle(palette),
                                  ),
                                  if (promptCards.isNotEmpty) ...[
                                    const SizedBox(height: 34),
                                    Wrap(
                                      key: const Key(
                                        'workspace-suggested-prompts',
                                      ),
                                      alignment: WrapAlignment.center,
                                      spacing: 14,
                                      runSpacing: 14,
                                      children: promptCards
                                          .map(
                                            (card) =>
                                                _PromptCardTile(card: card),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Composer(
                          copy: copy,
                          preferences: preferences,
                          project: project,
                        ),
                        if (preferences.showBottomPanel) ...[
                          const SizedBox(height: 12),
                          _WorkspaceBottomPanel(
                            copy: copy,
                            preferences: preferences,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.4,
      child: SvgPicture.asset(_piDarkMarkAsset, width: 58, height: 58),
    );
  }
}

class _PromptCardTile extends StatelessWidget {
  const _PromptCardTile({required this.card});

  final _PromptCard card;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 194,
        height: 128,
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.dividerLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(card.icon, size: 17, color: card.color),
            Text(card.title, style: _AppTypography.promptTitle(palette)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.copy,
    required this.preferences,
    required this.project,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final _ProjectGroup project;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: Container(
        decoration: BoxDecoration(
          color: palette.composerShell,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.dividerLight),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                _densityValue(density, compact: 10, comfortable: 12),
                18,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: _densityValue(density, compact: 12, comfortable: 16),
                  runSpacing: 8,
                  children: [
                    _ComposerTag(
                      icon: Icons.folder_outlined,
                      label: project.name,
                    ),
                    _ComposerTag(
                      icon: Icons.computer_outlined,
                      label: copy.localLabel,
                    ),
                    _ComposerTag(
                      icon: Icons.merge_type_outlined,
                      label: project.branch,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                _densityValue(density, compact: 8, comfortable: 10),
                14,
                0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.composerInput,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  _densityValue(density, compact: 14, comfortable: 16),
                  16,
                  _densityValue(density, compact: 10, comfortable: 12),
                ),
                child: Column(
                  children: [
                    TextField(
                      minLines: 3,
                      maxLines: 3,
                      style: _withCodeFont(
                        _AppTypography.composerInput(palette),
                        preferences.codeFont,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: copy.composerHint,
                        hintStyle: _withCodeFont(
                          _AppTypography.composerHint(palette),
                          preferences.codeFont,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(copy.customLabel),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                            textStyle: _AppTypography.controlLabel(palette),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            copy.composerExecutionSummary(preferences),
                            key: const Key('composer-execution-summary'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: _AppTypography.sectionLabel(palette),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {},
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          label: Text(copy.modelPresetLabel),
                          style: TextButton.styleFrom(
                            foregroundColor: palette.textSecondary,
                            textStyle: _AppTypography.controlLabel(palette),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {},
                          tooltip: copy.submitTaskTooltip,
                          icon: const Icon(Icons.arrow_upward_rounded),
                          color: palette.textPrimary,
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF767676),
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: _densityValue(density, compact: 12, comfortable: 14),
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
    final palette = context.appPalette;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: palette.textPrimary),
        const SizedBox(width: 6),
        Text(label, style: _AppTypography.composerTag(palette)),
      ],
    );
  }
}

class _WorkspaceBottomPanel extends StatelessWidget {
  const _WorkspaceBottomPanel({required this.copy, required this.preferences});

  final _AppCopy copy;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 836),
      child: Container(
        key: const Key('workspace-bottom-panel'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: palette.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.dividerLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              copy.executionDefaultsTitle,
              style: _AppTypography.settingsGroupLabel(palette),
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
    final palette = context.appPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.settingsField,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.dividerLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: _AppTypography.controlLabel(palette)),
        ],
      ),
    );
  }
}

class _SidebarActionTile extends StatelessWidget {
  const _SidebarActionTile({
    required this.action,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final _SidebarAction action;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: _densityValue(interfaceDensity, compact: 36, comfortable: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? palette.selection : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: palette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.label,
                  style: _AppTypography.sidebarItem(palette),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final _ProjectGroup project;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      decoration: BoxDecoration(
        color: selected ? palette.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: _densityValue(
                  interfaceDensity,
                  compact: 6,
                  comfortable: 8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      project.name,
                      style: _AppTypography.sidebarItem(palette),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 10, 10),
              child: Column(
                children: [
                  for (final item in project.items)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _ProjectItemRow(
                        interfaceDensity: interfaceDensity,
                        label: item,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectItemRow extends StatelessWidget {
  const _ProjectItemRow({required this.interfaceDensity, required this.label});

  final AppInterfaceDensity interfaceDensity;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SizedBox(
      height: _densityValue(interfaceDensity, compact: 30, comfortable: 34),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Expanded(
            child: Text(label, style: _AppTypography.projectItem(palette)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(label, style: _AppTypography.sectionLabel(palette)),
      ),
    );
  }
}

class _CollapsedSectionRow extends StatelessWidget {
  const _CollapsedSectionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(label, style: _AppTypography.sectionLabel(palette)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: palette.textMuted),
        ],
      ),
    );
  }
}
