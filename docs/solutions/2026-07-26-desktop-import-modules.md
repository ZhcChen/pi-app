# desktop import 模块边界

- 主题：`desktop` 从 `part` 结构向 import-based modules 过渡时的边界约定
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-persistence-and-modularization.md`

## 摘要

`desktop` 当前不再只有一条大而共享的 `part` 链，而是拆成四层：

- `main.dart`：启动入口与公共导出
- import/export core 模块：公开、跨层、低 UI 耦合能力
- import/export shared UI foundation：design helpers 与 desktop primitives
- feature / shell library roots：`desktop_shell.dart`、`workspace_feature.dart`、`settings_feature.dart`

其中 `workspace` 与 `settings` 都已经从原先附着在 shell 上的 `part` 文件，收敛成独立 feature root；共享的 design helpers 与 desktop primitives 也已经迁成独立 import 模块。

## 当前结构

- 启动入口与公共导出：`desktop/lib/main.dart`
- app shell orchestration module：`desktop/lib/src/desktop_shell.dart`
- workspace feature root：`desktop/lib/src/workspace_feature.dart`
- settings feature root：`desktop/lib/src/settings_feature.dart`
- 兼容导出 shim：`desktop/lib/src/desktop_app.dart`
- 独立应用级 import 模块：
  - `desktop/lib/src/app_copy.dart`
  - `desktop/lib/src/app_data.dart`
- 独立 import/export core 模块：
  - `desktop/lib/src/app_preferences.dart`
  - `desktop/lib/src/app_persistence.dart`
  - `desktop/lib/src/app_runtime.dart`
- 独立 import/export shared UI foundation：
  - `desktop/lib/src/desktop_design.dart`
  - `desktop/lib/src/desktop_primitives.dart`
- `desktop_shell.dart` 当前不再挂任何 `part` 文件；route 私有模型已经回收到 shell 内部
- 当前挂在 `settings_feature.dart` 下的 feature `part` 文件：
  - `desktop/lib/src/settings_view.dart`
  - `desktop/lib/src/settings_components.dart`
- 当前挂在 `workspace_feature.dart` 下的 feature `part` 文件：
  - `desktop/lib/src/workspace_view.dart`
  - `desktop/lib/src/workspace_components.dart`

## 为什么先迁这些模块

优先迁出的模块有几个共同点：

- 对外可见：测试、应用入口或后续其他模块都可能直接依赖
- 逻辑边界稳定：偏好模型、持久化、运行时桥接本身职责单一
- UI 私有耦合低：不依赖 `_SettingsCategory`、`_AppCopy`、`context.appPalette` 这类同 library 私有 helper

这类文件继续放在 `main.dart` 或分散的全局 `part` 链里，只会让入口文件继续充当过大的共享命名空间。

## 为什么其他 UI 文件暂时不继续拆

以下文件目前仍然共享大量私有实现细节：

- `settings_view.dart` 与 `settings_components.dart` 仍共享 settings feature 内部的私有 helper 和模型别名
- `workspace_view.dart` 与 `workspace_components.dart` 仍共享 workspace feature 内部的私有组件组合细节
- `app_copy.dart` 仍同时实现 `WorkspaceCopy` 与 `SettingsCopy`，属于应用级文案聚合点
- `app_data.dart` 仍保留应用级数据注入职责，例如当前工作区演示数据

在这些边界还没有进一步 feature 化之前，直接把它们全部改成 imports，通常会导致两种坏结果：

- 为了跨文件访问而把大量原本只该局部可见的类型改成 public
- 为了躲开访问限制，反向引入新的“大而泛”的工具文件

这两种结果都比暂时保留 `part` 更差。

## 当前判断规则

一个 `desktop/lib/src/*.dart` 文件满足下面大部分条件时，优先考虑迁成 import/export 模块：

- 主要承载公开类型，而不是页面私有结构
- 不需要访问大量 `_private` UI helper
- 可以单独被测试或在别处直接复用
- 自己的 imports 明确，不必借 `main.dart` 的共享导入才能成立

如果一个文件仍然主要服务于同一块 UI library 内部编排，继续保留在 `part` 层。

## 验证 / 证据

- 命令：`cd desktop && flutter analyze`、`cd desktop && flutter test`、`cd desktop && flutter build macos --debug`
- 代码观察：`main.dart` 已只保留入口与 `export`，共享设计层迁到 `desktop_design.dart` / `desktop_primitives.dart`，工作区与设置页分别改为 `workspace_feature.dart` / `settings_feature.dart`，`app_copy.dart` 与 `app_data.dart` 已脱离 shell `part` 链，`desktop_shell.dart` 本身也已不再依赖 `part`
- 兼容性观察：`package:pi_desktop/main.dart` 仍可被测试直接引用 `PiDesktopApp`、`AppPreferences`、`MemoryDesktopPreferencesStore`、`MemoryDesktopRuntimeController`

## 后续事项

- 后续如继续推进 import-based modularization，优先按 feature 边界迁移，而不是按文件名平铺拆散
- 当前更自然的下一步，不再是继续清理 app shell，而是观察 `settings_feature.dart` / `workspace_feature.dart` 内部的私有共享实现是否已经稳定到值得脱离 `part`；在没有稳定 contract 前，保留 feature 内部 `part` 仍是更克制的选择
