# Pi App 完整功能主路线图

- 任务：将 Pi App 从“具备历史 SDK host 回归链路的桌面工作台”建设为可日常使用的官方 Pi core 桌面 coding client
- 状态：进行中（R1、R2、I1 已完成；P1 为当前下一单元）
- 负责人：Pi
- 日期：2026-07-27
- 当前版本基线：`0.1.0+1`
- 当前执行入口：`docs/plans/README.md`；当前下一执行单元是 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md` 的 P1
- 关联文档：
  - `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`
  - `docs/plans/README.md`（计划入口、状态约定与当前执行队列）
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-27-macos-ad-hoc-release-and-update.md`
  - `docs/solutions/2026-07-27-pi-host-sdk-contract.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`
  - `docs/solutions/2026-07-28-pi-core-runtime-detector.md`
  - `docs/plans/2026-07-26-desktop-main-feature-roadmap.md`（已废弃的历史基线）

## 产品完成定义

本路线图中的“完整功能”不等于在 Flutter 中复刻 Pi CLI 的全部 TUI，也不等于重新分发另一份 Pi runtime。首个完整产品状态是：macOS 用户在已安装或由应用协助安装的官方 Pi core 上，能够安全、可观察、可恢复地完成项目级日常 coding workflow。

完成时必须同时满足：

1. Pi App 不携带 Node、`@earendil-works/pi-coding-agent`、`host/dist` 或 `pi-app-host` companion；生产 agent runtime 仅是用户安装的官方 `pi`。
2. 用户可检测、安装、诊断官方 Pi core，并通过 `pi --mode rpc` 建立 session、发送 prompt、接收流、abort、steer、切换 model / thinking。
3. 用户可管理项目和 session：新建、恢复、fork、切换、归档，并能在应用重启、Pi 进程退出或模型运行失败后得到可操作恢复路径。
4. 用户可看见受大小限制且不泄露敏感信息的工具 timeline、文件变更摘要、失败原因和运行状态；agent 不再是黑盒。
5. 默认 builtin coding tools、旧偏好迁移、项目 trust 与可执行项目资源之间的边界清晰且可验证；不把工具 allowlist 错称为 OS sandbox 或逐工具审批。
6. 主要 Pi 配置、模型、thinking、认证状态、prompts / skills / commands 和可选 workflow profile 有可理解的桌面入口；复杂 extension UI 至少能明确降级和诊断。
7. macOS 有可重复构建、ad-hoc 签名、GitHub Release、手动 DMG 更新和故障恢复证据。Windows、Linux 在 macOS 验收后以相同 runtime contract 扩展。

## 当前基线

| 区域 | 当前状态 | 在本路线图中的定位 |
| --- | --- | --- |
| Desktop shell、项目 registry、偏好、Config Center 第一批 | 已完成 | 继续复用，不重做视觉壳 |
| `Flutter -> LocalPiHostClient -> Node host -> Pi SDK` | 已完成 | 历史回归基线，不得作为新生产 fallback |
| 真实 prompt / 文本流 / abort / model / thinking 基线 | 已完成 | R1 / R2 的对照证据 |
| 受限工具白名单和旧偏好安全降级 | 已完成 | P1 的迁移起点，不是最终默认策略 |
| macOS ad-hoc DMG、GitHub Release workflow、手动更新 | 已完成 | 交付基础，仍需首个真实 tag 验证 |
| `PiCoreRpcClient`、runtime detector、官方 installer | R2、I1 已完成；I2 未完成 | direct production transport 已切换，已具备受管理 runtime 诊断 |
| session 管理、完整 timeline、auth / trust / resource UI | 未完成 | 阶段 P3/P4 功能面 |
| Windows、Linux production runtime / installer | 未开始 | 阶段 P5，必须后置到 macOS 验收 |

## 架构不变量

以下约束适用于所有阶段，后续需求不得绕过：

