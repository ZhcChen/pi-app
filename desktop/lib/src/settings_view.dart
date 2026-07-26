part of '../main.dart';

class _SettingsView extends StatelessWidget {
  const _SettingsView({
    required this.copy,
    required this.preferences,
    required this.searchController,
    required this.sections,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onBackToApp,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
    required this.onUiScaleChanged,
    required this.onInterfaceDensityChanged,
    required this.onCodeFontChanged,
    required this.onOpenDestinationChanged,
    required this.onDefaultPermissionsChanged,
    required this.onAutoReviewChanged,
    required this.onFullAccessChanged,
    required this.onShowInMenuBarChanged,
    required this.onShowBottomPanelChanged,
    required this.onPreventSleepChanged,
    required this.onSuggestedPromptsChanged,
    required this.onShowLicenses,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final TextEditingController searchController;
  final List<_SettingsNavSection> sections;
  final _SettingsCategory selectedCategory;
  final ValueChanged<_SettingsCategory> onCategorySelected;
  final VoidCallback onBackToApp;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<AppUiScale> onUiScaleChanged;
  final ValueChanged<AppInterfaceDensity> onInterfaceDensityChanged;
  final ValueChanged<AppCodeFont> onCodeFontChanged;
  final ValueChanged<AppOpenDestination> onOpenDestinationChanged;
  final ValueChanged<bool> onDefaultPermissionsChanged;
  final ValueChanged<bool> onAutoReviewChanged;
  final ValueChanged<bool> onFullAccessChanged;
  final ValueChanged<bool> onShowInMenuBarChanged;
  final ValueChanged<bool> onShowBottomPanelChanged;
  final ValueChanged<bool> onPreventSleepChanged;
  final ValueChanged<bool> onSuggestedPromptsChanged;
  final VoidCallback onShowLicenses;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;

    return Row(
      children: [
        Container(
          width: 318,
          color: palette.settingsSidebar,
          padding: EdgeInsets.fromLTRB(
            12,
            _densityValue(density, compact: 16, comfortable: 20),
            10,
            12,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('back-to-app-button'),
                  onPressed: onBackToApp,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(copy.backToAppLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.textSecondary,
                    textStyle: _AppTypography.settingsBackLabel(palette),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: searchController,
                style: _AppTypography.settingsSearchText(palette),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: palette.textMuted,
                  ),
                  hintText: copy.searchSettingsHint,
                  hintStyle: _AppTypography.settingsSearchHint(palette),
                  filled: true,
                  fillColor: palette.settingsField,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.dividerLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.dividerLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.dividerStrong),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final section in sections) ...[
                      _SettingsGroupLabel(label: section.label),
                      const SizedBox(height: 6),
                      for (final item in section.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: _SettingsCategoryTile(
                            item: item,
                            interfaceDensity: density,
                            selected: item.category == selectedCategory,
                            onTap: () => onCategorySelected(item.category),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    if (sections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                        child: Text(
                          copy.noSettingsFoundLabel,
                          style: _AppTypography.placeholderBody(palette),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: palette.divider),
        Expanded(
          child: ColoredBox(
            color: palette.canvas,
            child: switch (selectedCategory) {
              _SettingsCategory.general => _GeneralSettingsContent(
                copy: copy,
                preferences: preferences,
                onLanguageChanged: onLanguageChanged,
                onOpenDestinationChanged: onOpenDestinationChanged,
                onDefaultPermissionsChanged: onDefaultPermissionsChanged,
                onAutoReviewChanged: onAutoReviewChanged,
                onFullAccessChanged: onFullAccessChanged,
                onShowInMenuBarChanged: onShowInMenuBarChanged,
                onShowBottomPanelChanged: onShowBottomPanelChanged,
                onPreventSleepChanged: onPreventSleepChanged,
                onSuggestedPromptsChanged: onSuggestedPromptsChanged,
                onShowLicenses: onShowLicenses,
              ),
              _SettingsCategory.appearance => _AppearanceSettingsContent(
                copy: copy,
                preferences: preferences,
                onThemeModeChanged: onThemeModeChanged,
                onUiScaleChanged: onUiScaleChanged,
                onInterfaceDensityChanged: onInterfaceDensityChanged,
                onCodeFontChanged: onCodeFontChanged,
              ),
              _ => _SettingsPlaceholderContent(
                title: copy.settingsCategoryLabel(selectedCategory),
                body: copy.settingsPlaceholderBody(
                  copy.settingsCategoryLabel(selectedCategory),
                ),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _GeneralSettingsContent extends StatelessWidget {
  const _GeneralSettingsContent({
    required this.copy,
    required this.preferences,
    required this.onLanguageChanged,
    required this.onOpenDestinationChanged,
    required this.onDefaultPermissionsChanged,
    required this.onAutoReviewChanged,
    required this.onFullAccessChanged,
    required this.onShowInMenuBarChanged,
    required this.onShowBottomPanelChanged,
    required this.onPreventSleepChanged,
    required this.onSuggestedPromptsChanged,
    required this.onShowLicenses,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppOpenDestination> onOpenDestinationChanged;
  final ValueChanged<bool> onDefaultPermissionsChanged;
  final ValueChanged<bool> onAutoReviewChanged;
  final ValueChanged<bool> onFullAccessChanged;
  final ValueChanged<bool> onShowInMenuBarChanged;
  final ValueChanged<bool> onShowBottomPanelChanged;
  final ValueChanged<bool> onPreventSleepChanged;
  final ValueChanged<bool> onSuggestedPromptsChanged;
  final VoidCallback onShowLicenses;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(64, 54, 64, 54),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 890),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.generalTitle,
                  key: const Key('settings-page-title'),
                  style: _AppTypography.settingsPageTitle(palette),
                ),
                const SizedBox(height: 46),
                Text(
                  copy.permissionsSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.defaultPermissionsTitle,
                        description: copy.defaultPermissionsDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('default-permissions-switch'),
                          value: preferences.defaultPermissions,
                          onChanged: onDefaultPermissionsChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.autoReviewTitle,
                        description: copy.autoReviewDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('auto-review-switch'),
                          value: preferences.autoReview,
                          onChanged: onAutoReviewChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.fullAccessTitle,
                        description: copy.fullAccessDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('full-access-switch'),
                          value: preferences.fullAccess,
                          onChanged: onFullAccessChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  copy.generalSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.defaultOpenDestinationTitle,
                        description: copy.defaultOpenDestinationDescription,
                        trailing: _SettingsDropdown<AppOpenDestination>(
                          dropdownKey: const Key('open-destination-dropdown'),
                          value: preferences.openDestination,
                          onChanged: onOpenDestinationChanged,
                          entries: [
                            _DropdownEntry(
                              value: AppOpenDestination.vscode,
                              label: copy.openDestinationLabel(
                                AppOpenDestination.vscode,
                              ),
                            ),
                            _DropdownEntry(
                              value: AppOpenDestination.cursor,
                              label: copy.openDestinationLabel(
                                AppOpenDestination.cursor,
                              ),
                            ),
                            _DropdownEntry(
                              value: AppOpenDestination.terminal,
                              label: copy.openDestinationLabel(
                                AppOpenDestination.terminal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.languageTitle,
                        description: copy.languageDescription,
                        trailing: _SettingsDropdown<AppLanguage>(
                          dropdownKey: const Key('language-dropdown'),
                          value: preferences.language,
                          onChanged: onLanguageChanged,
                          entries: [
                            _DropdownEntry(
                              value: AppLanguage.english,
                              label: copy.languageLabel(AppLanguage.english),
                            ),
                            _DropdownEntry(
                              value: AppLanguage.simplifiedChinese,
                              label: copy.languageLabel(
                                AppLanguage.simplifiedChinese,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.showInMenuBarTitle,
                        description: copy.showInMenuBarDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('show-in-menu-bar-switch'),
                          value: preferences.showInMenuBar,
                          onChanged: onShowInMenuBarChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.bottomPanelTitle,
                        description: copy.bottomPanelDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('show-bottom-panel-switch'),
                          value: preferences.showBottomPanel,
                          onChanged: onShowBottomPanelChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.preventSleepTitle,
                        description: copy.preventSleepDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('prevent-sleep-switch'),
                          value: preferences.preventSleep,
                          onChanged: onPreventSleepChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.suggestedPromptsTitle,
                        description: copy.suggestedPromptsDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('suggested-prompts-switch'),
                          value: preferences.suggestedPrompts,
                          onChanged: onSuggestedPromptsChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.importWorkTitle,
                        description: copy.importWorkDescription,
                        trailing: _SettingsActionButton(
                          label: copy.importActionLabel,
                          onPressed: () {},
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        interfaceDensity: density,
                        title: copy.openSourceLicensesTitle,
                        description: copy.openSourceLicensesDescription,
                        trailing: _SettingsActionButton(
                          label: copy.viewActionLabel,
                          onPressed: onShowLicenses,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceSettingsContent extends StatelessWidget {
  const _AppearanceSettingsContent({
    required this.copy,
    required this.preferences,
    required this.onThemeModeChanged,
    required this.onUiScaleChanged,
    required this.onInterfaceDensityChanged,
    required this.onCodeFontChanged,
  });

  final _AppCopy copy;
  final AppPreferences preferences;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<AppUiScale> onUiScaleChanged;
  final ValueChanged<AppInterfaceDensity> onInterfaceDensityChanged;
  final ValueChanged<AppCodeFont> onCodeFontChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(64, 54, 64, 54),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 890),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.appearanceTitle,
                  key: const Key('appearance-page-title'),
                  style: _AppTypography.settingsPageTitle(palette),
                ),
                const SizedBox(height: 46),
                Text(
                  copy.themeSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsFieldBlock(
                        title: copy.themeModeTitle,
                        description: copy.themeModeDescription,
                        child: _SettingsSegmentedControl<AppThemeMode>(
                          values: [
                            AppThemeMode.dark,
                            AppThemeMode.light,
                            AppThemeMode.system,
                          ],
                          currentValue: preferences.themeMode,
                          labelBuilder: copy.themeModeLabel,
                          onChanged: onThemeModeChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  copy.typographySectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsFieldBlock(
                        title: copy.interfaceTextSizeTitle,
                        description: copy.interfaceTextSizeDescription,
                        child: _SettingsSegmentedControl<AppUiScale>(
                          values: [
                            AppUiScale.small,
                            AppUiScale.regular,
                            AppUiScale.large,
                          ],
                          currentValue: preferences.uiScale,
                          labelBuilder: copy.uiScaleLabel,
                          onChanged: onUiScaleChanged,
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsFieldBlock(
                        title: copy.codeFontTitle,
                        description: copy.codeFontDescription,
                        child: _SettingsDropdown<AppCodeFont>(
                          dropdownKey: const Key('code-font-dropdown'),
                          value: preferences.codeFont,
                          onChanged: onCodeFontChanged,
                          entries: [
                            _DropdownEntry(
                              value: AppCodeFont.jetBrainsMono,
                              label: copy.codeFontLabel(
                                AppCodeFont.jetBrainsMono,
                              ),
                            ),
                            _DropdownEntry(
                              value: AppCodeFont.systemMono,
                              label: copy.codeFontLabel(AppCodeFont.systemMono),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  copy.layoutSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsFieldBlock(
                        title: copy.interfaceDensityTitle,
                        description: copy.interfaceDensityDescription,
                        child: _SettingsSegmentedControl<AppInterfaceDensity>(
                          values: [
                            AppInterfaceDensity.compact,
                            AppInterfaceDensity.comfortable,
                          ],
                          currentValue: preferences.interfaceDensity,
                          labelBuilder: copy.interfaceDensityLabel,
                          onChanged: onInterfaceDensityChanged,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 42),
                Text(
                  copy.previewSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: _AppearancePreview(
                    copy: copy,
                    preferences: preferences,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.copy, required this.preferences});

  final _AppCopy copy;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.previewSectionDescription,
            style: _AppTypography.placeholderBody(palette),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            height: 276,
            decoration: BoxDecoration(
              color: palette.canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.dividerLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 176,
                  decoration: BoxDecoration(
                    color: palette.sidebar,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    _densityValue(density, compact: 12, comfortable: 16),
                    12,
                    12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
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
                      ),
                      SizedBox(
                        height: _densityValue(
                          density,
                          compact: 10,
                          comfortable: 14,
                        ),
                      ),
                      _PreviewSidebarItem(
                        label: copy.settingsLabel,
                        selected: true,
                      ),
                      _PreviewSidebarItem(
                        label: copy.settingsCategoryLabel(
                          _SettingsCategory.appearance,
                        ),
                      ),
                      _PreviewSidebarItem(label: copy.projectsLabel),
                      const Spacer(),
                      _PreviewSidebarItem(label: copy.tasksLabel),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.previewUiLabel,
                          style: _AppTypography.settingsGroupLabel(palette),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          copy.previewUiHeadline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _AppTypography.previewHeadline(palette),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          copy.previewUiBody,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _AppTypography.previewBody(palette),
                        ),
                        SizedBox(
                          height: _densityValue(
                            density,
                            compact: 10,
                            comfortable: 12,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: palette.panel,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: palette.dividerLight),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.previewCodeLabel,
                                  style: _AppTypography.settingsGroupLabel(
                                    palette,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: palette.settingsField,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                    child: Align(
                                      alignment: Alignment.topLeft,
                                      child: Text(
                                        copy.previewCodeSnippet,
                                        style: _withCodeFont(
                                          _AppTypography.codePreview(palette),
                                          preferences.codeFont,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: _densityValue(
                            density,
                            compact: 10,
                            comfortable: 12,
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(
                            14,
                            _densityValue(
                              density,
                              compact: 12,
                              comfortable: 14,
                            ),
                            14,
                            _densityValue(
                              density,
                              compact: 10,
                              comfortable: 12,
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: palette.composerShell,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.dividerLight),
                          ),
                          child: Text(
                            copy.composerHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _withCodeFont(
                              _AppTypography.composerHint(palette),
                              preferences.codeFont,
                            ),
                          ),
                        ),
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

class _PreviewSidebarItem extends StatelessWidget {
  const _PreviewSidebarItem({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      height: 30,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: selected ? palette.selection : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.centerLeft,
      child: Text(label, style: _AppTypography.sectionLabel(palette)),
    );
  }
}

class _SettingsPlaceholderContent extends StatelessWidget {
  const _SettingsPlaceholderContent({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(64, 54, 64, 54),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 890),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _AppTypography.settingsPageTitle(palette)),
              const SizedBox(height: 24),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  child: Text(
                    body,
                    style: _AppTypography.placeholderBody(palette),
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

class _SettingsCategoryTile extends StatelessWidget {
  const _SettingsCategoryTile({
    required this.item,
    required this.interfaceDensity,
    required this.selected,
    required this.onTap,
  });

  final _SettingsNavItem item;
  final AppInterfaceDensity interfaceDensity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: _densityValue(interfaceDensity, compact: 30, comfortable: 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? palette.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 17, color: palette.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: _AppTypography.settingsNavItem(palette),
              ),
            ),
            if (item.external)
              Icon(
                Icons.north_east_rounded,
                size: 14,
                color: palette.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroupLabel extends StatelessWidget {
  const _SettingsGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Text(label, style: _AppTypography.settingsGroupLabel(palette)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.panelRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.dividerLight),
      ),
      child: child,
    );
  }
}

class _SettingsFieldBlock extends StatelessWidget {
  const _SettingsFieldBlock({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _AppTypography.settingsRowTitle(palette)),
          const SizedBox(height: 4),
          Text(
            description,
            style: _AppTypography.settingsRowDescription(palette),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SettingsSegmentedControl<T> extends StatelessWidget {
  const _SettingsSegmentedControl({
    required this.values,
    required this.currentValue,
    required this.labelBuilder,
    required this.onChanged,
  });

  final List<T> values;
  final T currentValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return palette.selection;
            }
            return palette.settingsField;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? palette.textStrong
                : palette.textSecondary;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: palette.dividerLight),
          ),
        ),
        segments: values
            .map(
              (value) => ButtonSegment<T>(
                value: value,
                label: Text(labelBuilder(value)),
              ),
            )
            .toList(),
        selected: {currentValue},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            onChanged(selection.first);
          }
        },
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.interfaceDensity,
    required this.title,
    required this.description,
    required this.trailing,
  });

  final AppInterfaceDensity interfaceDensity;
  final String title;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final verticalPadding = _densityValue(
          interfaceDensity,
          compact: 14,
          comfortable: 16,
        );

        if (compact) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              verticalPadding,
              18,
              verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _AppTypography.settingsRowTitle(palette)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: _AppTypography.settingsRowDescription(palette),
                ),
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            verticalPadding,
            18,
            verticalPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _AppTypography.settingsRowTitle(palette),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: _AppTypography.settingsRowDescription(palette),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Align(alignment: Alignment.topRight, child: trailing),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Divider(height: 1, color: palette.dividerSoft);
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        foregroundColor: palette.textStrong,
        backgroundColor: palette.settingsField,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _AppTypography.controlLabel(palette),
      ),
      child: Text(label),
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final Key? switchKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Switch(
      key: switchKey,
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeThumbColor: Colors.white,
      activeTrackColor: palette.switchActive,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: palette.switchInactive,
    );
  }
}

class _SettingsDropdown<T> extends StatelessWidget {
  const _SettingsDropdown({
    this.dropdownKey,
    required this.value,
    required this.onChanged,
    required this.entries,
  });

  final Key? dropdownKey;
  final T value;
  final ValueChanged<T> onChanged;
  final List<_DropdownEntry<T>> entries;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return Container(
      key: dropdownKey,
      constraints: const BoxConstraints(minWidth: 228),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: palette.settingsField,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.dividerLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          dropdownColor: palette.panelRaised,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: palette.textMuted,
          ),
          style: _AppTypography.settingsDropdownValue(palette),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
          items: entries
              .map(
                (entry) => DropdownMenuItem<T>(
                  value: entry.value,
                  child: Text(entry.label),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
