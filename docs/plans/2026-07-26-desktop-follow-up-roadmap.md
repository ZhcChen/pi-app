# desktop 后续任务收口计划

- 任务：收口 `desktop` 剩余真实系统能力、真实数据接入与 feature 内部边界评估
- 状态：执行中
- 负责人：Pi
- 日期：2026-07-26
- 承接计划：`docs/plans/2026-07-26-desktop-persistence-and-modularization.md`

## 背景

当前 `desktop` 已完成：

- `main.dart` 入口收缩
- `desktop_shell.dart` 纯应用编排化
- `workspace_feature.dart` / `settings_feature.dart` 独立 feature root
- 偏好持久化与部分运行时桥接

但还有几类剩余工作尚未收口：

- 偏好项已存在，但尚未接到真实系统能力
- 工作区首页仍包含 seed data / demo data
- feature root 内部是否继续去 `part` 尚未做最后判断
- 少量兼容壳文件仍保留，用于避免旧路径瞬时失效

## 并行规划

与当前剩余的桌面基础能力收口并行，主功能开发另行规划到：

- `docs/plans/2026-07-26-desktop-main-feature-roadmap.md`

该计划关注 `pi` 主能力接入、host 形态、session/tool/model/auth 主链，而不是继续收口当前 UI/设置基础设施。

## 当前进度

- 已完成：阶段 1 / 单元 1-4
  - 为 `showInMenuBar` 建立 `DesktopRuntimeCapabilities` 能力边界
  - macOS 原生层新增 menu bar status item 与关闭主窗口后保活恢复逻辑
  - Windows / Linux 当前明确降级为不支持，并在设置页禁用对应开关
  - 补齐 runtime sync 与 unsupported 状态的自动化测试
- 已完成：阶段 2 / 单元 5-8
  - 为 workspace 引入显式 `workspaceRootPath -> workspacePath / targetPath` 输入链路
  - `PlatformDesktopRuntimeController` 新增 `openTarget(...)`，打通 VS Code / Cursor / Terminal 的跨平台启动策略
  - 工作区项目与项目项新增真实打开入口，并默认遵循当前 `openDestination`
  - 补齐打开请求、路径透传与失败反馈的自动化测试
- 已完成：阶段 3 / 单元 9-12 第一批
  - `app_data.dart` 不再保留 `yuance` / `novel-1` 之类 seed projects，只基于真实 workspace root 产出项目
  - 工作区右侧从空态标题升级为 `Project overview`，展示真实路径、仓库状态、branch、session cwd 预留位与 recent targets
  - recent targets 与项目根目录继续复用已有外部打开链路
  - 补齐“只显示真实项目”和 overview 的自动化测试
- 已完成：阶段 3 / 单元 9-12 第二批
  - composer 现在显式显示当前选中项目的 `sessionCwd`
  - 提交任务会生成与当前项目绑定的 prepared task 状态，而不是继续停留在纯视觉壳
  - 补齐 `composer -> project.sessionCwd` 的自动化测试
- 待执行：阶段 4-5
  - feature 内部边界复核
  - 兼容层与过渡文件清理

## 目标

在不破坏当前 UI 结构与跨平台可运行性的前提下，完成以下后续收口：

- 将 `showInMenuBar` 接到真实 tray / menu bar 行为
- 将 `openDestination` 接到真实 VS Code / Cursor / Terminal 打开能力
- 将工作区首页的 seed data 逐步替换为真实数据源或明确的空态
- 重新评估 `settings_feature.dart` / `workspace_feature.dart` 内部是否值得继续脱离 `part`
- 清理已退化为兼容层的壳文件与过渡路径

## 范围

这次计划会覆盖：

- `desktop/lib/src/app_runtime.dart`
- `desktop/lib/src/app_preferences.dart`
- `desktop/lib/src/app_data.dart`
- `desktop/lib/src/desktop_shell.dart`
- `desktop/lib/src/workspace_feature.dart`
- `desktop/lib/src/settings_feature.dart`
- `desktop/test/widget_test.dart`
- `desktop/macos/Runner/**`
- `desktop/windows/runner/**`
- `desktop/linux/runner/**`
- `docs/solutions/**`

## 非目标

- 不改动移动端、Web 或非桌面平台
- 不一次性实现所有 settings 分类的真实行为
- 不为了继续模块化而抬升大量原本应私有的类型为 public API
- 不引入新的全局状态管理框架

## 优先级

### P0

- `showInMenuBar` 真实系统桥接
- `openDestination` 真实外部打开桥接
- 相关失败路径与最小验证补齐

### P1

- `app_data.dart` 从 seed data 过渡到真实数据或明确空态
- 首页工作区动作与状态摘要对齐真实能力

### P2

- `settings_feature.dart` / `workspace_feature.dart` 内部是否继续去 `part` 的边界评估
- 兼容 shim 清理与路径收口

## 执行阶段

### 阶段 1：真实系统桥接

#### 单元 1

- 目标：为 `showInMenuBar` 定义跨平台能力边界
- 涉及文件 / 模块：`desktop/lib/src/app_runtime.dart`、平台 runner 文件
- 完成标准：明确 macOS / Windows / Linux 的支持策略、降级策略与能力探测方式

#### 单元 2

- 目标：打通 macOS menu bar / tray 保活行为
- 涉及文件 / 模块：`desktop/lib/src/app_runtime.dart`、`desktop/macos/Runner/**`
- 完成标准：关闭主窗口后，`showInMenuBar = true` 时应用仍可从 menu bar 入口恢复主窗口

