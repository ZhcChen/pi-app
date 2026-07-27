// ignore_for_file: annotate_overrides

import 'app_preferences.dart';
import 'pi_config_store.dart';
import 'settings_feature.dart';
import 'workspace_feature.dart';

class AppCopy implements WorkspaceCopy, SettingsCopy {
  const AppCopy(this.language);

  final AppLanguage language;

  bool get isChinese => language == AppLanguage.simplifiedChinese;

  String get searchTooltip => isChinese ? '搜索' : 'Search';
  String get projectsLabel => isChinese ? '项目' : 'Projects';
  String get addProjectTooltip => isChinese ? '添加项目' : 'Add project';
  String get tasksLabel => isChinese ? '任务' : 'Tasks';
  String get settingsLabel => isChinese ? '设置' : 'Settings';
  String get downloadRuntimeTooltip => isChinese ? '下载运行时' : 'Download runtime';
  String get heroPromptPrefix => isChinese ? '想在 ' : 'What should we build in ';
  String get heroPromptSuffix => isChinese ? ' 中完成什么？' : '?';
  String get localLabel => isChinese ? '本地' : 'Local';
  String get composerHint => isChinese ? '交给 Pi 处理' : 'Do anything';
  String get submitTaskTooltip => isChinese ? '提交任务' : 'Submit task';
  String get backToAppLabel => isChinese ? '返回应用' : 'Back to app';
  String get searchSettingsHint => isChinese ? '搜索设置...' : 'Search settings...';
  String get noSettingsFoundLabel =>
      isChinese ? '没有找到匹配的设置项' : 'No settings found';

  String get generalTitle => isChinese ? '通用' : 'General';
  String get permissionsSectionTitle => isChinese ? '权限' : 'Permissions';
  String get generalSectionTitle => isChinese ? '通用' : 'General';
  String get appearanceTitle => isChinese ? '外观' : 'Appearance';
  String get typographySectionTitle => isChinese ? '排版' : 'Typography';
  String get layoutSectionTitle => isChinese ? '布局' : 'Layout';
  String get previewSectionTitle => isChinese ? '预览' : 'Preview';
  String get themeSectionTitle => isChinese ? '主题' : 'Theme';

