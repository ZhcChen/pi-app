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
    required this.onAddProject,
    required this.onOpenProject,
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
  final Future<void> Function() onAddProject;
  final ValueChanged<WorkspaceProjectGroup> onOpenProject;
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
          _ProjectSectionHeader(
            label: copy.projectsLabel,
            addTooltip: copy.addProjectTooltip,
            onAddProject: onAddProject,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Text(
                      copy.noProjectsDescription,
                      style: DesktopTypography.projectItem(palette),
                    ),
                  )
                else
                  for (var i = 0; i < projects.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: desktopDensityValue(
                          density,
                          compact: 3,
                          comfortable: 4,
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
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
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
              ),
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: DesktopIconActionButton(
                  onPressed: () {},
                  tooltip: copy.downloadRuntimeTooltip,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  foregroundColor: const Color(0xFF98C4FF),
                  backgroundColor: const Color(0xFF2C5E9B),
                ),
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
    required this.composerController,
    required this.preparedTask,
    required this.onSubmitTask,
    required this.onOpenProject,
    required this.onOpenProjectItem,
    super.key,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup? project;
  final List<WorkspacePromptCard> promptCards;
  final TextEditingController composerController;
  final WorkspacePreparedTask? preparedTask;
  final VoidCallback onSubmitTask;
  final VoidCallback? onOpenProject;
  final ValueChanged<WorkspaceProjectItem>? onOpenProjectItem;

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;

    return ColoredBox(
      color: palette.canvas,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: project == null
                      ? _WorkspaceEmptyState(copy: copy)
                      : _ProjectOverview(
                          copy: copy,
                          preferences: preferences,
                          project: project!,
                          promptCards: promptCards,
                          preparedTask: preparedTask,
                          onOpenProject: onOpenProject,
                          onOpenProjectItem: onOpenProjectItem,
                        ),
                ),
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
                    controller: composerController,
                    onSubmit: onSubmitTask,
                  ),
                  if (preferences.showBottomPanel) ...[
                    const SizedBox(height: 12),
                    _WorkspaceBottomPanel(copy: copy, preferences: preferences),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
