part of 'workspace_feature.dart';

class WorkspaceSidebar extends StatefulWidget {
  const WorkspaceSidebar({
    required this.copy,
    required this.actions,
    required this.projects,
    required this.preferences,
    required this.selectedActionIndex,
    required this.selectedProjectIndex,
    required this.selectedProjectSessions,
    required this.onActionSelected,
    required this.onOpenProjectSession,
    required this.onProjectSelected,
    required this.onRenameProject,
    required this.onToggleProjectPinned,
    required this.onRemoveProject,
    required this.onAddProject,
    required this.onOpenProject,
    required this.onOpenSettings,
    required this.onDownloadRuntime,
    super.key,
  });

  final WorkspaceCopy copy;
  final List<WorkspaceAction> actions;
  final List<WorkspaceProjectGroup> projects;
  final AppPreferences preferences;
  final int selectedActionIndex;
  final int selectedProjectIndex;
  final List<WorkspaceSessionListEntry> selectedProjectSessions;
  final ValueChanged<int> onActionSelected;
  final ValueChanged<WorkspaceSessionListEntry> onOpenProjectSession;
  final Future<void> Function(int) onProjectSelected;
  final Future<void> Function(WorkspaceProjectGroup project, String alias)
  onRenameProject;
  final Future<void> Function(WorkspaceProjectGroup) onToggleProjectPinned;
  final Future<void> Function(WorkspaceProjectGroup) onRemoveProject;
  final Future<void> Function() onAddProject;
  final ValueChanged<WorkspaceProjectGroup> onOpenProject;
  final VoidCallback onOpenSettings;
  final VoidCallback onDownloadRuntime;

  @override
  State<WorkspaceSidebar> createState() => _WorkspaceSidebarState();
}

class _WorkspaceSidebarState extends State<WorkspaceSidebar> {
  bool _projectsExpanded = true;

  Future<void> _addProject() async {
    if (!_projectsExpanded) {
      setState(() {
        _projectsExpanded = true;
      });
    }
    await widget.onAddProject();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.desktopPalette;
    final density = widget.preferences.interfaceDensity;

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
                message: widget.copy.searchTooltip,
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
          for (var i = 0; i < widget.actions.length; i++)
            _SidebarActionTile(
              action: widget.actions[i],
              interfaceDensity: density,
              selected: i == widget.selectedActionIndex,
              onTap: () => widget.onActionSelected(i),
            ),
          SizedBox(
            height: desktopDensityValue(density, compact: 14, comfortable: 18),
          ),
          _ProjectSectionHeader(
            label: widget.copy.projectsLabel,
            expandTooltip: widget.copy.expandProjectsTooltip,
            collapseTooltip: widget.copy.collapseProjectsTooltip,
            isExpanded: _projectsExpanded,
            onToggle: () {
              setState(() {
                _projectsExpanded = !_projectsExpanded;
              });
            },
            addTooltip: widget.copy.addProjectTooltip,
            onAddProject: _addProject,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_projectsExpanded && widget.projects.isNotEmpty)
                  KeyedSubtree(
                    key: const Key('projects-section-project-list'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.projects.length; i++) ...[
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: desktopDensityValue(
                                density,
                                compact: 3,
                                comfortable: 4,
                              ),
                            ),
                            child: _ProjectTile(
                              key: Key('sidebar-project-tile-$i'),
                              copy: widget.copy,
                              project: widget.projects[i],
                              interfaceDensity: density,
                              openDestination:
                                  widget.preferences.openDestination,
                              selected: i == widget.selectedProjectIndex,
                              isManaged: widget.projects[i].registryId != null,
                              isPinned: widget.projects[i].isPinned,
                              onTap: () {
                                widget.onProjectSelected(i);
                              },
                              onOpenProject: () =>
                                  widget.onOpenProject(widget.projects[i]),
                              onRename: (alias) => widget.onRenameProject(
                                widget.projects[i],
                                alias,
                              ),
                              onTogglePinned: () => widget
                                  .onToggleProjectPinned(widget.projects[i]),
                              onRemove: () =>
                                  widget.onRemoveProject(widget.projects[i]),
                            ),
                          ),
                          if (i == widget.selectedProjectIndex &&
                              widget.selectedProjectSessions.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                left: 30,
                                right: 4,
                                bottom: desktopDensityValue(
                                  density,
                                  compact: 8,
                                  comfortable: 10,
                                ),
                              ),
                              child: _SelectedProjectSessionList(
                                copy: widget.copy,
                                interfaceDensity: density,
                                sessions: widget.selectedProjectSessions,
                                onSessionSelected: widget.onOpenProjectSession,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
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
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: widget.copy.settingsLabel,
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
                  key: const Key('download-runtime-button'),
                  onPressed: widget.onDownloadRuntime,
                  tooltip: widget.copy.downloadRuntimeTooltip,
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
    required this.session,
    required this.onSubmitTask,
    required this.onAbortTask,
    super.key,
  });

  final WorkspaceCopy copy;
  final AppPreferences preferences;
  final WorkspaceProjectGroup? project;
  final List<WorkspacePromptCard> promptCards;
  final TextEditingController composerController;
  final WorkspaceSessionState? session;
  final VoidCallback onSubmitTask;
  final VoidCallback? onAbortTask;

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
                      ? _WorkspaceEmptyState(
                          copy: copy,
                          promptCards: promptCards,
                        )
                      : _ProjectSessionCanvas(copy: copy, session: session),
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
                    session: session,
                    controller: composerController,
                    onSubmit: onSubmitTask,
                    onAbort: onAbortTask,
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