  String get defaultPermissionsTitle => isChinese ? '读取工具' : 'Read tools';
  String get defaultPermissionsDescription => isChinese
      ? '为新会话启用 read、grep、find 和 ls。它们不提供目录隔离，只应在你信任会话上下文时开启。'
      : 'Enable read, grep, find, and ls for new sessions. They do not provide directory isolation; enable them only for session context you trust.';
  String get autoReviewTitle => isChinese ? '自动审查' : 'Auto-review';
  String get autoReviewDescription => isChinese
      ? '该偏好会保留给后续审批流程；当前 host 尚未实现逐工具权限确认。'
      : 'This preference is reserved for a future approval flow; the current host does not implement per-tool permission confirmation.';
  String get fullAccessTitle => isChinese ? '编码工具' : 'Coding tools';
  String get fullAccessDescription => isChinese
      ? '为新会话启用 bash、edit 和 write。它不是沙箱，只应在你信任当前项目和提示词时开启。'
      : 'Enable bash, edit, and write for new sessions. This is not a sandbox; enable it only for projects and prompts you trust.';
  String get defaultOpenDestinationTitle =>
      isChinese ? '默认打开方式' : 'Default file open destination';
  String get defaultOpenDestinationDescription =>
      isChinese ? '文件和文件夹默认使用什么打开' : 'Where files and folders open by default';
  String get languageTitle => isChinese ? '语言' : 'Language';
  String get languageDescription =>
      isChinese ? '应用界面的显示语言' : 'Language for the app UI';
  String get showInMenuBarTitle => isChinese ? '在菜单栏中显示' : 'Show in menu bar';
  String get showInMenuBarDescription => isChinese
      ? '主窗口关闭后，仍在 macOS 菜单栏中保留 Pi App'
      : 'Keep Pi App in the macOS menu bar when the main window is closed';
  String get showInMenuBarUnsupportedDescription => isChinese
      ? '当前只有 macOS 支持此行为。'
      : 'This behavior is currently supported only on macOS.';
  String get bottomPanelTitle => isChinese ? '底部面板' : 'Bottom panel';
  String get bottomPanelDescription => isChinese
      ? '在 composer 下方显示执行预设和运行状态面板'
      : 'Show an execution preset and runtime status panel below the composer';
  String get preventSleepTitle =>
      isChinese ? '运行任务时阻止休眠' : 'Prevent sleep while running';
  String get preventSleepDescription => isChinese
      ? 'Pi 执行任务期间保持电脑唤醒'
      : 'Keep your computer awake while Pi is running a task';
  String get suggestedPromptsTitle => isChinese ? '建议提示' : 'Suggested prompts';
  String get suggestedPromptsDescription => isChinese
      ? '通过搜索项目文件和已连接应用来推荐下一步'
      : 'Suggest what to do next by searching project files and connected apps';
  String get importWorkTitle =>
      isChinese ? '从其他 AI 应用导入工作' : 'Import work from other AI apps';
  String get importWorkDescription => isChinese
      ? '迁移你的设置、项目和最近对话'
      : 'Bring over your setup, projects, and recent chats';
  String get openSourceLicensesTitle =>
      isChinese ? '开源许可证' : 'Open source licenses';
  String get openSourceLicensesDescription => isChinese
      ? '查看应用内第三方依赖的许可信息'
      : 'Third-party notices for bundled dependencies';
  String get appUpdatesSectionTitle => isChinese ? '应用更新' : 'App updates';
  String get appUpdateTitle => isChinese ? 'Pi App 更新' : 'Pi App update';
  String get appUpdateIdleDescription => isChinese
      ? '检查 GitHub Release 中可用的 Pi App 版本。'
      : 'Check GitHub Releases for an available Pi App version.';
  String get appUpdateCheckingDescription =>
      isChinese ? '正在检查可用更新...' : 'Checking for updates...';
  String appUpdateInstalledVersionDescription(String version) =>
      isChinese ? '已安装版本：$version。' : 'Installed version: $version.';
  String appUpdateCurrentVersionDescription(String version) => isChinese
      ? '当前版本 $version 已是最新版本。'
      : 'Current version $version is up to date.';
  String appUpdateAvailableDescription(
    String currentVersion,
    String latestVersion,
  ) => isChinese
      ? '可从 $currentVersion 更新到 $latestVersion。'
      : 'Update available: $currentVersion to $latestVersion.';
  String appUpdateDownloadingDescription(String progress) =>
      isChinese ? '正在下载更新包：$progress' : 'Downloading update: $progress';
  String appUpdateReadyDescription(String version) => isChinese
      ? '$version 的安装器已打开。退出应用后完成覆盖安装。'
      : 'The $version installer is open. Quit the app to complete replacement.';
  String appUpdateUnavailableDescription(String reason) =>
      isChinese ? '暂时无法使用更新：$reason' : 'Update unavailable: $reason';
  String appUpdateFailedDescription(String reason) =>
      isChinese ? '更新失败：$reason' : 'Update failed: $reason';
  String get appUpdateUnsupportedDescription => isChinese
      ? '仅打包后的 macOS release 支持应用内更新。'
      : 'In-app updates are available only in packaged macOS releases.';
  String get checkForUpdatesActionLabel =>
      isChinese ? '检查更新' : 'Check for updates';
  String get downloadUpdateActionLabel =>
      isChinese ? '下载更新' : 'Download update';
  String get quitAndInstallActionLabel =>
      isChinese ? '退出并安装' : 'Quit and install';
  String get importActionLabel => isChinese ? '导入' : 'Import';
  String get viewActionLabel => isChinese ? '查看' : 'View';

