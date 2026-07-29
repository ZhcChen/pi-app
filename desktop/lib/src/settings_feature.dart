import 'dart:async';

import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'app_runtime.dart';
import 'desktop_design.dart';
import 'desktop_primitives.dart';
import 'pi_config_store.dart';
import 'pi_core_runtime.dart';

part 'settings_view.dart';
part 'settings_components.dart';
part 'pi_config_view.dart';

extension _SettingsFeatureThemeLookup on BuildContext {
  DesktopPalette get appPalette => desktopPalette;
}

double _densityValue(
  AppInterfaceDensity density, {
  required double compact,
  required double comfortable,
}) {
  return desktopDensityValue(
    density,
    compact: compact,
    comfortable: comfortable,
  );
}

TextStyle _withCodeFont(TextStyle base, AppCodeFont codeFont) {
  return desktopWithCodeFont(base, codeFont);
}

typedef _AppTypography = DesktopTypography;
typedef _DesktopSurface = DesktopSurface;
typedef _DesktopFieldSurface = DesktopFieldSurface;
typedef _DesktopTextActionButton = DesktopTextActionButton;
typedef _DesktopSelectionTile = DesktopSelectionTile;

enum SettingsCategory {
  general,
  appearance,
  piModels,
  piPrompts,
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

class SettingsNavSection {
  const SettingsNavSection({required this.label, required this.items});

  final String label;
  final List<SettingsNavItem> items;
}

class SettingsNavItem {
  const SettingsNavItem({
    required this.category,
    required this.label,
    required this.icon,
    this.external = false,
  });

  final SettingsCategory category;
  final String label;
  final IconData icon;
  final bool external;
}

class _DropdownEntry<T> {
  const _DropdownEntry({required this.value, required this.label});