1. **唯一 runtime**：生产环境只启动用户安装的 `pi --mode rpc`；不把旧 Node host 作为静默 fallback，也不向 bundle 引入第二份 Pi SDK。
2. **稳定产品适配层**：Dart RPC transport / adapter 负责将 Pi RPC 映射为稳定 product view model；workspace、settings 和 widgets 不直接消费 Pi 原始 RPC schema。
3. **本地协议边界**：所有本地进程通信使用严格 LF JSONL，单条记录最多 1 MiB；普通日志不得写入协议 stdout；大输出通过截断摘要或本地 artifact 路径处理。
4. **工具与 trust 分离**：builtin tool allowlist 不是项目 trust、OS sandbox、路径 sandbox、网络隔离或逐工具审批。项目级 `.pi` 可执行资源只能在已验证的 trust contract 下加载。
5. **安全迁移**：旧 `toolPolicyVersion`、用户关闭工具或 runtime diagnostic 失能时，不能静默扩大权限；必须给出授权、保持受限或取消的明确选择。
6. **macOS 先行**：先证明 macOS direct RPC、检测、安装和工作流闭环，再设计 Windows / Linux 的进程与安装实现。
7. **版本可追溯**：每项 runtime capability 记录 Pi App build、Pi core 报告版本与验证证据、RPC adapter version、引入 commit、验证命令和残余风险。release tag 必须等于 `v<desktop/pubspec.yaml build-name>`。
8. **开发/发布数据隔离**：Pi App 自有的偏好、项目注册表与项目元数据在 debug/profile 中写入 `~/.pi-app-dev`，在正式 Release 中写入 `~/.pi-app`；不自动迁移或删除既有数据。Pi core 自己的 `~/.pi`、认证、session 与项目 resources 不属于该存储边界。

## 范围

- 生产 direct RPC transport、Pi core 生命周期和兼容性管理。
- 项目、session、消息、运行控制、工具 timeline 和文件变更工作流。
- 模型、thinking、认证状态、核心配置、resources 和 extension 降级路径。
- 工具 allowlist、project trust、可选 `pi-light-ce` workflow profile。
- macOS 交付质量、升级验证和后续 Windows / Linux parity。
- 聚焦自动化、真实 smoke test、故障诊断和能力矩阵沉淀。

## 非目标

- 不分发或自动更新 Pi core、Node、Pi SDK、`pi-app-host` companion。
- 不实现 Mac App Store sandbox、OS 级路径隔离、网络隔离或任意 shell 命令逐次确认。
- 不自动执行 `pi-l-ce init`，不在安装 Pi core 或 workflow profile 时自动改写用户项目。
- 不把 GitHub DMG 更新实现为静默替换、自动挂载或自动覆盖 Applications 中的 app。
- 不实现移动端、Web、云端多用户协作、会话云同步或 Pi CLI 的完整 TUI 兼容层。
- 不承诺任意第三方 extension 的自定义 TUI 都能在 Flutter 中原样呈现；先保证明确的支持、降级和诊断。

## 路线总览

| 阶段 | 结果 | 执行单元 | 前置条件 |
| --- | --- | --- | --- |
| P0 | direct RPC 兼容性证据 | R1 | 官方 Pi CLI `0.82.0`、真实测试认证 |
| P1 | production direct RPC workspace | R2 | R1 全部关键证据通过 |
| P2 | macOS Pi core 受管理运行时与工具迁移 | I1、I2、P1 | R1 / R2 对应边界完成 |
| P3 | 日常 coding workflow | C1、C2、O1、O2 | P1、P2 |
| P4 | 配置、资源、trust 与 workflow profile | M1、M2、S1、W1、E1 | P2、P3 |
| P5 | 发布质量、可恢复性与跨平台 | Q1、D1、D2 | P3；D2 以后续平台策略为准 |

每个执行单元都应作为独立提交和独立 `/goal`。阶段 P0 至阶段 P2 均是最高优先级；阶段 P3 是完成核心日常 workflow 的高优先级；阶段 P4、P5 根据 macOS 使用证据排序，不允许为了视觉功能跳过阶段 P0。

## 当前执行队列

总看板的当前顺序固定为 `I1 -> P1 -> I2 -> C1`：先让 runtime 可发现和可诊断，再完成旧权限的显式授权/修复，再提供官方安装入口，最后扩展连续 session 工作流。单个 `/goal` 只能覆盖其中一个连续执行单元。