  String get themeModeTitle => isChinese ? '主题模式' : 'Theme mode';
  String get themeModeDescription => isChinese
      ? '在深色、浅色和跟随系统之间切换整个应用的主题。'
      : 'Switch the entire app between dark, light, and system themes.';
  String get interfaceTextSizeTitle =>
      isChinese ? '界面文字大小' : 'Interface text size';
  String get interfaceTextSizeDescription => isChinese
      ? '统一调整导航、设置和工作区文案的整体字号。'
      : 'Scale navigation, settings, and workspace copy throughout the app.';
  String get codeFontTitle => isChinese ? '代码字体' : 'Code font';
  String get codeFontDescription => isChinese
      ? '用于代码预览和偏代码输入区域。'
      : 'Used in code previews and code-oriented input surfaces.';
  String get interfaceDensityTitle => isChinese ? '界面密度' : 'Interface density';
  String get interfaceDensityDescription => isChinese
      ? '控制列表、表单和工具栏的疏密程度。'
      : 'Choose how compact lists, forms, and controls feel.';
  String get previewSectionDescription => isChinese
      ? '预览当前主题、文字大小、界面密度、通用设置和代码字体的组合效果。'
      : 'Preview how theme, text sizing, density, general settings, and code font work together.';
  String get previewUiLabel => isChinese ? '界面预览' : 'UI preview';
  String get previewUiHeadline => isChinese
      ? '导航、设置和提示词需要保持克制且易扫读。'
      : 'Navigation, settings, and prompts should stay calm and readable.';
  String get previewUiBody => isChinese
      ? '这个预览会跟随当前主题、密度和代码字体同步变化。'
      : 'This preview responds to the current theme, density, and code font.';
  String get previewCodeLabel => isChinese ? '代码预览' : 'Code preview';
  String get previewCodeSnippet =>
      'git status\nflutter test\npi task "Review desktop settings UI"';

  String get executionDefaultsTitle =>
      isChinese ? '当前执行预设' : 'Current execution defaults';
  String get noProjectsTitle => isChinese ? '没有可用项目' : 'No projects available';
  String get noProjectsDescription => isChinese
      ? '当前工作区还没有可识别的本地项目路径。'
      : 'No local project path could be resolved for the current workspace.';
  String get projectOverviewTitle => isChinese ? '项目概览' : 'Project overview';
  String get projectDetailsTitle => isChinese ? '项目详情' : 'Project details';
  String get projectRecentTargetsTitle => isChinese ? '最近目标' : 'Recent targets';
  String get projectSuggestionsTitle =>
      isChinese ? '建议提示' : 'Suggested prompts';
  String get sessionConversationTitle => isChinese ? 'Pi 会话' : 'Pi session';
  String get projectPathLabel => isChinese ? '项目路径' : 'Project path';
  String get projectRepositoryLabel => isChinese ? '仓库状态' : 'Repository';
  String get projectBranchLabel => isChinese ? '分支' : 'Branch';
  String get projectSessionCwdLabel => isChinese ? '会话 cwd' : 'Session cwd';
  String get projectLocalFolderLabel => isChinese ? '本地文件夹' : 'Local folder';
  String get projectOpenRootLabel =>
      isChinese ? '打开项目根目录' : 'Open project root';
  String get projectNoRecentTargetsLabel => isChinese
      ? '当前项目还没有可展示的真实入口。'
      : 'This project does not have any concrete targets yet.';
  String get composerNoProjectNotice => isChinese
      ? '当前还没有可用于执行任务的项目上下文。'
      : 'There is no project context available for this task yet.';
  String get composerEmptyTaskNotice =>
      isChinese ? '先输入任务内容。' : 'Enter a task first.';
  String get abortTaskTooltip => isChinese ? '中止任务' : 'Abort task';

  String composerPromptRejectedNotice(String reason) {
    return isChinese
        ? 'Pi 未接受任务：$reason'
        : 'Pi did not accept the task: $reason';
  }

  String hostRunFailedNotice(String reason) {
    return isChinese ? 'Pi 运行失败：$reason' : 'Pi run failed: $reason';
  }

