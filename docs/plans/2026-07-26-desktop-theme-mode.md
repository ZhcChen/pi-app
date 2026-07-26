# desktop 主题模式计划

- 任务：为 `desktop` 的 `Appearance` 设置页补齐真实可用的主题模式
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在已有外观设置基础上，为应用增加真正可用的主题模式：

- 支持 `深色`、`浅色`、`跟随系统`
- 主题切换后工作区、设置页、侧栏与预览区同时生效
- 主题模式持久化到 `~/.pi-app/settings.json`

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-theme-mode.md`
- 扩展 `desktop/lib/src/app_models.dart` 偏好模型
- 扩展 `desktop/lib/src/app_persistence.dart` 读写主题模式
- 重构 `desktop/lib/src/app_theme.dart` 的颜色与文字主题
- 调整 `workspace_view.dart` 与 `settings_view.dart` 使用动态 palette
- 更新 `desktop/test/widget_test.dart`

## 非目标

- 不在本轮引入品牌级多主题设计系统
- 不处理系统强调色同步
- 不扩展移动端或 Web

## 执行单元

### 单元 1

- 目标：扩展主题模式偏好与持久化
- 涉及文件 / 模块：`app_models.dart`、`app_persistence.dart`
- 完成标准：主题模式可读写并恢复

### 单元 2

- 目标：重构亮暗 palette
- 涉及文件 / 模块：`app_theme.dart`
- 完成标准：`ThemeData` 可根据模式切换深浅主题

### 单元 3

- 目标：接入 `Appearance` 页面与全局生效
- 涉及文件 / 模块：`settings_view.dart`、`workspace_view.dart`、`desktop_app.dart`
- 完成标准：切换后设置页和主界面即时变化

### 单元 4

- 目标：回归验证
- 涉及文件 / 模块：`widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test`、`flutter build macos --debug` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：`Appearance` 页切换主题模式后整个应用同步变化
- 预期证据：`settings.json` 出现 `themeMode` 字段，亮暗主题均可用
