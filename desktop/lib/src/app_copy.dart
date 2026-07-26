// ignore_for_file: annotate_overrides

part of 'desktop_shell.dart';

class _AppCopy implements WorkspaceCopy {
  const _AppCopy(this.language);

  final AppLanguage language;

  bool get isChinese => language == AppLanguage.simplifiedChinese;

  String get searchTooltip => isChinese ? '搜索' : 'Search';
  String get projectsLabel => isChinese ? '项目' : 'Projects';
  String get tasksLabel => isChinese ? '任务' : 'Tasks';
  String get settingsLabel => isChinese ? '设置' : 'Settings';
  String get downloadRuntimeTooltip => isChinese ? '下载运行时' : 'Download runtime';
  String get heroPromptPrefix => isChinese ? '想在 ' : 'What should we build in ';
  String get heroPromptSuffix => isChinese ? ' 中完成什么？' : '?';
  String get localLabel => isChinese ? '本地' : 'Local';
  String get composerHint => isChinese ? '交给 Pi 处理' : 'Do anything';
  String get customLabel => isChinese ? '自定义' : 'Custom';
  String get modelPresetLabel => '5.4 Extra High';
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

  String get defaultPermissionsTitle =>
      isChinese ? '默认权限' : 'Default permissions';
  String get defaultPermissionsDescription => isChinese
      ? 'Pi 可以读取并编辑当前工作区中的文件；如有需要，它会请求额外访问权限。'
      : 'Pi can read and edit files in its workspace. It can ask for additional access when needed.';
  String get autoReviewTitle => isChinese ? '自动审查' : 'Auto-review';
  String get autoReviewDescription => isChinese
      ? 'Pi 可以自动审查请求并评估是否需要更高权限。自动审查可能会出错。'
      : 'Pi can automatically review requests for additional access. Auto-review can make mistakes.';
  String get fullAccessTitle => isChinese ? '完全访问' : 'Full access';
  String get fullAccessDescription => isChinese
      ? 'Pi 可以编辑你电脑上的任意文件，并执行带网络访问的命令。这会显著提高风险。'
      : 'Pi can edit any file on your computer and run commands with network access. This significantly increases risk.';
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
      return isChinese ? '完全访问' : 'Full access';
    }

    if (preferences.defaultPermissions) {
      return isChinese ? '工作区访问' : 'Workspace access';
    }

    return isChinese ? '按需请求' : 'Ask first';
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

  String settingsCategoryLabel(_SettingsCategory category) {
    return switch (category) {
      _SettingsCategory.general => isChinese ? '通用' : 'General',
      _SettingsCategory.appearance => isChinese ? '外观' : 'Appearance',
      _SettingsCategory.voice => isChinese ? '语音' : 'Voice',
      _SettingsCategory.configuration => isChinese ? '配置' : 'Configuration',
      _SettingsCategory.personalization =>
        isChinese ? '个性化' : 'Personalization',
      _SettingsCategory.pets => isChinese ? '宠物' : 'Pets',
      _SettingsCategory.keyboardShortcuts =>
        isChinese ? '键盘快捷键' : 'Keyboard shortcuts',
      _SettingsCategory.account => isChinese ? '账户' : 'Account',
      _SettingsCategory.appshots => isChinese ? '快照' : 'Appshots',
      _SettingsCategory.plugins => isChinese ? '插件' : 'Plugins',
      _SettingsCategory.browser => isChinese ? '浏览器' : 'Browser',
      _SettingsCategory.computerUse => isChinese ? '计算机使用' : 'Computer use',
      _SettingsCategory.hooks => 'Hooks',
      _SettingsCategory.connections => isChinese ? '连接' : 'Connections',
      _SettingsCategory.git => 'Git',
      _SettingsCategory.environments => isChinese ? '环境' : 'Environments',
      _SettingsCategory.worktrees => isChinese ? '工作树' : 'Worktrees',
      _SettingsCategory.archivedTasks => isChinese ? '归档任务' : 'Archived tasks',
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
}