  String sessionStatusLabel(WorkspaceRunStatus status) {
    return switch (status) {
      WorkspaceRunStatus.idle => isChinese ? '会话就绪' : 'Session ready',
      WorkspaceRunStatus.starting => isChinese ? '正在启动 Pi' : 'Starting Pi',
      WorkspaceRunStatus.running => isChinese ? 'Pi 正在执行' : 'Pi is running',
      WorkspaceRunStatus.settled => isChinese ? '任务已完成' : 'Task completed',
      WorkspaceRunStatus.aborted => isChinese ? '任务已中止' : 'Task aborted',
      WorkspaceRunStatus.failed => isChinese ? '任务失败' : 'Task failed',
    };
  }

  String sessionToolStatusLabel(String toolName) {
    return isChinese ? '正在执行 $toolName' : 'Running $toolName';
  }

  String projectAddedNotice(String projectName) {
    return isChinese ? '已添加项目：$projectName' : 'Added project: $projectName';
  }

  String projectAlreadyAddedNotice(String projectName) {
    return isChinese
        ? '项目已存在于列表中：$projectName'
        : 'Project is already in the list: $projectName';
  }

  String projectAddFailedNotice(String reason) {
    return isChinese ? '添加项目失败：$reason' : 'Failed to add project: $reason';
  }

  String get manageProjectTooltip => isChinese ? '管理项目' : 'Manage project';
  String get renameProjectLabel => isChinese ? '重命名项目' : 'Rename project';
  String get renameProjectDialogTitle => isChinese ? '重命名项目' : 'Rename project';
  String get projectNameFieldLabel => isChinese ? '显示名称' : 'Display name';
  String get cancelActionLabel => isChinese ? '取消' : 'Cancel';
  String get saveActionLabel => isChinese ? '保存' : 'Save';
  String get pinProjectLabel => isChinese ? '固定项目' : 'Pin project';
  String get unpinProjectLabel => isChinese ? '取消固定' : 'Unpin project';
  String get removeProjectLabel =>
      isChinese ? '从项目列表移除' : 'Remove from projects';

  String projectRenamedNotice(String projectName) {
    return isChinese ? '已更新项目名称：$projectName' : 'Renamed project: $projectName';
  }

  String projectPinnedNotice(String projectName) {
    return isChinese ? '已固定项目：$projectName' : 'Pinned project: $projectName';
  }

  String projectUnpinnedNotice(String projectName) {
    return isChinese
        ? '已取消固定项目：$projectName'
        : 'Unpinned project: $projectName';
  }

  String projectRemovedNotice(String projectName) {
    return isChinese
        ? '已从项目列表移除：$projectName'
        : 'Removed from projects: $projectName';
  }

  String projectManageFailedNotice(String reason) {
    return isChinese ? '更新项目失败：$reason' : 'Failed to update project: $reason';
  }

  String projectRecentTargetDescription(String relativePath) {
    return relativePath;
  }

  String projectRepositoryStatus(bool isGitRepository) {
    return isGitRepository
        ? (isChinese ? 'Git 仓库' : 'Git repository')
        : projectLocalFolderLabel;
  }

  String get piConfigGroupLabel => 'Pi Config';
  String get piModelsTitle => isChinese ? 'Pi 模型' : 'Pi Models';
  String get piPromptsTitle => isChinese ? 'Pi 提示词' : 'Pi Prompts';
  String get piConfigLoadingLabel =>
      isChinese ? '正在加载 Pi 全局配置...' : 'Loading Pi global config...';
  String piConfigLoadFailedBody(String reason) {
    return isChinese
        ? '无法加载 Pi 全局配置：$reason'
        : 'Could not load Pi global config: $reason';
  }

