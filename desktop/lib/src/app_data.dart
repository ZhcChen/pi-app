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
