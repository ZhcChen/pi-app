# desktop 字体规范化计划

- 任务：规范化 `desktop` 主界面字体层级并接入可商用字体
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在不改动整体布局结构的前提下，把 `desktop` 主界面的字体系统规范化：

- 除左上应用名称外，整体字号略降一档
- 主要正文与导航字重从偏粗收回到更克制的桌面工具风格
- 抽出统一的文字 token，避免后续继续散落手写 `fontSize` / `fontWeight`
- 接入一套可商用、可随应用分发的 UI 字体

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-typography-standardization.md`
- 调整 `desktop/lib/main.dart` 的文字样式体系
- 在 `desktop/pubspec.yaml` 注册自带字体资源
- 引入 `desktop/assets/fonts/Inter/` 字体文件与 `OFL.txt`
- 保持现有测试通过

## 非目标

- 不重做界面布局
- 不修改品牌 logo 造型
- 不引入复杂多字体组合方案

## 执行单元

### 单元 1

- 目标：定义统一字体 token
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 完成标准：主要文本不再依赖散落的样式字面量

### 单元 2

- 目标：收紧字号和字重
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 完成标准：除应用名称外，其余区域视觉更克制

### 单元 3

- 目标：接入可商用字体 `Inter`
- 涉及文件 / 模块：`desktop/pubspec.yaml`、`desktop/assets/fonts/Inter/`
- 完成标准：应用启动后使用本地打包字体，不依赖系统默认字体

### 单元 4

- 目标：回归验证
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test` 通过

### 单元 5

- 目标：继续收紧字号与表单控件尺寸
- 涉及文件 / 模块：`desktop/lib/src/app_theme.dart`、`desktop/lib/src/settings_view.dart`、`desktop/lib/src/workspace_view.dart`
- 完成标准：全局文字层级再收一档，`Switch`、下拉、按钮与状态胶囊尺寸更贴近桌面工具界面

### 单元 6

- 目标：整理设置页基础组件并补充开发文档
- 涉及文件 / 模块：`desktop/lib/src/settings_components.dart`、`desktop/README.md`、`docs/solutions/**`
- 完成标准：设置基础组件从页面实现中分离，并有清晰的组件使用说明

## 验证方式

- 命令：`flutter analyze`、`flutter test`
- 手工检查：确认左侧导航、空态标题、建议卡、输入器文案都比当前略轻、略小、层级更统一
- 预期证据：代码中形成统一文字 token，界面视觉更安静，并显式使用本地 `Inter` 字体资源