#### 单元 3

- 目标：为 Windows / Linux 提供 tray 行为或显式 no-op 降级
- 涉及文件 / 模块：`desktop/lib/src/app_runtime.dart`、`desktop/windows/runner/**`、`desktop/linux/runner/**`
- 完成标准：非 macOS 平台有明确的行为定义，不出现“开关可点但无约定”的灰区

#### 单元 4

- 目标：补齐 `showInMenuBar` 桥接测试
- 涉及文件 / 模块：`desktop/test/widget_test.dart`、必要的 memory/runtime fake
- 完成标准：偏好切换、runtime 同步与 UI 状态之间的最小验证可回归

### 阶段 2：真实外部打开能力

#### 单元 5

- 目标：定义 `openDestination` 所需的真实上下文输入
- 涉及文件 / 模块：`desktop/lib/src/app_preferences.dart`、`desktop/lib/src/app_data.dart`、`desktop/lib/src/desktop_shell.dart`
- 完成标准：明确外部打开所需的工作区路径、目标文件路径与调用入口，不再依赖纯文案摘要

#### 单元 6

- 目标：实现 VS Code / Cursor / Terminal 的跨平台启动策略
- 涉及文件 / 模块：`desktop/lib/src/app_runtime.dart`、平台 runner 或进程启动封装
- 完成标准：三种 `openDestination` 都能基于真实路径执行启动，失败时返回明确错误结果

#### 单元 7

- 目标：把 `General` 中的默认打开方式接入真实行为
- 涉及文件 / 模块：`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/workspace_feature.dart`
- 完成标准：工作区内相关操作默认遵循当前 `openDestination`，而不是只显示摘要文字

#### 单元 8

- 目标：补齐外部打开桥接测试与失败态说明
- 涉及文件 / 模块：`desktop/test/widget_test.dart`、`docs/solutions/**`
- 完成标准：至少覆盖命令选择、路径传递与失败降级，不把真实系统依赖硬塞进 widget test

### 阶段 3：工作区数据真实化

#### 单元 9

- 目标：界定哪些首页内容应来自真实数据，哪些应退回空态
- 涉及文件 / 模块：`desktop/lib/src/app_data.dart`、`desktop/lib/src/workspace_feature.dart`
- 完成标准：`actions / prompt cards / projects / status summary` 各自的来源与暂态策略清楚可执行

#### 单元 10

- 目标：替换 `desktopProjects` 等 seed data
- 涉及文件 / 模块：`desktop/lib/src/app_data.dart`、相关应用级数据提供模块
- 完成标准：工作区项目列表不再硬编码演示仓库名，未接真实数据时展示明确空态

#### 单元 11

- 目标：让首页动作与状态摘要对齐真实可用能力
- 涉及文件 / 模块：`desktop/lib/src/workspace_feature.dart`、`desktop/lib/src/desktop_shell.dart`
- 完成标准：不可执行的动作不再伪装成现成功能；保留项需有真实入口或明确标记

#### 单元 12

- 目标：补齐数据真实化后的回归测试
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 完成标准：空态、真实态、偏好影响态至少各有一条稳定验证

### 阶段 4：feature 内部边界复核

#### 单元 13

- 目标：评估 `settings_feature.dart` 是否值得继续脱离 `part`
- 涉及文件 / 模块：`desktop/lib/src/settings_feature.dart`、`desktop/lib/src/settings_view.dart`、`desktop/lib/src/settings_components.dart`
- 完成标准：只有在 contract 稳定、可减少耦合且不抬升无意义 public API 时才继续拆分

#### 单元 14

- 目标：评估 `workspace_feature.dart` 是否值得继续脱离 `part`
- 涉及文件 / 模块：`desktop/lib/src/workspace_feature.dart`、`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/workspace_components.dart`
- 完成标准：复用收益明确时再拆；否则保留 feature 内部 `part` 结构

### 阶段 5：过渡层清理

#### 单元 15

- 目标：收口兼容 shim 与过渡文件
- 涉及文件 / 模块：`desktop/lib/src/desktop_app.dart`、`desktop/lib/src/app_models.dart`、`desktop/lib/main.dart`
- 完成标准：确认外部引用面后，删除或进一步收缩已经失去实现职责的兼容壳

## 依赖与风险

- `showInMenuBar` 的真实落地依赖平台能力与 Flutter 侧可用插件/原生桥接方案
- `openDestination` 需要真实路径来源；如果工作区上下文仍不完整，必须先补数据输入
- feature 内部去 `part` 只应在边界稳定后进行，否则会把局部私有实现误抬成公开 API
- tray / 外部启动都具有明显平台差异，验证需要区分 widget 层与 runner / runtime 层

## 验证方式

- 命令：`cd desktop && flutter analyze`、`cd desktop && flutter test`、`cd desktop && flutter build macos --debug`
- 手工检查：
  - `showInMenuBar` 开关切换后，主窗口关闭与恢复行为符合平台约定
  - `openDestination` 能按当前偏好打开真实目标
  - 工作区首页不再依赖硬编码演示项目名
- 预期证据：
  - runtime bridge 有最小自动化验证
  - 无真实能力的入口有明确降级策略
  - 文档能说明哪些能力已完成、哪些平台仍保留降级