  String get piConfigRootSectionTitle => isChinese ? '配置根' : 'Config root';
  String get piConfigRootDescription => isChinese
      ? '当前页面直接读取和写入 Pi 的全局配置目录。'
      : 'This page reads and writes Pi\'s global config directory directly.';
  String get piConfigDirectoryTitle => isChinese ? '目录' : 'Directory';
  String piConfigDirectoryDescription(bool usesEnvironmentOverride) {
    return usesEnvironmentOverride
        ? (isChinese
              ? '当前路径来自环境变量 PI_CODING_AGENT_DIR。'
              : 'The current path comes from PI_CODING_AGENT_DIR.')
        : (isChinese
              ? '当前路径使用默认全局目录 ~/.pi/agent。'
              : 'The current path uses the default global directory ~/.pi/agent.');
  }

  String get piConfigSettingsFileLabel => 'settings.json';
  String get piConfigModelsFileLabel => 'models.json';
  String get piConfigAuthFileLabel => 'auth.json';
  String get piConfigSystemPromptFileLabel => 'SYSTEM.md';
  String get piConfigAppendSystemFileLabel => 'APPEND_SYSTEM.md';
  String get piConfigAgentsFileLabel => 'AGENTS.md';
  String piConfigRootSourceLabel(PiConfigRootSource source) {
    return switch (source) {
      PiConfigRootSource.defaultHome => '~/.pi/agent',
      PiConfigRootSource.environmentOverride => 'PI_CODING_AGENT_DIR',
      PiConfigRootSource.injected =>
        isChinese ? '注入配置目录' : 'Injected config root',
    };
  }

  String get piConfigSavedNotice =>
      isChinese ? 'Pi 配置已保存。' : 'Pi config saved.';
  String piConfigSaveFailedNotice(String reason) {
    return isChinese
        ? '保存 Pi 配置失败：$reason'
        : 'Failed to save Pi config: $reason';
  }

  String get piSaveActionLabel => isChinese ? '保存' : 'Save';
  String get piUnsetOptionLabel => isChinese ? '未设置' : 'Not set';
  String get piModelPreferencesSectionTitle =>
      isChinese ? '模型偏好' : 'Model preferences';
  String get piDefaultProviderTitle =>
      isChinese ? '默认 provider' : 'Default provider';
  String get piDefaultProviderDescription => isChinese
      ? '写入 settings.json 的 defaultProvider。留空表示不设置。'
      : 'Writes defaultProvider in settings.json. Leave blank to unset it.';
  String get piDefaultModelTitle => isChinese ? '默认模型' : 'Default model';
  String get piDefaultModelDescription => isChinese
      ? '写入 settings.json 的 defaultModel。留空表示不设置。'
      : 'Writes defaultModel in settings.json. Leave blank to unset it.';
  String get piDefaultThinkingLevelTitle =>
      isChinese ? '默认 thinking level' : 'Default thinking level';
  String get piDefaultThinkingLevelDescription => isChinese
      ? '写入 settings.json 的 defaultThinkingLevel。'
      : 'Writes defaultThinkingLevel in settings.json.';
  String get piEnabledModelsTitle =>
      isChinese ? '启用的模型循环' : 'Enabled model cycling';
  String get piEnabledModelsDescription => isChinese
      ? '写入 settings.json 的 enabledModels。每行一个模式，也支持逗号分隔。'
      : 'Writes enabledModels in settings.json. Use one pattern per line or commas.';
  String get piEnabledModelsHint => 'claude-*\ngpt-4o\ngemini-2*';
  String get piModelsJsonSectionTitle => isChinese
      ? '自定义 provider 与 models.json'
      : 'Custom providers and models.json';
  String get piModelsJsonDescription => isChinese
      ? '高级模型目录，适合自定义 provider、本地模型服务、modelOverrides 和 compat。'
      : 'Advanced model catalog for custom providers, local model servers, modelOverrides, and compat.';
  String piCustomProvidersSummary(int count) {
    return isChinese ? '自定义 providers：$count' : 'Custom providers: $count';
  }

  String piCustomModelsSummary(int count) {
    return isChinese ? '自定义 models：$count' : 'Custom models: $count';
  }

