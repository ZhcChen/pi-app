# 外置 Pi Core、RPC 与运行时管理执行计划

- 任务：将 Pi App 的生产运行时从内置 SDK host 迁移为已安装官方 Pi core 的 `pi --mode rpc`，并提供 macOS runtime 检测、官方安装与默认编码工具策略
- 状态：进行中（R1、R2、I1、P1、ACC-0 已完成；I2 为下一功能实现单元）
- 负责人：Pi
- 日期：2026-07-27
- 上层总看板：`docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
- 计划入口与状态约定：`docs/plans/README.md`
- 执行门：`docs/plans/2026-07-28-current-baseline-acceptance-plan.md` 的 ACC-0 与 P1 已完成；I2 可继续，但 `ACC-A1` 若确认冷启动 runtime 为 S1，仍会重新阻断 I2 / C1 新实现。该验收覆盖层不改变 P1、I2、C1 的功能依赖。
- 依赖文档：
  - `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`
  - `docs/plans/2026-07-26-desktop-main-feature-roadmap.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`（完整产品上层路线图）
  - `docs/solutions/2026-07-27-pi-host-sdk-contract.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`（R1 真实 Pi RPC 证据）
  - `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`（R2 adapter 与真实 smoke 证据）
  - `docs/solutions/2026-07-28-pi-core-runtime-detector.md`（I1 检测与诊断证据）

## 目标

完成后，Pi App 不再把 Node runtime 或 `@earendil-works/pi-coding-agent` 放入产品 bundle。macOS 用户可在设置中检测已安装的官方 Pi core；缺失、路径不可用或受限 RPC health 失败时，可下载并在可见 Terminal 中执行官方 `https://pi.dev/install.sh`，然后由应用重新检测并建立 Pi RPC 会话。

Pi App 通过 `pi --mode rpc` 驱动 workspace，不把原始 RPC schema 暴露给 view model。新安装默认请求完整 builtin tool 集；旧的无工具或受限偏好、以及 runtime 确认的工具不可用状态，会在会话前弹出授权 / 修复对话。`pi-light-ce` 只作为设置中的可选 workflow profile，不是 Pi core 的安装来源。

## 范围

- `desktop/` 的 Pi runtime 检测、设置页、官方安装启动、运行状态、日志定位与恢复提示。
- Flutter -> Pi CLI RPC JSONL transport、事件规约和 workspace 接线。
- 现有工具偏好从默认无工具迁移为默认完整 builtin tool 集，并提供旧状态授权对话。
- `pi-light-ce` 的可选检测 / 安装入口，不自动初始化任何项目。
- Pi CLI `0.82.0` 的兼容性 spike、版本记录、自动化与手工回归；该实证基线不构成 runtime 启动限制。

## 非目标

- 不将 Node、Pi SDK、`host/dist` 或 `node_modules` 打进应用 bundle。
- 不安装 `pi-app-host` companion，也不把旧 SDK host 作为未定义的生产 fallback。
- 不在首版实现 OS sandbox、路径 sandbox、逐工具审批或自动 project trust。
- 不在安装 Pi core 时执行 `pi-l-ce init`、修改 `AGENTS.md`、`.pi/prompts/` 或项目文档。
- 不在本计划中完成 Windows / Linux 的安装交付；先完成 macOS。
- 不自动更新 Pi core 或 `pi-light-ce`。

## 影响区域

- 文件：
  - `desktop/lib/src/pi_host_client.dart` 或其替代的通用 runtime client abstraction
  - 新增 Pi RPC transport / adapter、runtime detector、installer launcher 和测试 fake
  - `desktop/lib/src/desktop_shell.dart`、`workspace_feature.dart`
  - `desktop/lib/src/app_preferences.dart`、`app_persistence.dart`
  - `desktop/lib/src/settings_feature.dart`、`settings_view.dart`、`app_copy.dart`
  - `desktop/test/widget_test.dart` 与新增 transport / runtime 测试
  - `docs/solutions/2026-07-27-pi-host-sdk-contract.md`
- 模块：Pi core 发现、JSONL transport、session lifecycle、工具策略、设置页 runtime surface。
- 接口 / 约束：
  - 生产端只启动已安装的 `pi --mode rpc`。
  - RPC 仍严格按 LF JSONL 分帧，单条记录保留 1 MiB 防护。
  - workspace 继续消费稳定产品事件，不直接依赖 Pi RPC 原始 event。
  - Pi CLI `0.82.0` 是当前实测证据基线；后续版本应补回归证据，但 runtime 不得以版本号拒绝启动。
  - builtin tools 默认启用不表示 project trust、sandbox 或 OS 级权限。