  final T value;
  final String label;
}

abstract interface class SettingsCopy {
  String get settingsLabel;
  String get backToAppLabel;
  String get searchSettingsHint;
  String get noSettingsFoundLabel;
  String get generalTitle;
  String get piCoreRuntimeSectionTitle;
  String get piCoreRuntimeTitle;
  String piCoreRuntimeStatusLabel(PiCoreRuntimeStatus status);
  String piCoreRuntimeStatusDescription(
    PiCoreRuntimeStatus status,
    PiCoreRuntimeDiagnosticCode diagnosticCode,
  );
  String piCoreRuntimeSourceLabel(PiCoreRuntimeSource? source);
  String get piCoreRuntimeSourceTitle;
  String get piCoreRuntimePathLabel;
  String get piCoreRuntimeVersionLabel;
  String get piCoreRuntimeNotDetectedLabel;
  String get piCoreRuntimeRefreshTooltip;
  String get piCoreRuntimeChooseTooltip;
  String get piCoreRuntimeClearTooltip;
  String get piCoreInstallerTitle;
  String get piCoreInstallerSourceLabel;
  String get piCoreInstallerScriptLabel;
  String get piCoreInstallerLogLabel;
  String get permissionsSectionTitle;
  String get generalSectionTitle;
  String get appearanceTitle;
  String get typographySectionTitle;
  String get layoutSectionTitle;
  String get previewSectionTitle;
  String get themeSectionTitle;
  String get defaultPermissionsTitle;
  String get defaultPermissionsDescription;
  String get autoReviewTitle;
  String get autoReviewDescription;
  String get fullAccessTitle;
  String get fullAccessDescription;
  String get defaultOpenDestinationTitle;
  String get defaultOpenDestinationDescription;
  String get languageTitle;
  String get languageDescription;
  String get showInMenuBarTitle;
  String get showInMenuBarDescription;
  String get showInMenuBarUnsupportedDescription;
  String get bottomPanelTitle;
  String get bottomPanelDescription;
  String get preventSleepTitle;
  String get preventSleepDescription;
  String get suggestedPromptsTitle;
  String get suggestedPromptsDescription;
  String get importWorkTitle;
  String get importWorkDescription;
  String get openSourceLicensesTitle;
  String get openSourceLicensesDescription;
  String get appUpdatesSectionTitle;
  String get appUpdateTitle;
  String get appUpdateIdleDescription;
  String get appUpdateCheckingDescription;
  String appUpdateInstalledVersionDescription(String version);
  String appUpdateCurrentVersionDescription(String version);
  String appUpdateAvailableDescription(
    String currentVersion,
    String latestVersion,
  );
  String appUpdateDownloadingDescription(String progress);
  String appUpdateReadyDescription(String version);
  String appUpdateUnavailableDescription(String reason);
  String appUpdateFailedDescription(String reason);
  String get appUpdateUnsupportedDescription;
  String get checkForUpdatesActionLabel;
  String get downloadUpdateActionLabel;
  String get quitAndInstallActionLabel;
  String get importActionLabel;
  String get viewActionLabel;
  String get themeModeTitle;
  String get themeModeDescription;
  String get interfaceTextSizeTitle;
  String get interfaceTextSizeDescription;
  String get codeFontTitle;
  String get codeFontDescription;
  String get interfaceDensityTitle;
  String get interfaceDensityDescription;
  String get previewSectionDescription;
  String get previewUiLabel;
  String get previewUiHeadline;
  String get previewUiBody;
  String get previewCodeLabel;
  String get previewCodeSnippet;
  String get composerHint;
  String get projectsLabel;
  String get tasksLabel;
  String get personalGroupLabel;
  String get integrationsGroupLabel;
  String get codingGroupLabel;
  String get archivedGroupLabel;
  String get piConfigGroupLabel;
  String get piModelsTitle;
  String get piPromptsTitle;
  String get piConfigLoadingLabel;
  String piConfigLoadFailedBody(String reason);
  String get piConfigRootSectionTitle;
  String get piConfigRootDescription;
  String get piConfigDirectoryTitle;
  String piConfigDirectoryDescription(bool usesEnvironmentOverride);
  String get piConfigSettingsFileLabel;
  String get piConfigModelsFileLabel;
  String get piConfigAuthFileLabel;
  String get piConfigSystemPromptFileLabel;
  String get piConfigAppendSystemFileLabel;
  String get piConfigAgentsFileLabel;
  String piConfigRootSourceLabel(PiConfigRootSource source);
  String get piConfigSavedNotice;
  String piConfigSaveFailedNotice(String reason);
  String get piSaveActionLabel;
  String get piUnsetOptionLabel;
  String get piModelPreferencesSectionTitle;
  String get piDefaultProviderTitle;
  String get piDefaultProviderDescription;
  String get piDefaultModelTitle;
  String get piDefaultModelDescription;
  String get piDefaultThinkingLevelTitle;
  String get piDefaultThinkingLevelDescription;
  String get piEnabledModelsTitle;
  String get piEnabledModelsDescription;
  String get piEnabledModelsHint;
  String get piModelsJsonSectionTitle;
  String get piModelsJsonDescription;
  String piCustomProvidersSummary(int count);
  String piCustomModelsSummary(int count);
  String piAuthProvidersSummary(int count, {required bool fileExists});
  String piJsonParseErrorLabel(String fileName, String reason);
  String get piSystemPromptTitle;
  String get piSystemPromptDescription;
  String get piAppendSystemPromptTitle;
  String get piAppendSystemPromptDescription;
  String get piGlobalAgentsTitle;
  String get piGlobalAgentsDescription;
  String get piPromptEditorHint;