  String piAuthProvidersSummary(int count, {required bool fileExists}) {
    if (!fileExists) {
      return isChinese ? 'auth.json：未找到' : 'auth.json: not found';
    }
    return isChinese ? '认证条目：$count' : 'Auth entries: $count';
  }

  String piJsonParseErrorLabel(String fileName, String reason) {
    return isChinese
        ? '无法解析 $fileName：$reason'
        : 'Could not parse $fileName: $reason';
  }

  String get piSystemPromptTitle => 'SYSTEM.md';
  String get piSystemPromptDescription =>
      isChinese ? '替换 Pi 默认系统提示词。' : 'Replace Pi\'s default system prompt.';
  String get piAppendSystemPromptTitle => 'APPEND_SYSTEM.md';
  String get piAppendSystemPromptDescription => isChinese
      ? '在默认系统提示词后追加全局指令。'
      : 'Append global instructions after the default system prompt.';
  String get piGlobalAgentsTitle => 'AGENTS.md';
  String get piGlobalAgentsDescription => isChinese
      ? '全局普通上下文、工作规则与偏好，会在各项目间共享。'
      : 'Global context, working rules, and preferences shared across projects.';
  String get piPromptEditorHint =>
      isChinese ? '留空并保存可移除该文件。' : 'Leave blank and save to remove this file.';

  String openTargetTooltip(AppOpenDestination destination) {
    final label = openDestinationLabel(destination);
    return isChinese ? '在$label中打开' : 'Open in $label';
  }

  String get openTargetUnavailableLabel => isChinese
      ? '当前项目还没有可打开的本地路径。'
      : 'This project does not have a local path yet.';

  String openFailedMessage(AppOpenDestination destination, String reason) {
    final label = openDestinationLabel(destination);
    return isChinese
        ? '无法在$label中打开：$reason'
        : 'Could not open in $label: $reason';
  }

  String composerExecutionSummary(AppPreferences preferences) {
    return '${openDestinationLabel(preferences.openDestination)} · '
        '${accessModeLabel(preferences)} · '
        '${reviewModeLabel(preferences.autoReview)}';
  }

  String openDestinationSummaryLabel(AppOpenDestination destination) {
    return isChinese
        ? '打开：${openDestinationLabel(destination)}'
        : 'Open: ${openDestinationLabel(destination)}';
  }

  String accessModeLabel(AppPreferences preferences) {
    if (preferences.fullAccess) {
      return isChinese ? '编码工具' : 'Coding tools';
    }

    if (preferences.defaultPermissions) {
      return isChinese ? '只读工具' : 'Read-only tools';
    }

    return isChinese ? '无内置工具' : 'No built-in tools';
  }

  String reviewModeLabel(bool autoReview) {
    return autoReview
        ? (isChinese ? '自动审查' : 'Auto-review')
        : (isChinese ? '手动审查' : 'Manual review');
  }

  String sleepModeLabel(bool preventSleep) {
    return preventSleep
        ? (isChinese ? '保持唤醒' : 'Keep awake')
        : (isChinese ? '允许休眠' : 'Allow sleep');
  }

  String suggestedPromptsModeLabel(bool enabled) {
    return enabled
        ? (isChinese ? '建议提示开启' : 'Suggested prompts on')
        : (isChinese ? '建议提示关闭' : 'Suggested prompts off');
  }

  String get promptExplore =>
      isChinese ? '浏览并\n理解代码' : 'Explore and\nunderstand code';
  String get promptBuild =>
      isChinese ? '构建新功能、\n应用或工具' : 'Build a new feature,\napp, or tool';
  String get promptReview =>
      isChinese ? '审查代码并\n提出修改建议' : 'Review code and\nsuggest changes';
  String get promptFix => isChinese ? '修复问题与故障' : 'Fix issues and failures';

  String get personalGroupLabel => isChinese ? '个人' : 'Personal';
  String get integrationsGroupLabel => isChinese ? '集成' : 'Integrations';
  String get codingGroupLabel => isChinese ? '编码' : 'Coding';
  String get archivedGroupLabel => isChinese ? '归档' : 'Archived';

