# desktop 设置基础组件约定

- 主题：桌面设置页基础组件与尺寸规范
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-typography-standardization.md`

## 摘要

为 `desktop` 设置页沉淀一组稳定的基础组件和统一尺寸约定，避免后续继续在页面里散写按钮、下拉、分段控件和 `Switch` 的样式。

## 背景

这轮迭代里，设置页出现了两个典型问题：

- 字号和控件尺寸整体偏大，不够像桌面工具界面
- 基础控件虽然已经抽成私有类，但仍混在 `desktop/lib/src/settings_view.dart` 页面实现里，开发时不方便查找和复用

因此将设置基础组件统一收拢到独立文件，并补一份开发侧可直接参考的说明。

## 关键结论

- 设置页基础组件统一放在 `desktop/lib/src/settings_components.dart`
- 字体 token 统一放在 `desktop/lib/src/app_theme.dart` 的 `_AppTypography`
- 桌面设置页的主要控件高度默认收敛到 `34px` 左右
- `Switch` 不直接裸用 Material 默认尺寸，而通过 `_SettingsSwitch` 做桌面化缩放包装
- 新增设置项时，优先复用 `_SettingsRow` / `_SettingsFieldBlock` / `_SettingsDropdown<T>` / `_SettingsSegmentedControl<T>`，不要在页面里重新手写一套样式

## 可复用建议

- 页面分组容器：使用 `_SettingsCard`
  - 适合承载一组相关设置项或占位面板
- 行式设置：使用 `_SettingsRow`
  - 左侧标题和说明，右侧单个 trailing 控件
- 块式设置：使用 `_SettingsFieldBlock`
  - 适合 `Appearance` 这类说明在上、控件在下的结构
- 二元开关：使用 `_SettingsSwitch`
  - 不要直接写 `Switch(...)`
- 枚举选择：使用 `_SettingsDropdown<T>` 或 `_SettingsSegmentedControl<T>`
  - 少量固定项优先分段控件，选项更长或更灵活时用下拉
- 次级动作：使用 `_SettingsActionButton`
  - 用于 `Import`、`View` 这类非主操作按钮
- 左侧导航项：使用 `_SettingsCategoryTile`
  - 设置页左栏的交互、选中态和高度统一走这里

## 验证 / 证据

- 命令：`cd desktop && flutter analyze`、`cd desktop && flutter test`
- 文件：`desktop/lib/src/settings_components.dart`、`desktop/lib/src/app_theme.dart`、`desktop/lib/src/settings_view.dart`
- 输出或观察：设置页基础控件从页面实现中拆出；字号、下拉、按钮、分段控件和 `Switch` 尺寸统一收紧

## 后续事项

- 如工作区和设置页继续积累更多通用桌面控件，可再抽出 `desktop/lib/src/ui_primitives.dart`
- 若后续引入更多表单页，可考虑为组件补示例截图或 widgetbook / story 风格预览