- I1：已完成；证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。
- P1：进行中，当前下一单元；完整工具默认、legacy migration 与受限 bootstrap 已完成，授权/修复 UI 待实现。
- I2：待 P1 完成后开始，复用 I1 detector 完成安装后的重新检测。
- C1：R2 技术前置已满足，但排在 I2 后，避免把短生命周期 runtime 直接扩展为可恢复 catalog。

## 任务看板

状态含义：`已完成` 表示实现、验证和证据均已闭环；`进行中` 表示已有交付且剩余范围明确；`可开始` 表示前置满足但尚未进入当前切片；`待前置` 表示不得提前实现；`待验收` 表示等待真实环境或发布证据；`待排期` 表示留待 macOS 核心闭环后决定。详细文档分类和更新规则见 `docs/plans/README.md`。

| ID | 状态 | 依赖 | 可交付结果 | 完成门槛 |
| --- | --- | --- | --- | --- |
| R1 | 已完成 | 本机官方 Pi core 与测试认证 | RPC harness、fixture、兼容矩阵 | `--no-approve` 未信任基线和所有关键事件有证据 |
| R2 | 已完成 | R1 | `PiCoreRpcClient`、adapter、workspace 迁移 | 生产路径 direct RPC；无旧 host 静默 fallback；证据见 `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md` |
| I1 | 已完成 | R1 | Pi core detector、诊断卡、测试 fake | 五类 runtime 状态可区分；证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md` |
| I2 | 待前置 | I1、P1 | 官方 installer launcher、Terminal / 日志流程 | 真实下载、可见 Terminal、重新检测闭环 |
| P1 | 进行中 | R1、R2；runtime 修复路径依赖 I1 | 完整 builtin tools、迁移授权 / 修复 dialog | 拒绝后仍受限，tools / trust 不混淆 |
| C1 | 可开始（排在 I2 后） | R2；执行顺序依赖 I2 | session catalog、new / resume / fork | 多项目与重启恢复不串流 |
| C2 | 待前置 | C1 | steer / follow-up / abort / retry 状态机 | 崩溃、迟到 event、恢复可解释 |
| O1 | 待前置 | R2、P1 | 受限工具 timeline、失败诊断 | 大输出不进入 widget state，敏感信息不泄露 |
| O2 | 待前置 | O1 | 文件变更摘要、overview / Git 刷新 | 不自动修改 Git 或覆盖外部编辑器 |
| M1 | 待前置 | R2、C1 | model / thinking / auth / config 闭环 | 运行中不能静默热切换 |
| S1 | 待前置 | R2、P1 | project trust 行为证据与 UI | 撤销 trust 后资源不继续加载 |
| M2 | 待前置 | M1、S1 | commands / prompts / skills resource browser | 来源与可执行性清晰可见 |
| W1 | 待前置 | I1、S1 | 可选 `pi-light-ce` profile 入口 | 不自动安装或 init 项目 |
| E1 | 待前置 | M2、S1 | 最小 extension UI bridge 与降级诊断 | timeout / abort / 不支持 UI 可恢复 |
| Q1 | 待前置 | R2、I2、C2、O1 | 故障矩阵、日志、恢复指导 | 可预期失败均有可操作状态 |
| D1 | 待前置 | Q1、阶段 P0-P3 | 干净 macOS 验收、首个 Release 证据 | 真实 tag / DMG / direct RPC smoke test 通过 |
| D2 | 待排期 | D1、平台调研 | Windows / Linux parity | 各平台各自 installer / process / CI 证据 |

### R1 与 R2 当前状态

R1 已完成 direct RPC 兼容性证据，R2 已完成生产 composer transport 切换，I1 已完成 Pi core 检测、版本信息采集、受限 health 与设置诊断，证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。版本记录是验证和排障证据，不是启动 gate；当前执行队列固定为 I1、P1、I2、C1，P1 是下一执行单元，I2 与 C1 不得抢跑。任何后续单元发现 RPC 语义不满足时，应先更新证据与计划。

- [x] R1.1：建立独立 `pi --mode rpc` harness，固定 LF JSONL framing、超时、1 MiB 保护、原始 request / event 录制和测试项目临时目录。
- [x] R1.2：验证无副作用 state、Pi 版本、create / resume session、model 与 thinking request / response，并形成 host contract 对照表。
- [x] R1.3：验证 prompt、文本 / thinking stream、`agent_settled` 终态、abort、进程退出和迟到 event 的真实顺序。
- [x] R1.4：验证 builtin tool lifecycle、工具输出截断、extension 本地处理 prompt 与终态语义。
- [x] R1.5：构建含 project-local extension / prompt / skill 的 fixture，验证完整 builtin allowlist 加 `--no-approve` 的未信任行为。
- [x] R1.6：将结果写入 capability matrix，列出支持范围、版本、启动参数、残余风险和 R2 的明确 go / no-go 结论。

R1 证据见 `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`，R2 证据见 `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`，I1 证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。当前下一执行单元为 P1；完成后继续 I2、C1。不得将 runtime detector 误解为 installer、session catalog 或完整 timeline 已完成。

## 阶段拆分

### 阶段 P0：Pi RPC 兼容性与未信任基线

- 目标：用事实确认 Pi CLI RPC 能覆盖当前产品 contract，并确认完整 builtin tools 与 `--no-approve` 在未信任项目中的行为。
- 边界：只写 harness、fixture、映射表和证据，不修改 production workspace transport。
- 验收重点：state、create / resume、prompt、文本 / thinking delta、`agent_settled`、abort、model、thinking、tool lifecycle、extension 本地处理、session 文件和 `--no-approve` fixture 均有可复现证据。

### 阶段 P1：Production Direct RPC Workspace

- 目标：以 `PiCoreRpcClient` 替代生产 `LocalPiHostClient`，保持现有 workspace view model 和 JSONL 容量边界。
- 边界：只覆盖现有主链；session catalog、fork、完整 timeline 和 installer 后置。
- 验收重点：多项目不串流、prompt stream / abort 可用、进程代际隔离、崩溃恢复可解释；旧 host 不作为生产 fallback。

### 阶段 P2：Pi Core 管理与安全工具迁移

- 目标：让 macOS 用户知道 Pi core 是否可用、如何安装和如何修复，同时把新 session 迁移到经验证的完整 builtin coding tools 默认。
- 边界：官方 installer 必须在可见 Terminal 运行；不读取 auth、不自动更新 Pi core、不把 `pi-light-ce` 当作 runtime。
- 验收重点：未安装、路径损坏、报告版本缺失、RPC health 失败和运行正常可区分；旧限制策略不会静默升级；用户能明确选择完整工具或保持受限。

### 阶段 P3：日常 Coding Workspace

- 目标：从“一次性 prompt 面板”升级为可连续工作的项目和 session 工作区。
- 边界：优先 Pi session 原生能力，不直接解析或编辑 Pi session JSONL；不做云同步。
- 验收重点：new / resume / fork、steer / follow-up / abort、工具 timeline、变更摘要、失败恢复和跨项目隔离全部成立。

### 阶段 P4：配置、资源与可选工作流

- 目标：补齐运行配置、auth 状态、资源 discoverability、project trust 和可选 `pi-light-ce` workflow profile。
- 边界：resources 先读取元数据，执行能力必须走 trust / diagnostic contract；profile 安装与项目初始化分离。
- 验收重点：用户能理解配置归属、生效范围、资源来源和风险；不支持的 extension UI 不会静默失败。

### 阶段 P5：质量、交付与平台扩展

- 目标：让完成的 macOS 体验可稳定发布、诊断和升级，并将 runtime contract 推广到 Windows / Linux。
- 边界：不为了跨平台复用 macOS Shell / Terminal 假设；每个平台明确安装、进程、日志与包格式。
- 验收重点：macOS real-release smoke test 完整；Windows / Linux 在各自 CI 和干净环境中验证 direct RPC、安装 / 检测和恢复。

## 执行单元

### R1：RPC Capability Matrix

- 所属阶段：P0。
- 目标：实现独立 Pi RPC harness 和含 project-local resource 的 fixture，记录 CLI `0.82.0` 与产品 event contract 的逐项映射。
- 涉及文件 / 模块：新增 RPC fixture / harness、`desktop/test/` 或独立测试目录、`docs/solutions/2026-07-27-pi-host-sdk-contract.md`。
- 前置依赖：官方 `pi`、真实可用模型认证、隔离测试项目目录。
- 验证方式：严格 LF JSONL test、真实 state / prompt / stream / abort、model / thinking、工具和 extension 本地处理；完整 builtin tools 加 `--no-approve` 的 resource fixture。
- 完成标准：写明支持 / 不支持 / 待补能力、确切 CLI 版本、启动参数、事件终态语义和未信任基线；阶段 P1 只能在阶段 P0 的所有阻塞项通过后启动。

### R2：PiCoreRpcClient 与 Workspace 迁移

- 所属阶段：P1。
- 状态：已完成；证据见 `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`。
- 目标：新增 direct RPC JSONL transport、request correlation、adapter、process ownership、generation isolation 和 memory fake，并让 composer 生产路径使用它。
- 涉及文件 / 模块：`desktop/lib/src/pi_host_client.dart` 的替换边界、新增 RPC client / protocol adapter、`desktop_shell.dart`、workspace state、Dart / widget tests。
- 前置依赖：R1。
- 验证方式：单元测试 LF framing、1 MiB 上限、迟到 event、进程替换和 malformed input；真实多项目 prompt / stream / abort smoke test。
- 完成标准：production 仅启动通过显式 runtime override 或 `PATH` 解析的 direct `pi --mode rpc`；I1 已将可执行路径、报告版本与受限 RPC health 变成用户可见诊断，且不以版本号阻止启动。workspace 不读取原始 RPC schema，旧 host 只可作为明确开发回归工具，Dart product client 不向 UI 暴露 raw `bash` / `abort_bash` user command。

### I1：Pi Core Detector 与诊断卡

- 所属阶段：P2。
- 状态：已完成；证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。
- 目标：实现 `PiCoreRuntimeController`，检测用户选择路径、`PI_CORE_EXECUTABLE` 与 `PATH` 中的 `pi`，尽力采集报告版本并运行受限 RPC health。
- 涉及文件 / 模块：runtime abstraction、preferences / persistence、settings feature / view / copy、process fake、测试。
- 前置依赖：R1 的 RPC health contract。
- 验证方式：模拟缺失、不可执行、路径错误、新版 / 预发布 / 扩展版本、版本信息缺失、RPC handshake 失败和健康 Pi；widget 状态回归；`dart run tool/verify_pi_core_runtime.dart --pi /opt/homebrew/bin/pi`。
- 完成结果：设置页展示绝对路径、来源、报告版本、状态、诊断和刷新/选择/清除操作；可用性只由受限 RPC health 决定，默认 client 对新 session 执行 runtime gate，既有 session process 不受路径切换影响；不读取 auth，不加载项目 resources。

### I2：官方 Pi Core Installer Launcher

- 所属阶段：P2。
- 状态：待前置；在 I1 与 P1 完成后执行。
- 目标：下载官方 `https://pi.dev/install.sh`，显示真实脚本下载字节、来源、日志路径，在 macOS 可见 Terminal 启动，并轮询 I1 检测。
- 涉及文件 / 模块：installer service、runtime bridge、settings UI、HTTP / process fake、macOS bridge、测试。
- 前置依赖：I1、P1。
- 验证方式：本地 HTTP fixture 的下载进度、Terminal command、停止等待、日志定位、安装后重新检测和干净环境 smoke test。
- 完成标准：Pi App 不运行隐藏的 `curl | sh`，不伪造 Homebrew / npm 百分比；关闭等待不被描述为取消外部 installer。

