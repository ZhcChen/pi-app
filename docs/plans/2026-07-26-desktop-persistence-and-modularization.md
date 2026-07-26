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

### 单元 5

- 目标：将公开偏好模型独立为 import 模块
- 涉及文件 / 模块：`desktop/lib/src/app_preferences.dart`、`desktop/lib/src/app_models.dart`
- 完成标准：`AppPreferences` 与公开枚举不再依赖 `part` 链路，仍可被测试与应用入口复用

### 单元 6

- 目标：将持久化与运行时桥接迁为 import/export 模块
- 涉及文件 / 模块：`desktop/lib/main.dart`、`desktop/lib/src/app_persistence.dart`、`desktop/lib/src/app_runtime.dart`
- 完成标准：`main.dart` 通过 `import/export` 暴露 core 类型，`app_persistence.dart` 与 `app_runtime.dart` 不再使用 `part of`

### 单元 7

- 目标：补充 import-based modularization 边界文档
- 涉及文件 / 模块：`desktop/README.md`、`docs/solutions/**`
- 完成标准：明确记录当前 hybrid 结构，以及哪些模块继续保留在 `part` 层

### 单元 8

- 目标：将剩余 UI `part` 链迁到独立的 shell library root
- 涉及文件 / 模块：`desktop/lib/main.dart`、`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/*.dart`
- 完成标准：`main.dart` 只保留启动入口与导出，UI `part` 文件改为挂接 `desktop_shell.dart`

### 单元 9

- 目标：更新 hybrid modularization 文档
- 涉及文件 / 模块：`desktop/README.md`、`docs/solutions/**`
- 完成标准：文档明确 `main.dart`、`desktop_shell.dart` 与 core import 模块的职责边界

### 单元 10

- 目标：将共享 design helpers 与 desktop primitives 迁为 import 模块
- 涉及文件 / 模块：`desktop/lib/src/desktop_design.dart`、`desktop/lib/src/desktop_primitives.dart`、`desktop/lib/src/desktop_shell.dart`
- 完成标准：主题、排版、density、code font 与 shared primitives 不再依赖 shell `part` 链

### 单元 11

- 目标：将 workspace 收拢为独立 feature root
- 涉及文件 / 模块：`desktop/lib/src/workspace_feature.dart`、`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/workspace_components.dart`、`desktop/lib/src/desktop_app.dart`
- 完成标准：workspace 通过公开 copy contract 与数据模型接收注入，不再挂在 `desktop_shell.dart` 下

### 单元 12

- 目标：更新 workspace feature root 与 hybrid modularization 文档
- 涉及文件 / 模块：`desktop/README.md`、`docs/solutions/**`
- 完成标准：文档明确 `desktop_shell.dart`、`workspace_feature.dart` 与 shared UI foundation 的职责边界

### 单元 13

- 目标：将 settings 收拢为独立 feature root
- 涉及文件 / 模块：`desktop/lib/src/settings_feature.dart`、`desktop/lib/src/settings_view.dart`、`desktop/lib/src/settings_components.dart`、`desktop/lib/src/desktop_app.dart`
- 完成标准：settings 通过公开 copy contract 与导航模型接收注入，不再挂在 `desktop_shell.dart` 下

### 单元 14

- 目标：把 settings 导航模型与分组构建从 shell 中迁出
- 涉及文件 / 模块：`desktop/lib/src/settings_feature.dart`、`desktop/lib/src/app_models.dart`、`desktop/lib/src/app_data.dart`、`desktop/lib/src/app_copy.dart`
- 完成标准：`SettingsCategory`、`SettingsNavSection`、`SettingsNavItem` 与 settings section builders 归 settings feature 所有

### 单元 15

- 目标：更新 settings feature root 与 hybrid modularization 文档
- 涉及文件 / 模块：`desktop/README.md`、`docs/solutions/**`
- 完成标准：文档明确 `desktop_shell.dart`、`settings_feature.dart`、`workspace_feature.dart` 与 shared UI foundation 的职责边界

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：切换语言后重新启动应用，设置页与主界面文案仍保持一致
- 预期证据：`~/.pi-app/settings.json` 出现并写入语言字段，`main.dart` 显著收缩
