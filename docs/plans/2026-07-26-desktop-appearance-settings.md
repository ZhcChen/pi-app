# desktop 外观设置计划

- 任务：补齐 `desktop` 的 `Appearance` 设置页，并让外观偏好实时生效且持久化
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在已有设置页基础上，把 `Appearance` 从占位分类做成真实可用的一页：

- 提供界面文字大小设置
- 提供界面密度设置
- 提供代码字体设置
- 设置变更实时作用于应用，并持久化到 `~/.pi-app/settings.json`

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-appearance-settings.md`
- 扩展 `desktop/lib/src/app_models.dart` 的偏好模型
- 扩展 `desktop/lib/src/app_persistence.dart` 的设置持久化
- 新增 `Appearance` 页面内容与预览
- 新增 `JetBrains Mono` 代码字体资源与注册
- 更新 `desktop/test/widget_test.dart`

## 非目标

- 不在本轮实现完整明暗主题切换
- 不补齐所有设置项的持久化
- 不引入新的状态管理框架

## 执行单元

### 单元 1

- 目标：扩展偏好模型与持久化
- 涉及文件 / 模块：`desktop/lib/src/app_models.dart`、`desktop/lib/src/app_persistence.dart`
- 完成标准：界面字体大小、密度、代码字体可读写到 `~/.pi-app/settings.json`

### 单元 2

- 目标：完成 `Appearance` 页面 UI
- 涉及文件 / 模块：`desktop/lib/src/settings_view.dart`
- 完成标准：可看到真实控件而非占位内容

### 单元 3

- 目标：把外观偏好接入应用
- 涉及文件 / 模块：`desktop/lib/src/desktop_app.dart`、`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/app_theme.dart`
- 完成标准：修改后主界面与预览区出现即时变化

### 单元 4

- 目标：回归验证
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test`、`flutter build macos --debug` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：外观页可切换字体大小、密度、代码字体，返回主界面后仍能感知变化
- 预期证据：`~/.pi-app/settings.json` 出现对应字段，`Appearance` 页面不再是占位
