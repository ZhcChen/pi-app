# desktop 通用设置行为桥接计划

- 任务：把 `General` 中已有偏好继续接到真实运行时或工作区行为
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在已经完成设置持久化的基础上，继续减少“只存在于设置页里”的开关：

- 让 `preventSleep` 接到真实运行时能力
- 让 `suggestedPrompts` 真正控制工作区建议卡片显隐
- 让 `showBottomPanel` 真正控制工作区底部状态面板显隐
- 让 `openDestination / defaultPermissions / autoReview / fullAccess` 影响 composer 的当前执行预设展示

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-general-runtime-bridges.md`
- 新增桌面运行时控制抽象
- 调整 `desktop_app.dart` 生命周期与偏好同步
- 调整 `workspace_view.dart` 的工作区行为
- 调整 `settings_view.dart` 测试 key 与设置文案
- 更新 `widget_test.dart`

## 非目标

- 不在这轮补齐 `showInMenuBar` 的系统托盘 / 菜单栏实现
- 不在这轮实现真正的外部编辑器或终端打开动作
- 不引入状态管理框架或大规模重构

## 执行单元

### 单元 1

- 目标：接入运行时控制器
- 涉及文件 / 模块：`main.dart`、`app_runtime.dart`、`desktop_app.dart`、`pubspec.yaml`
- 完成标准：`preventSleep` 能通过运行时控制器同步到平台能力，测试环境可注入内存控制器

### 单元 2

- 目标：把通用设置映射到工作区行为
- 涉及文件 / 模块：`app_copy.dart`、`workspace_view.dart`、`settings_view.dart`、`app_models.dart`
- 完成标准：建议卡片、底部状态面板、composer 执行预设会随设置变更即时更新

### 单元 3

- 目标：回归验证
- 涉及文件 / 模块：`widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test`、`flutter build macos --debug` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：切换 General 相关设置后，工作区与运行时表现同步变化
- 预期证据：工作区建议卡片和底部状态面板可见性可切换，composer 能展示当前执行预设，运行时控制器记录到 `preventSleep` 变化