## 实现思路

1. 先用独立 spike 验证 Pi RPC 能覆盖当前 UI 所需的 session、stream、abort、model、thinking 和工具 lifecycle，不先改 workspace。
2. 以通用 runtime client 边界替代 `PiHostClient` 的生产绑定：`PiCoreRpcClient` 在 Dart 内完成 Pi RPC 到稳定产品事件的映射；旧 SDK host 仅保留为显式开发回归参考，不是 production fallback。
3. 新增 `PiCoreRuntimeController`，从用户显式选择路径和 `PATH` 检测 `pi`，尽力采集 `pi --version` 信息并运行受限 RPC state handshake；可用性只由 health 决定，不读取 auth 内容、不加载项目资源。
4. macOS 安装由设置页下载官方 script 到临时文件并显示真实 HTTP 下载进度，然后在用户可见 Terminal 执行。官方 installer 需要 TTY 才能在缺少 Node 时完成交互式安装，Pi App 只能显示确定阶段并轮询 health，不能伪造包管理器百分比。
5. 新 session 默认以完整 builtin tool allowlist 启动。R1 必须先验证显式 `--no-approve` 能阻止 project-local executable resources 的自动加载；只有该验证通过，R2 / P1 才能将“完整工具 + 未信任项目”作为生产默认。旧受限偏好和 runtime diagnostic 触发授权 / 修复 modal。

## 阶段拆分

### 阶段 1：R1 Pi RPC 兼容性 Spike

- 目标：验证 Pi CLI `0.82.0` 的 RPC protocol 能替代当前 SDK host 所需的最小产品能力。
- 边界：不更改 workspace 默认运行时，不做安装 UI。
- 验收重点：记录 request / response / event 对照表，证明 state、prompt、text / thinking delta、`agent_settled`、abort、model、thinking、session 文件、工具 lifecycle 和本地 extension prompt 的行为；另以含 project-local resource 的 fixture 验证显式 `--no-approve` 与完整 builtin tool allowlist 的组合。

### 阶段 2：R2 RPC Adapter 与运行时迁移

- 目标：实现 direct Pi RPC client，并将 composer 和 workspace 接到稳定产品事件。
- 边界：只完成当前 host 已有的功能面；session list / fork / 完整 timeline 不在本阶段扩展。
- 验收重点：同一项目 session 能 stream、abort、重启恢复；多项目 / 多 session 的 process ownership 与迟到 event 不串流。仅在 R1 验证 `--no-approve` 基线后才切换 production default。

### 阶段 3：I1 Pi Core Runtime 检测

- 目标：在设置中提供 Pi core 状态、路径、报告版本和诊断入口。
- 边界：不读取或编辑 auth，不自动安装，不加载项目资源。
- 验收重点：未安装、路径不可用、版本信息缺失但 health 通过、RPC health 失败和运行正常可区分且有可操作信息；版本号不得作为启动限制。

### 阶段 4：I2 官方 Pi 安装流程

- 目标：macOS 下从设置页触发官方 Pi core 安装，并准确反映下载与安装状态。
- 边界：只使用官方 `https://pi.dev/install.sh`；不把 `pi-light-ce` 加入 core 流程；不伪造第三方包管理器进度。
- 验收重点：脚本下载字节进度、用户可见 Terminal、安装后检测、失败日志、停止等待和重新检测均可用。

### 阶段 5：P1 默认编码工具与授权迁移

- 目标：新 session 默认启用完整 builtin tool 集，并安全迁移旧无工具设置。
- 边界：不宣称 sandbox 或逐工具 approval；project trust 仍单独处理。
- 验收重点：新偏好直接启用工具；旧受限状态或 runtime diagnostic 弹出授权 / 修复对话；用户拒绝后不会偷偷扩大权限。

### 阶段 6：W1 可选 `pi-light-ce` Workflow Profile

- 目标：在设置中提供独立、可选的 `pi-light-ce` 检测和安装入口。
- 边界：只安装 workflow profile；不自动执行 `init`，不把它显示为 Pi core。
- 验收重点：用户能看见来源、版本、脚本影响和安装状态；项目初始化必须另行确认路径与写入文件。

### 阶段 7：S1 Direct RPC Trust 行为验证

- 目标：确认 direct RPC 的 project trust 后续交互边界，并在已验证的 `--no-approve` 默认基础上设计 trust UI。
- 边界：不再作为完整 builtin tool 默认的前置条件；先出 UI 所需证据和限制。
- 验收重点：明确用户显式 trust 后哪些 project resources 可以加载、撤销 trust 后如何恢复，以及结论写入 solution 文档。

