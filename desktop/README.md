# desktop

`desktop/` 是当前仓库中的 Flutter 桌面端模块，用来开发基于 `pi.dev` 的 GUI 客户端。

## 当前定位

- 目标平台：`windows`、`macos`、`linux`
- 当前范围：初始化桌面端应用骨架与基础界面壳
- 后续接入：`pi agent` 进程托管、会话列表、日志流、工具调用面板

## 目录说明

- `lib/`：Flutter 应用代码
- `linux/`、`macos/`、`windows/`：各桌面平台 runner
- `test/`：基础 Widget 测试

## 开发约定

- 字体与文字 token：`desktop/lib/src/app_theme.dart`
- 公开偏好模型：`desktop/lib/src/app_preferences.dart`
- 偏好持久化：`desktop/lib/src/app_persistence.dart`
- 运行时桥接：`desktop/lib/src/app_runtime.dart`
- shared desktop primitives：`desktop/lib/src/ui_primitives.dart`
- 设置页基础组件：`desktop/lib/src/settings_components.dart`
- 工作区基础组件：`desktop/lib/src/workspace_components.dart`
- settings 组件说明：`docs/solutions/2026-07-26-desktop-settings-components.md`
- workspace 组件说明：`docs/solutions/2026-07-26-desktop-workspace-components.md`
- shared primitives 说明：`docs/solutions/2026-07-26-desktop-shared-primitives.md`
- import 边界说明：`docs/solutions/2026-07-26-desktop-import-modules.md`

当前 `desktop/lib/` 采用 hybrid 结构：
- `main.dart` 负责启动入口、对外导出公开 core 类型、挂接仍在 `part` 层的 UI library
- `app_preferences.dart`、`app_persistence.dart`、`app_runtime.dart` 这类公开、跨层、低 UI 耦合的 core 模块优先使用 `import/export`
- `settings_view.dart`、`workspace_view.dart`、`app_copy.dart`、`app_theme.dart` 等仍大量共享私有 UI helper 的文件，继续保留在 `part` 层，等后续 feature module 边界更清晰后再迁

设置页新增控件时，优先复用 `_SettingsCard`、`_SettingsRow`、`_SettingsFieldBlock`、`_SettingsDropdown<T>`、`_SettingsSegmentedControl<T>`、`_SettingsSwitch`，不要在页面里重新散写一套样式。

工作区新增卡片、侧栏项、状态胶囊或输入区细节时，优先复用 `_PromptCardTile`、`_Composer`、`_WorkspaceBottomPanel`、`_WorkspaceStatusPill`、`_SidebarActionTile`、`_ProjectTile` 等基础组件，不要直接把实现堆回 `workspace_view.dart`。

当同一种 visual pattern 已经跨 settings / workspace 重复出现时，优先继续上提到 `_DesktopSurface`、`_DesktopFieldSurface`、`_DesktopTextActionButton`、`_DesktopIconActionButton`、`_DesktopSelectionTile`、`_DesktopStatusPill` 这一层 shared primitives，而不是继续在两个组件文件里分别复制实现。

## 常用命令

```bash
cd desktop
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

在 Windows 或 Linux 上运行时，将最后一条命令替换为对应设备，例如 `flutter run -d windows` 或 `flutter run -d linux`。

## 备注

当前模块还没有接入真实的 `pi agent` 运行时；现有界面主要用于承载后续桌面端交互和状态面板。