### P1：完整 Builtin Tools 与旧偏好迁移

- 所属阶段：P2。
- 状态：进行中；新配置完整 tools 默认、旧偏好安全迁移和受限 bootstrap 已完成，授权/修复 dialog 与 runtime 工具失能路径待实现。
- 目标：完成旧受限策略及 runtime diagnostic 的授权 / 修复对话，并保留已交付的完整 builtin tools 默认与安全迁移。
- 涉及文件 / 模块：`app_preferences.dart`、`app_persistence.dart`、RPC launch arguments、settings / workspace dialog、测试。
- 前置依赖：R1 的 `--no-approve` 基线；R2 的 production transport；剩余 runtime diagnostic 修复路径依赖 I1。
- 验证方式：新安装、`toolPolicyVersion: 1`、授权、拒绝、取消和 runtime 工具失能状态的 client / widget tests。
- 完成标准：拒绝后不扩大权限；所有 UI 明确说明 allowlist 不是 sandbox；project trust 不因 tools 默认启用而改变。

### C1：Session Catalog、New、Resume 与 Fork

- 所属阶段：P3。
- 目标：围绕 Pi 管理的 session 文件实现项目内 session list、创建、恢复、fork、重命名、归档 / 删除入口和最近使用索引。
- 涉及文件 / 模块：RPC adapter、project metadata / registry、workspace session switcher、测试 fake 和迁移。
- 前置依赖：R2。
- 验证方式：真实项目的跨重启恢复、多项目隔离、fork 后上下文差异、归档后不影响原始 session。
- 完成标准：Flutter 不直接修改 session JSONL；用户能可靠地回到最近工作上下文，不会把不同项目 transcript 混在一起。