## 执行单元

### R1：RPC Capability Matrix

- 所属阶段：阶段 1。
- 状态：已完成；证据见 `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`。
- 目标：写一个独立 RPC harness / fixture，针对 Pi CLI `0.82.0` 逐项验证当前 host product contract 的等价能力。
- 涉及文件 / 模块：新增 RPC fixture、测试、`docs/solutions/2026-07-27-pi-host-sdk-contract.md`。
- 前置依赖：本机官方 Pi core、可用的无副作用模型认证用于真实 prompt 验证。
- 验证方式：严格 JSONL fixture、`pi --mode rpc` state / abort / model / thinking / prompt smoke test、extension 本地处理测试，以及含 project-local extension / prompt / skill 的 `--no-approve` fixture。
- 完成标准：有明确 event mapping、版本范围、未覆盖能力清单和未信任项目基线；没有 UI 默认切换。

### R2：PiCoreRpcClient

- 所属阶段：阶段 2。
- 状态：已完成；证据见 `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`。
- 目标：实现 session process lifecycle、请求关联、LF framing、1 MiB 限制、event mapping、崩溃恢复和 Memory fake。
- 涉及文件 / 模块：runtime client abstraction、RPC client、desktop shell、workspace feature、测试。
- 前置依赖：R1 矩阵和 `--no-approve` 未信任项目基线通过。
- 验证方式：Dart 单元 / widget tests、真实 Pi session 的 state / model / thinking / prompt / stream / abort、跨 session process exit 隔离回归。
- 完成结果：生产默认 transport 已为 direct RPC；每 session 独占 process；LF、CRLF 兼容、1 MiB、malformed JSON、request correlation、extension 本地完成、dialog 降级和 process exit 均有回归；旧 host 无静默 fallback，产品接口不暴露 raw `bash` / `abort_bash`。

### I1：Pi Core Detector

- 所属阶段：阶段 3。
- 状态：已完成；证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。
- 目标：实现 `PiCoreRuntimeController` 和设置页 runtime card。
- 涉及文件 / 模块：app preferences / persistence、settings feature / view、process abstraction、测试 fake。
- 前置依赖：R1 的 RPC health contract。
- 验证方式：模拟 `pi` 缺失、路径错误、不可执行、新版 / 预发布 / 扩展版本、版本信息缺失、RPC handshake 失败和健康 Pi；widget 状态测试；`dart run tool/verify_pi_core_runtime.dart --pi /opt/homebrew/bin/pi`。
- 完成结果：以 `PI_CORE_EXECUTABLE`、用户已选路径和 `PATH` 发现 Pi，尽力展示其报告版本；以临时空目录运行 `--no-approve --no-tools` 的 `get_state` health 决定可用性，不以版本号拒绝启动；状态卡支持刷新、选择和清除路径，新 session 经 runtime gate 启动。

### I2：官方 Installer Launcher

- 所属阶段：阶段 4。
- 状态：可开始；I1 与 P1 已完成。
- 目标：下载官方 script、显示下载状态、创建本地日志、在 macOS Terminal 启动并轮询安装结果。
- 涉及文件 / 模块：runtime controller、macOS platform bridge、settings view、HTTP / process fake、测试。
- 前置依赖：I1、P1。
- 验证方式：本地 HTTP fixture 的字节下载进度、Terminal launch command 生成、取消等待、安装后 detector 重试、真实干净环境手工 smoke test。
- 完成标准：Pi App 不执行 `curl | sh`；官方 script 始终在可见 Terminal 中运行；无 Node 环境的交互式安装可继续；应用显示下载来源和脚本路径，但不把本地下载表述为内容完整性校验，也不显示伪百分比。

### P1：完整工具默认与迁移授权

- 所属阶段：阶段 5。
- 状态：已完成；证据见 `docs/solutions/2026-07-29-p1-tool-policy-upgrade-and-runtime-repair.md`。
- 目标：完成旧受限策略和 runtime diagnostic 的授权 / 修复交互，保留新 session 的完整 builtin tool 默认与现有安全迁移行为。
- 涉及文件 / 模块：`app_preferences.dart`、`app_persistence.dart`、desktop shell、settings copy / view、RPC launch arguments、测试。
- 前置依赖：R2，以及 R1 的 `--no-approve` trust baseline；剩余 runtime diagnostic 修复路径依赖 I1。
- 验证方式：新安装、旧 `toolPolicyVersion: 1`、用户拒绝、用户授权、Pi runtime diagnostic 的 widget / client 回归。
- 完成标准：默认参数包含 `read,grep,find,ls,bash,edit,write`；用户拒绝时不扩大权限；所有 UI 明确说明这不是 sandbox。

