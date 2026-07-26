# desktop shared primitives 约定

- 主题：跨设置页与工作区共享的 desktop primitives
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-shell-refinement.md`

## 摘要

为 `desktop` 沉淀一层更上游的共享 UI primitives，专门承接设置页和工作区都已经重复出现的基础模式，例如 bordered surface、selected tile、status pill、field shell、compact action button。

## 背景

在完成 `settings_components.dart` 和 `workspace_components.dart` 拆分后，仍然能看到两边存在重复模式：

- 带边框和圆角的 surface 容器
- 带选中态背景的 sidebar tile
- icon + label 的紧凑状态胶囊
- 紧凑的二级文字操作按钮 / 图标操作按钮
- field-like shell，例如设置 dropdown、搜索框、代码预览框

如果这些模式继续分别维护，后续再做尺寸或风格调整时，仍然需要在多个组件文件之间来回同步。

## 关键结论

- 跨场景共享 primitives 统一放在 `desktop/lib/src/ui_primitives.dart`
- 当前收口的共享 primitives 包括：
  - `_DesktopSurface`
  - `_DesktopFieldSurface`
  - `_DesktopTextActionButton`
  - `_DesktopIconActionButton`
  - `_DesktopSelectionTile`
  - `_DesktopStatusPill`
- `settings_components.dart` 和 `workspace_components.dart` 负责更靠近业务语义的包装，不直接退化成“所有页面都自己堆 BoxDecoration”
- 新增共享模式时，先判断它是否已经跨 settings / workspace 重复，再决定是否进入 `ui_primitives.dart`

## 可复用建议

- 通用带边框 surface：使用 `_DesktopSurface`
  - 适用于设置卡片、提示卡、底部状态面板、composer 外壳、预览区面板这类中性容器
- 通用 field shell：使用 `_DesktopFieldSurface`
  - 适用于设置 dropdown、搜索框、代码预览框这类浅层输入 / 展示壳
- 通用紧凑文字操作按钮：使用 `_DesktopTextActionButton`
  - 适用于返回应用、打开设置、composer 次级操作这类不需要强调背景的按钮
- 通用紧凑图标操作按钮：使用 `_DesktopIconActionButton`
  - 适用于提交、下载运行时等带背景色的单图标按钮
- 通用选中态 tile：使用 `_DesktopSelectionTile`
  - 适用于设置导航项、工作区侧栏动作项、工作区项目项，以及无点击行为的静态预览选中项
- 通用状态胶囊：使用 `_DesktopStatusPill`
  - 适用于权限、运行状态、偏好摘要等低层级状态展示

## 不建议放进 shared primitives 的内容

- 明显带业务语义的组件，例如 `_Composer`、`_WorkspaceBottomPanel`、`_SettingsRow`
- 只是单次出现、尚未重复的样式模式
- 需要过多参数才能泛化的复杂组合控件

## 验证 / 证据

- 命令：`cd desktop && flutter analyze`、`cd desktop && flutter test`
- 文件：`desktop/lib/src/ui_primitives.dart`、`desktop/lib/src/settings_components.dart`、`desktop/lib/src/settings_view.dart`、`desktop/lib/src/workspace_components.dart`、`desktop/lib/src/workspace_view.dart`
- 输出或观察：settings 与 workspace 的 surface / tile / pill / compact action / field shell 不再各自维护重复实现

## 后续事项

- 保持 `ui_primitives.dart` 小而稳定，避免演化成参数过多的万能组件集合
- `SegmentedButton` 风格与 settings 内的 tonal action button 目前仍只有单场景复用，继续保留在 `settings_components.dart`
- 剩余明显带业务语义的组合，如 `_ProjectItemRow`、`_ProjectTile` 的展开内容、`_SettingsSegmentedControl<T>` 的语义包装，仍应留在场景级组件文件而不是继续上提
