part of 'desktop_shell.dart';

enum _DesktopRoute { workspace, settings }

enum _SettingsCategory {
  general,
  appearance,
  voice,
  configuration,
  personalization,
  pets,
  keyboardShortcuts,
  account,
  appshots,
  plugins,
  browser,
  computerUse,
  hooks,
  connections,
  git,
  environments,
  worktrees,
  archivedTasks,
}

class _SettingsNavSection {
  const _SettingsNavSection({required this.label, required this.items});

  final String label;
  final List<_SettingsNavItem> items;
}

class _SettingsNavItem {
  const _SettingsNavItem({
    required this.category,
    required this.label,
    required this.icon,
    this.external = false,
  });

  final _SettingsCategory category;
  final String label;
  final IconData icon;
  final bool external;
}

class _DropdownEntry<T> {
  const _DropdownEntry({required this.value, required this.label});

  final T value;
  final String label;
}