  String settingsCategoryLabel(SettingsCategory category) {
    return switch (category) {
      SettingsCategory.general => isChinese ? '通用' : 'General',
      SettingsCategory.appearance => isChinese ? '外观' : 'Appearance',
      SettingsCategory.piModels => isChinese ? 'Pi 模型' : 'Pi Models',
      SettingsCategory.piPrompts => isChinese ? 'Pi 提示词' : 'Pi Prompts',
      SettingsCategory.voice => isChinese ? '语音' : 'Voice',
      SettingsCategory.configuration => isChinese ? '配置' : 'Configuration',
      SettingsCategory.personalization => isChinese ? '个性化' : 'Personalization',
      SettingsCategory.pets => isChinese ? '宠物' : 'Pets',
      SettingsCategory.keyboardShortcuts =>
        isChinese ? '键盘快捷键' : 'Keyboard shortcuts',
      SettingsCategory.account => isChinese ? '账户' : 'Account',
      SettingsCategory.appshots => isChinese ? '快照' : 'Appshots',
      SettingsCategory.plugins => isChinese ? '插件' : 'Plugins',
      SettingsCategory.browser => isChinese ? '浏览器' : 'Browser',
      SettingsCategory.computerUse => isChinese ? '计算机使用' : 'Computer use',
      SettingsCategory.hooks => 'Hooks',
      SettingsCategory.connections => isChinese ? '连接' : 'Connections',
      SettingsCategory.git => 'Git',
      SettingsCategory.environments => isChinese ? '环境' : 'Environments',
      SettingsCategory.worktrees => isChinese ? '工作树' : 'Worktrees',
      SettingsCategory.archivedTasks => isChinese ? '归档任务' : 'Archived tasks',
    };
  }

  String settingsPlaceholderBody(String categoryLabel) {
    return isChinese
        ? '$categoryLabel 相关设置会在下一轮继续补齐。'
        : '$categoryLabel preferences will be filled in next.';
  }

  String languageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.english => 'English (United States)',
      AppLanguage.simplifiedChinese => '简体中文',
    };
  }

  String themeModeLabel(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.dark => isChinese ? '深色' : 'Dark',
      AppThemeMode.light => isChinese ? '浅色' : 'Light',
      AppThemeMode.system => isChinese ? '跟随系统' : 'System',
    };
  }

  String openDestinationLabel(AppOpenDestination destination) {
    return switch (destination) {
      AppOpenDestination.vscode => 'VS Code',
      AppOpenDestination.cursor => 'Cursor',
      AppOpenDestination.terminal => isChinese ? '终端' : 'Terminal',
    };
  }

  String uiScaleLabel(AppUiScale scale) {
    return switch (scale) {
      AppUiScale.small => isChinese ? '小' : 'Small',
      AppUiScale.regular => isChinese ? '默认' : 'Default',
      AppUiScale.large => isChinese ? '大' : 'Large',
    };
  }

  String interfaceDensityLabel(AppInterfaceDensity density) {
    return switch (density) {
      AppInterfaceDensity.compact => isChinese ? '紧凑' : 'Compact',
      AppInterfaceDensity.comfortable => isChinese ? '舒适' : 'Comfortable',
    };
  }

  String codeFontLabel(AppCodeFont codeFont) {
    return switch (codeFont) {
      AppCodeFont.jetBrainsMono => 'JetBrains Mono',
      AppCodeFont.systemMono => isChinese ? '系统等宽' : 'System mono',
    };
  }

  String thinkingLevelLabel(String level) {
    return switch (level) {
      'off' => isChinese ? '关闭' : 'Off',
      'minimal' => isChinese ? '极低' : 'Minimal',
      'low' => isChinese ? '低' : 'Low',
      'medium' => isChinese ? '中' : 'Medium',
      'high' => isChinese ? '高' : 'High',
      'xhigh' => isChinese ? '极高' : 'Extra high',
      'max' => isChinese ? '最大' : 'Max',
      _ => level,
    };
  }
}
