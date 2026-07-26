part of 'workspace_feature.dart';

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    required this.copy,
    required this.actions,
    required this.projects,
    required this.preferences,
    required this.selectedActionIndex,
    required this.selectedProjectIndex,
    required this.onActionSelected,
    required this.onProjectSelected,
    required this.onOpenProject,
    required this.onOpenProjectItem,
    required this.onOpenSettings,
    super.key,
  });

  final WorkspaceCopy copy;
  final List<WorkspaceAction> actions;
  final List<WorkspaceProjectGroup> projects;
  final AppPreferences preferences;
  final int selectedActionIndex;
  final int selectedProjectIndex;
  final ValueChanged<int> onActionSelected;
  final ValueChanged<int> onProjectSelected;
  final ValueChanged<WorkspaceProjectGroup> onOpenProject;
  final void Function(WorkspaceProjectGroup project, WorkspaceProjectItem item)
  onOpenProjectItem;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final density = preferences.interfaceDensity;

    return Container(
      color: palette.sidebar,
      padding: EdgeInsets.fromLTRB(
        10,
        desktopDensityValue(density, compact: 14, comfortable: 18),
        10,
        desktopDensityValue(density, compact: 8, comfortable: 10),
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
                        style: DesktopTypography.brandTitle(palette),
                      ),
                      TextSpan(
                        text: 'App',
                        style: DesktopTypography.brandAccentTitle(palette),
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
            height: desktopDensityValue(density, compact: 12, comfortable: 14),
          ),
          for (var i = 0; i < actions.length; i++)
            _SidebarActionTile(
              action: actions[i],
              interfaceDensity: density,
              selected: i == selectedActionIndex,
              onTap: () => onActionSelected(i),
            ),
          SizedBox(
            height: desktopDensityValue(density, compact: 14, comfortable: 18),
          ),
          _SectionLabel(label: copy.projectsLabel),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < projects.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: desktopDensityValue(
                        density,
                        compact: 6,
                        comfortable: 8,
                      ),
                    ),
                    child: _ProjectTile(
                      copy: copy,
                      project: projects[i],
                      interfaceDensity: density,
                      openDestination: preferences.openDestination,
                      selected: i == selectedProjectIndex,
                      onTap: () => onProjectSelected(i),
                      onOpenProject: () => onOpenProject(projects[i]),
                      onOpenProjectItem: (item) =>
                          onOpenProjectItem(projects[i], item),
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
                child: DesktopTextActionButton(
                  buttonKey: const Key('open-settings-button'),
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: copy.settingsLabel,
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: desktopDensityValue(
                      density,
                      compact: 10,
                      comfortable: 12,
                    ),
                  ),
                ),
              ),
              DesktopIconActionButton(
                onPressed: () {},
                tooltip: copy.downloadRuntimeTooltip,
                icon: const Icon(Icons.download_rounded, size: 18),
                foregroundColor: const Color(0xFF98C4FF),
                backgroundColor: const Color(0xFF2C5E9B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WorkspaceCanvas extends StatelessWidget {
  const WorkspaceCanvas({
    required this.copy,
    required this.preferences,
    required this.project,
    required this.promptCards,
    super.key,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup project;
  final List<WorkspacePromptCard> promptCards;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

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
                                    style: DesktopTypography.heroTitle(palette),
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