### C2：运行控制、Steer 与恢复

- 所属阶段：P3。
- 目标：在运行中提供 abort、steer / follow-up、retry、Pi process 重启后的明确恢复策略和 pending state。
- 涉及文件 / 模块：workspace run state、RPC adapter、composer、诊断 / notice、测试。
- 前置依赖：R2、C1。
- 验证方式：真实运行中 abort / steer、请求拒绝、RPC 进程崩溃、重连后 resume；迟到 event 回归。
- 完成标准：用户始终能区分“正在运行、已完成、已中止、可重试、需要新建 session”，不会产生幽灵运行状态。

### O1：受限工具 Timeline 与失败诊断

- 所属阶段：P3。
- 目标：将 Pi 工具事件规约为带时间、状态、目标摘要、截断标记、错误摘要和 artifact 引用的可展开 timeline。
- 涉及文件 / 模块：RPC event adapter、workspace components / feature、local diagnostic store、测试。
- 前置依赖：R1、R2、P1。
- 验证方式：read / bash / edit / write、超长输出、工具失败、abort 和 extension 本地处理的 event fixture；widget 可读性回归。
- 完成标准：不会把原始大输出塞进 widget state 或 JSONL；timeline 不暴露 auth / secret；用户可定位失败步骤。

### O2：文件变更与项目 Overview 联动

