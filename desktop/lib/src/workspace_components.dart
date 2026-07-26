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

/// Primary task composer shown at the bottom of the workspace.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.copy,
    required this.preferences,
    required this.project,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup project;

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
                          onPressed: () {},
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
class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final WorkspaceProjectGroup project;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return DesktopSelectionTile(
      selected: selected,
      radius: _WorkspaceComponentSpec.projectTileRadius,
      animated: false,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(
              _WorkspaceComponentSpec.projectTileRadius,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: desktopDensityValue(
                  interfaceDensity,
                  compact: 5,
                  comfortable: 7,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    size: 17,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      project.name,
                      style: DesktopTypography.sidebarItem(palette),
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
    final palette = context.desktopPalette;

    return SizedBox(
      height: desktopDensityValue(
        interfaceDensity,
        compact: 30,
        comfortable: 34,
      ),
      child: Row(
        children: [
          const SizedBox(width: 2),
          Expanded(
            child: Text(label, style: DesktopTypography.projectItem(palette)),
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
    final palette = context.desktopPalette;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(label, style: DesktopTypography.sectionLabel(palette)),
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
