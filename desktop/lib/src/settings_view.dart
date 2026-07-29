part of 'settings_feature.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({
    super.key,
    required this.copy,
    required this.preferences,
    required this.runtimeCapabilities,
    required this.piConfigSnapshot,
    required this.piConfigLoadError,
    required this.piCoreRuntimeSnapshot,
    required this.onRefreshPiCoreRuntime,
    required this.onChoosePiCoreExecutable,
    required this.onClearPiCoreExecutable,
    required this.piCoreInstallerStatus,
    required this.piCoreInstallerBusy,
    required this.piCoreInstallerProgressPercent,
    required this.piCoreInstallerSourceUrl,
    required this.piCoreInstallerScriptPath,
    required this.piCoreInstallerLogPath,
    required this.piCoreInstallerActionLabel,
    required this.onPiCoreInstallerAction,
    required this.piCoreInstallerSecondaryActionLabel,
    required this.onPiCoreInstallerSecondaryAction,
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
    required this.onSavePromptFile,
    required this.onSaveModelPreferences,
    required this.onSaveModelsJson,
    required this.appUpdateStatus,
    required this.appUpdateChecking,
    required this.appUpdateDownloading,
    required this.appUpdateAvailable,
    required this.appUpdateReadyToInstall,
    required this.appUpdateProgressPercent,
    required this.onCheckForUpdate,
    required this.onDownloadUpdate,
    required this.onQuitAndInstall,
    required this.onShowLicenses,
  });

  final SettingsCopy copy;
  final AppPreferences preferences;
  final DesktopRuntimeCapabilities runtimeCapabilities;
  final PiConfigSnapshot? piConfigSnapshot;
  final String? piConfigLoadError;
  final PiCoreRuntimeSnapshot piCoreRuntimeSnapshot;
  final Future<void> Function() onRefreshPiCoreRuntime;
  final Future<void> Function() onChoosePiCoreExecutable;
  final Future<void> Function() onClearPiCoreExecutable;
  final String piCoreInstallerStatus;
  final bool piCoreInstallerBusy;
  final int? piCoreInstallerProgressPercent;
  final String piCoreInstallerSourceUrl;
  final String? piCoreInstallerScriptPath;
  final String? piCoreInstallerLogPath;
  final String? piCoreInstallerActionLabel;
  final VoidCallback? onPiCoreInstallerAction;
  final String? piCoreInstallerSecondaryActionLabel;
  final VoidCallback? onPiCoreInstallerSecondaryAction;
  final TextEditingController searchController;
  final List<SettingsNavSection> sections;
  final SettingsCategory selectedCategory;
  final ValueChanged<SettingsCategory> onCategorySelected;
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
  final Future<void> Function(PiPromptFileKind kind, String content)
  onSavePromptFile;
  final Future<void> Function(PiModelPreferences preferences)
  onSaveModelPreferences;
  final Future<void> Function(String content) onSaveModelsJson;
  final String appUpdateStatus;
  final bool appUpdateChecking;
  final bool appUpdateDownloading;
  final bool appUpdateAvailable;
  final bool appUpdateReadyToInstall;
  final int? appUpdateProgressPercent;
  final VoidCallback onCheckForUpdate;
  final VoidCallback onDownloadUpdate;
  final VoidCallback onQuitAndInstall;
  final VoidCallback onShowLicenses;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;

    return Row(
      children: [
        Container(
          width: 306,
          color: palette.settingsSidebar,
          padding: EdgeInsets.fromLTRB(
            12,
            _densityValue(density, compact: 14, comfortable: 18),
            10,
            12,
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _DesktopTextActionButton(
                  buttonKey: const Key('back-to-app-button'),
                  onPressed: onBackToApp,
                  icon: const Icon(Icons.arrow_back_rounded, size: 17),
                  label: copy.backToAppLabel,
                  alignment: Alignment.centerLeft,
                  radius: 10,
                  textStyle: _AppTypography.settingsBackLabel(palette),
                ),
              ),
              const SizedBox(height: 8),
              _DesktopFieldSurface(
                radius: 10,
                constraints: const BoxConstraints(minHeight: 38),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: palette.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        style: _AppTypography.settingsSearchText(palette),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: copy.searchSettingsHint,
                          hintStyle: _AppTypography.settingsSearchHint(palette),
                        ),
                      ),
                    ),
                  ],
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
                          child: SettingsCategoryTile(
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
              SettingsCategory.general => _GeneralSettingsContent(
                copy: copy,
                preferences: preferences,
                runtimeCapabilities: runtimeCapabilities,
                piCoreRuntimeSnapshot: piCoreRuntimeSnapshot,
                onRefreshPiCoreRuntime: onRefreshPiCoreRuntime,
                onChoosePiCoreExecutable: onChoosePiCoreExecutable,
                onClearPiCoreExecutable: onClearPiCoreExecutable,
                piCoreInstallerStatus: piCoreInstallerStatus,
                piCoreInstallerBusy: piCoreInstallerBusy,
                piCoreInstallerProgressPercent: piCoreInstallerProgressPercent,
                piCoreInstallerSourceUrl: piCoreInstallerSourceUrl,
                piCoreInstallerScriptPath: piCoreInstallerScriptPath,
                piCoreInstallerLogPath: piCoreInstallerLogPath,
                piCoreInstallerActionLabel: piCoreInstallerActionLabel,
                onPiCoreInstallerAction: onPiCoreInstallerAction,
                piCoreInstallerSecondaryActionLabel:
                    piCoreInstallerSecondaryActionLabel,
                onPiCoreInstallerSecondaryAction:
                    onPiCoreInstallerSecondaryAction,
                onLanguageChanged: onLanguageChanged,
                onOpenDestinationChanged: onOpenDestinationChanged,
                onDefaultPermissionsChanged: onDefaultPermissionsChanged,
                onAutoReviewChanged: onAutoReviewChanged,
                onFullAccessChanged: onFullAccessChanged,
                onShowInMenuBarChanged: onShowInMenuBarChanged,
                onShowBottomPanelChanged: onShowBottomPanelChanged,
                onPreventSleepChanged: onPreventSleepChanged,
                onSuggestedPromptsChanged: onSuggestedPromptsChanged,
                appUpdateStatus: appUpdateStatus,
                appUpdateChecking: appUpdateChecking,
                appUpdateDownloading: appUpdateDownloading,
                appUpdateAvailable: appUpdateAvailable,
                appUpdateReadyToInstall: appUpdateReadyToInstall,
                appUpdateProgressPercent: appUpdateProgressPercent,
                onCheckForUpdate: onCheckForUpdate,
                onDownloadUpdate: onDownloadUpdate,
                onQuitAndInstall: onQuitAndInstall,
                onShowLicenses: onShowLicenses,
              ),
              SettingsCategory.appearance => _AppearanceSettingsContent(
                copy: copy,
                preferences: preferences,
                onThemeModeChanged: onThemeModeChanged,
                onUiScaleChanged: onUiScaleChanged,
                onInterfaceDensityChanged: onInterfaceDensityChanged,
                onCodeFontChanged: onCodeFontChanged,
              ),
              SettingsCategory.piModels => _PiModelsSettingsContent(
                copy: copy,
                preferences: preferences,
                snapshot: piConfigSnapshot,
                loadError: piConfigLoadError,
                onSaveModelPreferences: onSaveModelPreferences,
                onSaveModelsJson: onSaveModelsJson,
              ),
              SettingsCategory.piPrompts => _PiPromptsSettingsContent(
                copy: copy,
                preferences: preferences,
                snapshot: piConfigSnapshot,
                loadError: piConfigLoadError,
                onSavePromptFile: onSavePromptFile,
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
    required this.runtimeCapabilities,
    required this.piCoreRuntimeSnapshot,
    required this.onRefreshPiCoreRuntime,
    required this.onChoosePiCoreExecutable,
    required this.onClearPiCoreExecutable,
    required this.piCoreInstallerStatus,
    required this.piCoreInstallerBusy,
    required this.piCoreInstallerProgressPercent,
    required this.piCoreInstallerSourceUrl,
    required this.piCoreInstallerScriptPath,
    required this.piCoreInstallerLogPath,
    required this.piCoreInstallerActionLabel,
    required this.onPiCoreInstallerAction,
    required this.piCoreInstallerSecondaryActionLabel,
    required this.onPiCoreInstallerSecondaryAction,
    required this.onLanguageChanged,
    required this.onOpenDestinationChanged,
    required this.onDefaultPermissionsChanged,
    required this.onAutoReviewChanged,
    required this.onFullAccessChanged,
    required this.onShowInMenuBarChanged,
    required this.onShowBottomPanelChanged,
    required this.onPreventSleepChanged,
    required this.onSuggestedPromptsChanged,
    required this.appUpdateStatus,
    required this.appUpdateChecking,
    required this.appUpdateDownloading,
    required this.appUpdateAvailable,
    required this.appUpdateReadyToInstall,
    required this.appUpdateProgressPercent,
    required this.onCheckForUpdate,
    required this.onDownloadUpdate,
    required this.onQuitAndInstall,
    required this.onShowLicenses,
  });

  final SettingsCopy copy;
  final AppPreferences preferences;
  final DesktopRuntimeCapabilities runtimeCapabilities;
  final PiCoreRuntimeSnapshot piCoreRuntimeSnapshot;
  final Future<void> Function() onRefreshPiCoreRuntime;
  final Future<void> Function() onChoosePiCoreExecutable;
  final Future<void> Function() onClearPiCoreExecutable;
  final String piCoreInstallerStatus;
  final bool piCoreInstallerBusy;
  final int? piCoreInstallerProgressPercent;
  final String piCoreInstallerSourceUrl;
  final String? piCoreInstallerScriptPath;
  final String? piCoreInstallerLogPath;
  final String? piCoreInstallerActionLabel;
  final VoidCallback? onPiCoreInstallerAction;
  final String? piCoreInstallerSecondaryActionLabel;
  final VoidCallback? onPiCoreInstallerSecondaryAction;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppOpenDestination> onOpenDestinationChanged;
  final ValueChanged<bool> onDefaultPermissionsChanged;
  final ValueChanged<bool> onAutoReviewChanged;
  final ValueChanged<bool> onFullAccessChanged;
  final ValueChanged<bool> onShowInMenuBarChanged;
  final ValueChanged<bool> onShowBottomPanelChanged;
  final ValueChanged<bool> onPreventSleepChanged;
  final ValueChanged<bool> onSuggestedPromptsChanged;
  final String appUpdateStatus;
  final bool appUpdateChecking;
  final bool appUpdateDownloading;
  final bool appUpdateAvailable;
  final bool appUpdateReadyToInstall;
  final int? appUpdateProgressPercent;
  final VoidCallback onCheckForUpdate;
  final VoidCallback onDownloadUpdate;
  final VoidCallback onQuitAndInstall;
  final VoidCallback onShowLicenses;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final density = preferences.interfaceDensity;
    final showInMenuBarSupported = runtimeCapabilities.supportsShowInMenuBar;
    final showInMenuBarDescription = showInMenuBarSupported
        ? copy.showInMenuBarDescription
        : copy.showInMenuBarUnsupportedDescription;
    final isUpdateBusy = appUpdateChecking || appUpdateDownloading;
    final installerScriptPath = piCoreInstallerScriptPath;
    final installerLogPath = piCoreInstallerLogPath;
    final updateActionLabel = appUpdateReadyToInstall
        ? copy.quitAndInstallActionLabel
        : appUpdateAvailable
        ? copy.downloadUpdateActionLabel
        : copy.checkForUpdatesActionLabel;
    final updateAction = appUpdateReadyToInstall
        ? onQuitAndInstall
        : appUpdateAvailable
        ? onDownloadUpdate
        : onCheckForUpdate;

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
                  copy.piCoreRuntimeSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: _PiCoreRuntimeSettingsCard(
                    copy: copy,
                    snapshot: piCoreRuntimeSnapshot,
                    hasSelectedExecutable:
                        preferences.piCoreExecutablePath != null,
                    onRefresh: onRefreshPiCoreRuntime,
                    onChooseExecutable: onChoosePiCoreExecutable,
                    onClearExecutable: onClearPiCoreExecutable,
                    installerStatus: piCoreInstallerStatus,
                    installerBusy: piCoreInstallerBusy,
                    installerProgressPercent: piCoreInstallerProgressPercent,
                    installerSourceUrl: piCoreInstallerSourceUrl,
                    installerScriptPath: installerScriptPath,
                    installerLogPath: installerLogPath,
                    installerActionLabel: piCoreInstallerActionLabel,
                    onInstallerAction: onPiCoreInstallerAction,
                    installerSecondaryActionLabel:
                        piCoreInstallerSecondaryActionLabel,
                    onInstallerSecondaryAction:
                        onPiCoreInstallerSecondaryAction,
                  ),
                ),
                const SizedBox(height: 42),
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
                        description: showInMenuBarDescription,
                        trailing: _SettingsSwitch(
                          switchKey: const Key('show-in-menu-bar-switch'),
                          value: preferences.showInMenuBar,
                          onChanged: showInMenuBarSupported
                              ? onShowInMenuBarChanged
                              : null,
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
                const SizedBox(height: 42),
                Text(
                  copy.appUpdatesSectionTitle,
                  style: _AppTypography.settingsSectionTitle(palette),
                ),
                const SizedBox(height: 14),
                _SettingsCard(
                  child: _SettingsRow(
                    interfaceDensity: density,
                    title: copy.appUpdateTitle,
                    description: appUpdateStatus,
                    trailing: isUpdateBusy
                        ? SizedBox(
                            width: 164,
                            child: LinearProgressIndicator(
                              value:
                                  appUpdateDownloading &&
                                      appUpdateProgressPercent != null
                                  ? appUpdateProgressPercent! / 100
                                  : null,
                            ),
                          )
                        : _SettingsActionButton(
                            buttonKey: const Key('app-update-action-button'),
                            label: updateActionLabel,
                            onPressed: updateAction,
                          ),
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

class _PiCoreRuntimeSettingsCard extends StatelessWidget {
  const _PiCoreRuntimeSettingsCard({
    required this.copy,
    required this.snapshot,
    required this.hasSelectedExecutable,
    required this.onRefresh,
    required this.onChooseExecutable,
    required this.onClearExecutable,
    required this.installerStatus,
    required this.installerBusy,
    required this.installerProgressPercent,
    required this.installerSourceUrl,
    required this.installerScriptPath,
    required this.installerLogPath,
    required this.installerActionLabel,
    required this.onInstallerAction,
    required this.installerSecondaryActionLabel,
    required this.onInstallerSecondaryAction,
  });

  final SettingsCopy copy;
  final PiCoreRuntimeSnapshot snapshot;
  final bool hasSelectedExecutable;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onChooseExecutable;
  final Future<void> Function() onClearExecutable;
  final String installerStatus;
  final bool installerBusy;
  final int? installerProgressPercent;
  final String installerSourceUrl;
  final String? installerScriptPath;
  final String? installerLogPath;
  final String? installerActionLabel;
  final VoidCallback? onInstallerAction;
  final String? installerSecondaryActionLabel;
  final VoidCallback? onInstallerSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final diagnostic = copy.piCoreRuntimeStatusDescription(
      snapshot.status,
      snapshot.diagnosticCode,
    );
    final executablePath =
        snapshot.executablePath ?? copy.piCoreRuntimeNotDetectedLabel;
    final version = snapshot.version ?? copy.piCoreRuntimeNotDetectedLabel;

    return Padding(
      key: const Key('pi-core-runtime-card'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copy.piCoreRuntimeTitle,
                      style: _AppTypography.settingsRowTitle(palette),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      copy.piCoreRuntimeStatusLabel(snapshot.status),
                      key: const Key('pi-core-runtime-status'),
                      style: _AppTypography.settingsRowDescription(palette),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: copy.piCoreRuntimeRefreshTooltip,
                child: IconButton(
                  key: const Key('pi-core-runtime-refresh-button'),
                  onPressed: () {
                    unawaited(onRefresh());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              Tooltip(
                message: copy.piCoreRuntimeChooseTooltip,
                child: IconButton(
                  key: const Key('pi-core-runtime-choose-button'),
                  onPressed: () {
                    unawaited(onChooseExecutable());
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                ),
              ),
              if (hasSelectedExecutable)
                Tooltip(
                  message: copy.piCoreRuntimeClearTooltip,
                  child: IconButton(
                    key: const Key('pi-core-runtime-clear-button'),
                    onPressed: () {
                      unawaited(onClearExecutable());
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            diagnostic,
            style: _AppTypography.settingsRowDescription(palette),
          ),
          const SizedBox(height: 14),
          const _SettingsDivider(),
          const SizedBox(height: 12),
          _PiCoreRuntimeMetadataRow(
            label: copy.piCoreRuntimePathLabel,
            value: executablePath,
          ),
          const SizedBox(height: 8),
          _PiCoreRuntimeMetadataRow(
            label: copy.piCoreRuntimeVersionLabel,
            value: version,
          ),
          const SizedBox(height: 8),
          _PiCoreRuntimeMetadataRow(
            label: copy.piCoreRuntimeSourceTitle,
            value: copy.piCoreRuntimeSourceLabel(snapshot.source),
            valueIsSource: true,
          ),
          const SizedBox(height: 14),
          const _SettingsDivider(),
          const SizedBox(height: 12),
          Text(
            copy.piCoreInstallerTitle,
            style: _AppTypography.settingsGroupLabel(palette),
          ),
          const SizedBox(height: 6),
          Text(
            installerStatus,
            key: const Key('pi-core-installer-status'),
            style: _AppTypography.settingsRowDescription(palette),
          ),
          const SizedBox(height: 12),
          if (installerBusy)
            SizedBox(
              width: 164,
              child: LinearProgressIndicator(
                key: const Key('pi-core-installer-progress'),
                value: installerProgressPercent == null
                    ? null
                    : installerProgressPercent! / 100,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (installerActionLabel != null && onInstallerAction != null)
                  _SettingsActionButton(
                    buttonKey: const Key('pi-core-installer-action-button'),
                    label: installerActionLabel!,
                    onPressed: onInstallerAction,
                  ),
                if (installerSecondaryActionLabel != null &&
                    onInstallerSecondaryAction != null)
                  _SettingsActionButton(
                    buttonKey: const Key(
                      'pi-core-installer-secondary-action-button',
                    ),
                    label: installerSecondaryActionLabel!,
                    onPressed: onInstallerSecondaryAction,
                  ),
              ],
            ),
          const SizedBox(height: 14),
          const _SettingsDivider(),
          const SizedBox(height: 12),
          _PiCoreRuntimeMetadataRow(
            label: copy.piCoreInstallerSourceLabel,
            value: installerSourceUrl,
            valueIsSource: true,
          ),
          if (installerScriptPath != null) ...[
            const SizedBox(height: 8),
            _PiCoreRuntimeMetadataRow(
              label: copy.piCoreInstallerScriptLabel,
              value: installerScriptPath!,
            ),
          ],
          if (installerLogPath != null) ...[
            const SizedBox(height: 8),
            _PiCoreRuntimeMetadataRow(
              label: copy.piCoreInstallerLogLabel,
              value: installerLogPath!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PiCoreRuntimeMetadataRow extends StatelessWidget {
  const _PiCoreRuntimeMetadataRow({
    required this.label,
    required this.value,
    this.valueIsSource = false,
  });

  final String label;
  final String value;
  final bool valueIsSource;

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: _AppTypography.settingsGroupLabel(palette)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            maxLines: valueIsSource ? 1 : 2,
            style: _AppTypography.settingsRowDescription(palette),
          ),
        ),
      ],
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

  final SettingsCopy copy;
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

  final SettingsCopy copy;
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
          _DesktopSurface(
            color: palette.canvas,
            radius: 16,
            width: double.infinity,
            height: 276,
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
                          SettingsCategory.appearance,
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
                          child: _DesktopSurface(
                            color: palette.panel,
                            radius: 14,
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
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
                                  child: _DesktopFieldSurface(
                                    radius: 12,
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
                        _DesktopSurface(
                          color: palette.composerShell,
                          radius: 16,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: _DesktopSelectionTile(
        selected: selected,
        height: 28,
        radius: 9,
        animated: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: _AppTypography.sectionLabel(palette)),
          ),
        ),
      ),
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
                    horizontal: 18,
                    vertical: 18,
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
