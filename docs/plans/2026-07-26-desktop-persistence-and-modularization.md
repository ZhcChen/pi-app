# desktop 持久化与组件化计划

- 任务：把语言设置持久化到 `~/.pi-app`，并将 `desktop` UI 从 `main.dart` 拆分为多文件模块
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在不改变当前交互行为的前提下完成两项整理：

- 将应用级设置持久化到 `~/.pi-app/settings.json`
- 将 `main.dart` 中的启动、持久化、文案、主题、工作区、设置页按职责拆分

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-persistence-and-modularization.md`
- 重构 `desktop/lib/main.dart`
- 新增 `desktop/lib/src/` 下的模块文件
- 更新 `desktop/test/widget_test.dart`

## 非目标

- 不在本轮做设置持久化的全量覆盖，只先落语言设置
- 不引入状态管理框架
- 不改动现有主界面和设置页的视觉结构

## 执行单元

### 单元 1

- 目标：建立 `~/.pi-app/settings.json` 持久化链路
- 涉及文件 / 模块：`desktop/lib/src/app_persistence.dart`
- 完成标准：语言切换后重启应用仍保持上次选择

### 单元 2

- 目标：拆分 `main.dart`
- 涉及文件 / 模块：`desktop/lib/main.dart`、`desktop/lib/src/*.dart`
- 完成标准：`main.dart` 只保留启动入口和模块装配

### 单元 3

- 目标：保持现有设置页与工作区行为不变
- 涉及文件 / 模块：`desktop/lib/src/desktop_app.dart`、`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/settings_view.dart`
- 完成标准：进入设置页、切换语言、返回主界面仍可用

### 单元 4

- 目标：回归验证
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test`、`flutter build macos --debug` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：切换语言后重新启动应用，设置页与主界面文案仍保持一致
- 预期证据：`~/.pi-app/settings.json` 出现并写入语言字段，`main.dart` 显著收缩