- 所属阶段：P3。
- 目标：根据受规约工具事件显示 changed-path 摘要、刷新项目 overview / Git 状态，并提供安全的外部打开动作。
- 涉及文件 / 模块：project overview、workspace timeline、desktop runtime open bridge、Git metadata reader、测试。
- 前置依赖：O1。
- 验证方式：真实 edit / write 产生的变更、无 Git 项目、外部打开失败和多项目状态刷新。
- 完成标准：用户能知道 agent 改了哪些文件；应用不自动覆盖编辑器窗口或执行额外 Git 写操作。

### M1：Model、Thinking、Auth 与核心 Config Center

- 所属阶段：P4。
- 目标：提供当前 / 新 session 的 model 和 thinking picker、provider auth 状态、Pi config 常用项、立即生效与仅新 session 生效的说明。
- 涉及文件 / 模块：RPC adapter、Pi config store、settings feature / view、workspace header、测试。
- 前置依赖：R2、C1。
- 验证方式：列模型、空闲会话切换、运行中禁用、配置保存 / reload、未认证 provider 和错误状态。
- 完成标准：不在运行中静默切模型；不读取 secret；认证入口复用官方 Pi 流程或只展示可操作诊断。

### M2：Resources、Commands、Prompts 与 Skills

- 所属阶段：P4。
- 目标：提供 command palette / resource browser，展示全局与项目来源、类型、描述和可执行性；先覆盖 prompts、skills、commands、packages 的元数据。
- 涉及文件 / 模块：resource index adapter、settings / workspace palette、copy、测试。
- 前置依赖：M1、S1。
- 验证方式：全局资源、未信任项目资源、缺失资源、不可执行资源和搜索 / 筛选回归。
- 完成标准：资源来源和 trust 状态可见；未信任项目中的可执行资源不能被静默执行。