### W1：`pi-light-ce` 可选入口

- 所属阶段：阶段 6。
- 目标：将 workflow profile 与 Pi core card 分离，提供独立检测、安装和项目初始化入口设计。
- 涉及文件 / 模块：settings feature / view、runtime controller 或独立 profile service、文档、测试。
- 前置依赖：I1；Pi core 已健康。
- 验证方式：profile 缺失 / 已安装 / 安装失败状态测试；确认 `init` 不能在没有目标项目确认时运行。
- 完成标准：用户只会把它理解为可选 workflow；Pi core 不依赖它；执行可变远端脚本前必须由用户明确确认来源与风险，UI 不把显示版本或 URL 表述为内容校验。

### S1：Trust Behavior Spike

- 所属阶段：阶段 7。
- 目标：基于 R1 已验证的未信任基线，研究用户显式 project trust 后的 resources 加载与撤销行为，为 trust UI 建立证据。
- 涉及文件 / 模块：临时 fixture 项目、RPC harness、solution 文档。
- 前置依赖：R2、P1，以及 R1 的 `--no-approve` 基线。
- 验证方式：含 project-local extension / prompt / skill 的 fixture、显式 trust / 撤销 trust、工具调用、abort、重启回归。
- 完成标准：明确哪些 project resources 会在显式 trust 后加载、撤销后如何失效；据此创建 project trust UI 的后续计划。

## 当前执行顺序

I1 与 P1 已完成。当前子计划的执行顺序服从总看板：`I2 -> C1`。I2 复用 detector 完成安装后的重新检测；C1 由总看板在 I2 之后安排，不在本文件重复维护。`ACC-A` / `ACC-A1` 继续作为验收覆盖层，其中 `ACC-A1` 若确认冷启动 runtime 为 S1，仍会重新阻断后续 I2 / C1 新实现。

## `/goal` 建议作用域

1. `/goal I2`：仅官方 installer launcher 与 macOS smoke test。
2. `/goal W1`：仅可选 workflow profile 入口。
3. `/goal S1`：仅显式 project trust 行为与 UI 前置证据；不重复验证 R1 的默认未信任基线。

不应把整个迁移作为单个 `/goal`。

## 验证方式

- 命令：`cd desktop && flutter analyze`。
- 命令：`cd desktop && flutter test`。
- 命令：`cd desktop && flutter build macos --debug`。
- 命令：`cd desktop && dart run tool/verify_pi_core_runtime.dart --pi /absolute/path/to/pi`。
- 命令：对已安装官方 Pi 执行 `pi --version`，并通过 `pi --mode rpc` 完成受限 state handshake。
- 手工检查：无 Node / 无 Pi 的 macOS 环境中，设置页下载官方 script、在 Terminal 完成官方安装、Pi App 自动重新检测并创建 session。
- 手工检查：首次新偏好启动时默认完整工具可用；旧无工具偏好先出现授权对话；R1 已验证的 `--no-approve` 参数下，项目未信任时 project-local executable resources 不自动执行。

## 风险 / 待验证问题

- 官方 installer 在无 Node 场景要求 TTY；应用需要用可见 Terminal 运行，不能保证所有安装步骤都可从 Flutter 获得精确进度。本地下载脚本便于展示来源和进度，但不构成独立内容完整性校验，首版信任根是用户确认的官方 HTTPS 来源。
- Pi RPC schema 或语义随上游版本变化时，必须由 R1 证据和真实 smoke 驱动 adapter 维护；Pi App 记录观察到的版本并建议重跑验证，但不把版本号作为启动 gate。
- 默认启用 `bash`、`edit`、`write` 是用户确定的产品策略，但它们不提供路径隔离、网络隔离或 OS 权限限制。
- 系统 PATH 在 Terminal 安装后可能尚未反映到 Pi App 进程；detector 需要支持用户选择可执行路径并重新扫描。
- `pi-light-ce` 当前 installer 的脚本来源和更新语义独立于 Pi core；其安装不能影响 Pi core 更新或项目 trust，且用户显式执行可变脚本的风险必须在 UI 中披露。

## 沉淀跟进

- R1 和 S1 的 protocol / trust 结论更新到 `docs/solutions/2026-07-27-pi-host-sdk-contract.md` 或创建新的 RPC integration solution。
- 每个完成单元更新能力版本矩阵，记录 Pi core 版本、RPC adapter 版本、引入 commit、验证命令和已知限制。
