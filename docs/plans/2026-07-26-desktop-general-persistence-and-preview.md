# desktop 通用设置持久化与外观预览计划

- 任务：把 `General` 页设置并入 `~/.pi-app/settings.json`，并升级 `Appearance` 预览
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在现有主题模式与外观设置基础上继续整理两件事：

- 让 `General` 页中的真实设置与外观偏好走同一条持久化链路
- 将 `Appearance` 页预览从说明型文本升级为更接近真实应用界面的组合预览

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-general-persistence-and-preview.md`
- 扩展 `AppPreferences` 模型
- 扩展 `app_persistence.dart` 读写通用设置
- 调整 `desktop_app.dart` 与 `settings_view.dart`
- 更新 `widget_test.dart`

## 非目标

- 不接入系统级权限或菜单栏的真实系统桥接
- 不补齐所有设置项的后端实现
- 不重做主界面布局

## 执行单元

### 单元 1

- 目标：General 设置并入偏好模型
- 涉及文件 / 模块：`app_models.dart`、`app_persistence.dart`、`desktop_app.dart`
- 完成标准：相关值不再只存在于 `State` 内存里

### 单元 2

- 目标：升级 Appearance 预览
- 涉及文件 / 模块：`settings_view.dart`
- 完成标准：预览更接近真实应用结构，并跟随当前主题/密度/代码字体变化

### 单元 3

- 目标：回归验证
- 涉及文件 / 模块：`widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test`、`flutter build macos --debug` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：General 设置修改后重启仍保留；Appearance 预览能明显看出样式变化
- 预期证据：`settings.json` 包含通用设置字段，外观页预览不再只是说明文字