  String settingsCategoryLabel(SettingsCategory category);
  String settingsPlaceholderBody(String categoryLabel);
  String languageLabel(AppLanguage language);
  String themeModeLabel(AppThemeMode mode);
  String openDestinationLabel(AppOpenDestination destination);
  String uiScaleLabel(AppUiScale scale);
  String interfaceDensityLabel(AppInterfaceDensity density);
  String codeFontLabel(AppCodeFont codeFont);
  String thinkingLevelLabel(String level);
}

List<SettingsNavSection> buildSettingsSections(SettingsCopy copy) {
  return [
    SettingsNavSection(
      label: copy.personalGroupLabel,
      items: [
        SettingsNavItem(
          category: SettingsCategory.general,
          label: copy.settingsCategoryLabel(SettingsCategory.general),
          icon: Icons.settings_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.appearance,
          label: copy.settingsCategoryLabel(SettingsCategory.appearance),
          icon: Icons.light_mode_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.voice,
          label: copy.settingsCategoryLabel(SettingsCategory.voice),
          icon: Icons.mic_none_rounded,
        ),
        SettingsNavItem(
          category: SettingsCategory.configuration,
          label: copy.settingsCategoryLabel(SettingsCategory.configuration),
          icon: Icons.tune_rounded,
        ),
        SettingsNavItem(
          category: SettingsCategory.personalization,
          label: copy.settingsCategoryLabel(SettingsCategory.personalization),
          icon: Icons.auto_awesome_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.pets,
          label: copy.settingsCategoryLabel(SettingsCategory.pets),
          icon: Icons.pets_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.keyboardShortcuts,
          label: copy.settingsCategoryLabel(SettingsCategory.keyboardShortcuts),
          icon: Icons.keyboard_command_key_rounded,
        ),
        SettingsNavItem(
          category: SettingsCategory.account,
          label: copy.settingsCategoryLabel(SettingsCategory.account),
          icon: Icons.account_circle_outlined,
          external: true,
        ),
      ],
    ),
    SettingsNavSection(
      label: copy.piConfigGroupLabel,
      items: [
        SettingsNavItem(
          category: SettingsCategory.piModels,
          label: copy.settingsCategoryLabel(SettingsCategory.piModels),
          icon: Icons.smart_toy_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.piPrompts,
          label: copy.settingsCategoryLabel(SettingsCategory.piPrompts),
          icon: Icons.note_alt_outlined,
        ),
      ],
    ),
    SettingsNavSection(
      label: copy.integrationsGroupLabel,
      items: [
        SettingsNavItem(
          category: SettingsCategory.appshots,
          label: copy.settingsCategoryLabel(SettingsCategory.appshots),
          icon: Icons.crop_free_rounded,
        ),
        SettingsNavItem(
          category: SettingsCategory.plugins,
          label: copy.settingsCategoryLabel(SettingsCategory.plugins),
          icon: Icons.extension_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.browser,
          label: copy.settingsCategoryLabel(SettingsCategory.browser),
          icon: Icons.web_asset_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.computerUse,
          label: copy.settingsCategoryLabel(SettingsCategory.computerUse),
          icon: Icons.mouse_outlined,
        ),
      ],
    ),
    SettingsNavSection(
      label: copy.codingGroupLabel,
      items: [
        SettingsNavItem(
          category: SettingsCategory.hooks,
          label: copy.settingsCategoryLabel(SettingsCategory.hooks),
          icon: Icons.anchor_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.connections,
          label: copy.settingsCategoryLabel(SettingsCategory.connections),
          icon: Icons.hub_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.git,
          label: copy.settingsCategoryLabel(SettingsCategory.git),
          icon: Icons.merge_type_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.environments,
          label: copy.settingsCategoryLabel(SettingsCategory.environments),
          icon: Icons.terminal_outlined,
        ),
        SettingsNavItem(
          category: SettingsCategory.worktrees,
          label: copy.settingsCategoryLabel(SettingsCategory.worktrees),
          icon: Icons.account_tree_outlined,
        ),
      ],
    ),
    SettingsNavSection(
      label: copy.archivedGroupLabel,
      items: [
        SettingsNavItem(
          category: SettingsCategory.archivedTasks,
          label: copy.settingsCategoryLabel(SettingsCategory.archivedTasks),
          icon: Icons.archive_outlined,
        ),
      ],
    ),
  ];
}

List<SettingsNavSection> filterSettingsSections(
  List<SettingsNavSection> sections,
  String query,
) {
  if (query.isEmpty) {
    return sections;
  }

  final normalizedQuery = query.toLowerCase();
  final filtered = <SettingsNavSection>[];

  for (final section in sections) {
    final matches = section.items.where((item) {
      return item.label.toLowerCase().contains(normalizedQuery);
    }).toList();

    if (matches.isNotEmpty) {
      filtered.add(SettingsNavSection(label: section.label, items: matches));
    }
  }

  return filtered;
}