### S1：Project Trust 行为与 UI

- 所属阶段：P4。
- 目标：在 R1 已证实的未信任默认上，验证显式 trust / 撤销 trust 对 project-local extension、prompt、skill、command 的影响，并实现可撤销 UI。
- 涉及文件 / 模块：fixture 项目、RPC harness、project metadata、trust UI、solution 文档、测试。
- 前置依赖：R2、P1。
- 验证方式：显式 trust、撤销 trust、重启、abort、资源加载和工具调用的真实 fixture。
- 完成标准：明确 trust 范围与副作用；撤销后不加载相应 resources；工具 allowlist 与 trust 状态分别呈现。

### W1：可选 `pi-light-ce` Workflow Profile

- 所属阶段：P4。
- 目标：在 Pi core 健康后增加独立的 profile 检测、来源披露、安装和项目初始化确认流程。
- 涉及文件 / 模块：profile service、settings UI、project picker、文档、测试。
- 前置依赖：I1、S1。
- 验证方式：profile 缺失 / 已安装 / 脚本失败、来源确认、init 目标确认和写入预览。
- 完成标准：它永远不显示为 Pi core；不自动安装、不自动 init；可变远端脚本的风险被明确告知。

### E1：Extension UI Bridge 与降级诊断

- 所属阶段：P4。
- 目标：支持最小 confirm / select / input event-response bridge；不支持的 extension 自定义 TUI 显示来源、诊断和 CLI 回退建议。
- 涉及文件 / 模块：RPC adapter、Flutter modal coordinator、timeout / cancel handling、测试。
- 前置依赖：M2、S1。
- 验证方式：fixture extension 的 confirm / select / input、超时、abort、Pi 进程退出与不支持 UI。
- 完成标准：extension 不会无反馈卡住；每个待响应请求有 session 绑定、超时和取消路径。

### Q1：可靠性、日志与恢复矩阵

- 所属阶段：P5。
- 目标：统一 RPC process crash、malformed JSONL、RPC health / schema 错误、installer 失败、下载失败、session 失效和资源拒绝的诊断与恢复动作。
- 涉及文件 / 模块：runtime controller、diagnostic store、local logs、settings / workspace notices、自动化 fixture。
- 前置依赖：R2、I2、C2、O1。
- 验证方式：故障注入、1 MiB 边界、重复启动、旧进程迟到退出、日志路径检查和用户可恢复性手工评估。
- 完成标准：所有可预期故障都有用户可读状态、日志位置和下一步；日志不污染协议 stdout、不记录 auth secret。

### D1：macOS Production Acceptance 与首个正式 Release

- 所属阶段：P5。
- 目标：在真实非开发环境完成 Pi core 检测 / 安装、direct RPC coding、更新和恢复 smoke test，并用 `v<build-name>` 创建第一个 GitHub Release。
- 涉及文件 / 模块：release scripts、GitHub Actions、版本记录、release notes、手工测试证据。
- 前置依赖：阶段 P0 至阶段 P3 完成；Q1 关键故障矩阵通过。
- 验证方式：干净 macOS 用户环境、无 Pi / 路径不可用或 health 失败的 Pi / health 正常 Pi 三种路径；tag gate、DMG、首次打开、更新、真实 prompt / tool / abort / resume。
- 完成标准：发布资产、Pi App build、Pi core 报告版本与验证证据、RPC adapter version、hash、签名模式和残余风险均有可追溯记录；不把 ad-hoc 签名描述为 notarized / Gatekeeper 受信任发布。

### D2：Windows 与 Linux Direct RPC Parity

- 所属阶段：P5。
- 目标：依据 macOS 已稳定的 runtime contract 实现各平台 Pi core 检测、启动、终止、日志、安装入口和 CI / clean-machine smoke test。
- 涉及文件 / 模块：Windows runner、Linux runner、platform runtime bridge、installer policy、CI、测试。
- 前置依赖：D1；各平台官方 Pi 安装方式和 TTY / package-manager 行为的独立研究。
- 验证方式：各平台 build、`pi --version`、受限 RPC health、prompt / abort / recovery、路径含空格、进程终止和日志。
- 完成标准：不复用 macOS `open` / Terminal 假设；每个平台在支持矩阵中有明确 installer、发布包、已验证版本和限制。

