part of 'desktop_shell.dart';

List<WorkspaceAction> _buildPrimaryActions(_AppCopy copy) {
  return [
    WorkspaceAction(
      label: copy.isChinese ? '新任务' : 'New task',
      icon: Icons.edit_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '计划任务' : 'Scheduled',
      icon: Icons.schedule_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '插件' : 'Plugins',
      icon: Icons.extension_outlined,
    ),
    WorkspaceAction(
      label: copy.isChinese ? '拉取请求' : 'Pull requests',
      icon: Icons.call_split_outlined,
    ),
  ];
}

List<WorkspacePromptCard> _buildPromptCards(_AppCopy copy) {
  return [
    WorkspacePromptCard(
      title: copy.promptExplore,
      icon: Icons.travel_explore_outlined,
      color: const Color(0xFF3CA4FF),
    ),
    WorkspacePromptCard(
      title: copy.promptBuild,
      icon: Icons.auto_fix_high_outlined,
      color: const Color(0xFFB57BFF),
    ),
    WorkspacePromptCard(
      title: copy.promptReview,
      icon: Icons.sync_alt_rounded,
      color: const Color(0xFF39D273),
    ),
    WorkspacePromptCard(
      title: copy.promptFix,
      icon: Icons.local_fire_department_outlined,
      color: const Color(0xFFFF8A3C),
    ),
  ];
}

List<_SettingsNavSection> _buildSettingsSections(_AppCopy copy) {
  return [
    _SettingsNavSection(
      label: copy.personalGroupLabel,
      items: [
        _SettingsNavItem(
          category: _SettingsCategory.general,
          label: copy.settingsCategoryLabel(_SettingsCategory.general),
          icon: Icons.settings_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.appearance,
          label: copy.settingsCategoryLabel(_SettingsCategory.appearance),
          icon: Icons.light_mode_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.voice,
          label: copy.settingsCategoryLabel(_SettingsCategory.voice),
          icon: Icons.mic_none_rounded,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.configuration,
          label: copy.settingsCategoryLabel(_SettingsCategory.configuration),
          icon: Icons.tune_rounded,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.personalization,
          label: copy.settingsCategoryLabel(_SettingsCategory.personalization),
          icon: Icons.auto_awesome_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.pets,
          label: copy.settingsCategoryLabel(_SettingsCategory.pets),
          icon: Icons.pets_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.keyboardShortcuts,
          label: copy.settingsCategoryLabel(
            _SettingsCategory.keyboardShortcuts,
          ),
          icon: Icons.keyboard_command_key_rounded,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.account,
          label: copy.settingsCategoryLabel(_SettingsCategory.account),
          icon: Icons.account_circle_outlined,
          external: true,
        ),
      ],
    ),
    _SettingsNavSection(
      label: copy.integrationsGroupLabel,
      items: [
        _SettingsNavItem(
          category: _SettingsCategory.appshots,
          label: copy.settingsCategoryLabel(_SettingsCategory.appshots),
          icon: Icons.crop_free_rounded,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.plugins,
          label: copy.settingsCategoryLabel(_SettingsCategory.plugins),
          icon: Icons.extension_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.browser,
          label: copy.settingsCategoryLabel(_SettingsCategory.browser),
          icon: Icons.web_asset_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.computerUse,
          label: copy.settingsCategoryLabel(_SettingsCategory.computerUse),
          icon: Icons.mouse_outlined,
        ),
      ],
    ),
    _SettingsNavSection(
      label: copy.codingGroupLabel,
      items: [
        _SettingsNavItem(
          category: _SettingsCategory.hooks,
          label: copy.settingsCategoryLabel(_SettingsCategory.hooks),
          icon: Icons.anchor_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.connections,
          label: copy.settingsCategoryLabel(_SettingsCategory.connections),
          icon: Icons.hub_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.git,
          label: copy.settingsCategoryLabel(_SettingsCategory.git),
          icon: Icons.merge_type_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.environments,
          label: copy.settingsCategoryLabel(_SettingsCategory.environments),
          icon: Icons.terminal_outlined,
        ),
        _SettingsNavItem(
          category: _SettingsCategory.worktrees,
          label: copy.settingsCategoryLabel(_SettingsCategory.worktrees),
          icon: Icons.account_tree_outlined,
        ),
      ],
    ),
    _SettingsNavSection(
      label: copy.archivedGroupLabel,
      items: [
        _SettingsNavItem(
          category: _SettingsCategory.archivedTasks,
          label: copy.settingsCategoryLabel(_SettingsCategory.archivedTasks),
          icon: Icons.archive_outlined,
        ),
      ],
    ),
  ];
}

List<_SettingsNavSection> _filterSettingsSections(
  List<_SettingsNavSection> sections,
  String query,
) {
  if (query.isEmpty) {
    return sections;
  }

  final normalizedQuery = query.toLowerCase();
  final filtered = <_SettingsNavSection>[];

  for (final section in sections) {
    final matches = section.items.where((item) {
      return item.label.toLowerCase().contains(normalizedQuery);
    }).toList();

    if (matches.isNotEmpty) {
      filtered.add(_SettingsNavSection(label: section.label, items: matches));
    }
  }

  return filtered;
}

const List<WorkspaceProjectGroup> _projects = [
  WorkspaceProjectGroup(
    name: 'pi-app',
    branch: 'main',
    items: ['desktop shell redesign', 'runtime bridge', 'branding assets'],
  ),
  WorkspaceProjectGroup(
    name: 'yuance',
    branch: 'feature/ui',
    items: ['analyze project', 'analyze project', 'analyze project'],
  ),
  WorkspaceProjectGroup(
    name: 'novel-1',
    branch: 'local',
    items: ['draft scene'],
  ),
];