## `/goal` 建议作用域

R1、R2、I1 已完成，不应重新创建对应 `/goal`。禁止把整份路线图作为单个 `/goal`；当前和后续目标按以下依赖顺序创建：

1. `/goal P1`：只完成授权/修复 dialog、runtime 工具失能路径与迁移回归；不重做已交付的工具默认策略。
2. `/goal I2`：只完成官方 installer launcher、Terminal 启动和重新检测。
3. `/goal C1`：只完成 session catalog、new / resume / fork 与持久化索引。
4. `/goal C2`：只完成运行控制、steer / follow-up 与进程恢复状态。
5. `/goal O1`：只完成受限工具 timeline 与失败诊断。
6. `/goal O2`：只完成文件变更摘要和项目 overview 联动。
7. `/goal M1`、`/goal S1`、`/goal M2`、`/goal W1`、`/goal E1`：按前置依赖分别执行。
8. `/goal Q1`：只完成可靠性、日志和故障恢复矩阵。
9. `/goal D1`：只完成真实 macOS release 验收与首个 GitHub Release。
10. `/goal D2`：按 Windows、Linux 分开执行，不共享一个跨平台大目标。

## 验证矩阵

| 层级 | 必需证据 |
| --- | --- |
| Dart transport | LF JSONL、request correlation、1 MiB、malformed input、迟到 event、process generation、memory fake 测试 |
| Pi RPC | CLI / adapter 版本、state / prompt / stream / abort / model / thinking / tool / extension fixture 真实记录 |
| Workspace | 多项目隔离、session 恢复、fork、steer、timeline、变更摘要、错误恢复 widget / 手工回归 |
| 安全边界 | `--no-approve` fixture、旧权限迁移、拒绝路径、trust / tools 分离、日志脱敏检查 |
| macOS 交付 | `flutter analyze`、`flutter test`、ad-hoc DMG、`codesign --verify`、`hdiutil verify`、干净环境 smoke test |
| 发布 | `desktop/pubspec.yaml` build name 与 `v<build-name>` tag gate、单一 universal DMG、GitHub Release asset / hash / release notes |
| Windows / Linux | 平台 build、Pi core detection / RPC smoke test、路径和进程生命周期、平台 installer 限制记录 |

## 风险与待确认事项

1. Pi CLI RPC schema 或语义随上游版本变化，必须通过 adapter version 和真实 smoke test 管理，不能只依赖 SDK 类型声明或版本号 gate。
2. R1 若不能证明 `--no-approve` 对 project-local executable resources 的安全基线，R2 / P1 不能把完整 builtin tools 作为生产默认；需要重新设计 trust-first 启动参数。
3. 官方 `install.sh` 的 TTY 行为和 PATH 刷新不能由后台进程可靠控制，安装 UI 必须如实表达“等待 / 重新检测”，不许伪造取消或百分比。
4. session 文件、extension resources 和 auth 属于 Pi core 管理边界；Pi App 不应直接编辑、复制或上传它们。
5. ad-hoc macOS 发布会受 Gatekeeper 影响，首个正式 release 的用户路径需要真实验证；Developer ID / notarization 是后续独立决策。
6. extension UI / package 生态存在不可预测的交互形态，首版应优先正确拒绝和诊断，而不是假装支持。
7. Windows / Linux 安装方式、权限、PATH 和 process handling 不能从 macOS 推导，必须独立调研与验收。

## 沉淀跟进

- R1、R2、I2、P1、S1、Q1、D1、D2 完成时分别在 `docs/solutions/` 记录兼容性、决策、真实验证命令和残余风险。
- 更新 `docs/solutions/2026-07-27-pi-host-sdk-contract.md` 的 capability matrix，不删除历史 host 证据，但明确 production direct RPC capability 的取代关系。
- 每个 release 在 release notes 和能力矩阵记录 Pi App version、Git tag、Pi core version、RPC adapter version、asset hash、签名方式和 smoke test 证据。
