# desktop 主功能开发路线图

- 任务：为 `desktop` 建立围绕 `pi` 的主功能开发任务链路，覆盖集成形态、runtime host、会话、流式输出、工具面板与打包交付
- 状态：已废弃（历史基线）
- 负责人：Pi
- 日期：2026-07-26
- 依赖文档：
  - `docs/plans/2026-07-26-desktop-follow-up-roadmap.md`
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`（已决定的外置 Pi core 执行计划）
  - `docs/solutions/2026-07-26-pi-integration-modes.md`
  - `docs/solutions/2026-07-27-pi-host-sdk-contract.md`（含能力与版本基线）
  - `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`（外置 Pi core 架构修订）

> **文档状态，2026-07-27：** 本文件记录已完成的 SDK host 主链及其历史规划，整份文档中的 bundle、`pi-host`、SDK adapter、工具审批和旧 `/goal` 描述均不可执行。完整产品上层路线图为 `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`；当前第一个可执行入口是 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md` 的 R1，生产方向为已安装官方 Pi core 的 `pi --mode rpc`。

## 已完成的首条主链（历史基线）

以下内容记录已经完成的 SDK host 闭环及其验证边界，不再代表后续生产运行时方向。新的生产方向是外置 Pi core 与 `pi --mode rpc`，详见 `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`。

此前优先级是先完成 `pi-host` SDK 最小闭环，再回到 Pi Config Center 的阶段 4-5；该闭环现作为 RPC 迁移的回归基线保留。

当时执行范围固定为“可用的第一条主链”，而不是一次性实现完整 CLI：

- `Flutter -> 本地 pi-host -> Pi SDK`
- 以 stdio JSONL 作为 Flutter 与 host 的本地传输层
- 复用 `~/.pi/agent`（或 `PI_CODING_AGENT_DIR`）中的 auth、models、settings 和 Pi 标准 JSONL session
- 每个项目按其 `sessionCwd` 创建独立持久化 session
- 支持创建 session、发送 prompt、流式文本、tool lifecycle、abort、读取当前 model/thinking
- host 内部使用 `AgentSessionRuntime` / `createAgentSessionServices()`，不在 Node host 内再次启动 `pi --mode rpc`

第一轮不实现 OAuth 登录 UI、project trust 确认 UI、session 列表/恢复界面、fork/clone、extension UI 对话、完整 tool timeline 或 sidecar 打包。对于没有明确已保存信任的项目，host 以未信任状态加载项目资源，避免静默执行项目级 extension；全局 Pi 资源和 `AGENTS.md` 仍按 SDK 默认规则生效。

## 当前进度

- 已完成：阶段 0 / 单元 1
  - `host/`、严格 LF JSONL request/event contract 和 SDK/runtime 边界已经落地
- 已完成：阶段 1 / 单元 2-4
  - host 已接入 `ModelRuntime`、`AgentSessionRuntime`、持久化 session、prompt stream、abort、model 和 thinking API
- 已完成：阶段 2 / 单元 5 第一批
  - Flutter composer 已接入真实 host session、prompt、文本流、tool 状态摘要和 abort
  - sidecar stdout 使用 Pi `output-guard` 隔离普通日志；host 重启会使旧 GUI session 失效并在下一次提交时重建
  - 新安装的默认 session 不获内置工具；用户显式开启“读取工具”后添加 `read`、`grep`、`find`、`ls`，开启“编码工具”后再添加 `bash`、`edit`、`write`
  - extension command/input handler 的本地完成路径会发出终态，不会让 composer 卡在运行中
- 待执行：阶段 2 / 单元 6 及后续
  - 完整消息/工具 timeline、session 管理、trust UI、model picker、auth UI 与受管理 Pi core 的安装 / 检测 / 兼容性

## 已废弃的旧下一阶段方案（仅历史记录，不可执行）

> **架构修订，2026-07-27：** Pi App 不再以 bundle 内置 Node runtime、`pi-host` 和 Pi SDK 为产品方向，而是增强用户独立安装的 Pi core。原 M1/A1/A2 的 bundle 假设及本节其他旧单元均已废弃，禁止按本节描述执行。已决定的替代执行计划见 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`；架构决策记录见 `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`。本节只保留历史上下文。

### 排序原则

1. 先让现有主链可以在没有开发环境的机器上稳定启动，再扩大功能面。
2. 在暴露 `bash`、`edit`、`write` 前完成可见、可拒绝、可持久化的 trust / approval 交互；工具白名单不是 sandbox。
3. 会话、模型、thinking 和工具事件都继续由 host 规约，Flutter 不读取 Pi session JSONL 或 SDK 原始事件。
4. 每个阶段保持可独立验收、提交和回滚；长任务按下面的连续单元创建 `/goal`，不将整条路线作为单个 goal。

### 建议里程碑

| 里程碑 | 交付结果 | 前置条件 | 建议优先级 |
| --- | --- | --- | --- |
| M1：可分发运行时（旧方案，已暂停） | macOS bundle 自带可启动的 Node + host，具备诊断与兼容检查 | 当前 host 主链 | P0 |
| M2：受控编码 | 项目 trust 和逐工具 approval 生效，用户能安全地授权读写 / shell | M1 的 host 发现与日志能力 | P0 |
| M3：日常会话工作流 | new / resume / fork、steer / follow-up、model / thinking 选择可用 | M2 | P1 |
| M4：可观测执行 | 可展开的工具 timeline、失败和受限输出可追踪 | M2、M3 | P1 |
| M5：配置与资源生态 | Config Center 后续项、auth 状态、commands / prompts / skills、extension UI bridge | M3、M4 | P2 |
| M6：跨平台交付 | Windows、Linux sidecar bundle 与平台回归 | M1 的 macOS 方案稳定 | P2 |

### 阶段 A：M1 可分发运行时（旧方案，已暂停）

> 此阶段假设 Pi App bundle 内置 Node、host 和 SDK，已与外置 Pi core 方向冲突。不要执行下列 A1/A2；它们已被 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md` 中的 R1/R2/I1/I2 替代。

**目标**：消除开发期对系统 Node、仓库 cwd 和 `PI_HOST_ENTRYPOINT` 的依赖，先交付可在干净 macOS 用户环境启动的 bundle。

1. 定义 bundle 布局与构建脚本：将完整官方 Node runtime、`host/dist`、生产依赖和版本清单置于 app resources；不采用 Node SEA，因为 Pi 的动态 SDK / extension 加载需要完整 Node 运行时。
2. 将 `LocalPiHostClient` 的发现顺序固化为：显式开发覆盖变量、bundle sidecar、开发态入口；生产态不从当前 cwd 猜测路径。
3. 在 `host.health` 中增加 host build version、SDK version 和 protocol version；Flutter 对不兼容版本给出可操作诊断。
4. 增加 `~/.pi-app/logs/` 轮转日志、启动失败原因、崩溃次数和有限退避重启；不把诊断混入 JSONL stdout。
5. 编写 macOS clean-machine smoke test：临时隐藏系统 Node / 仓库入口，启动 bundle、创建无工具 session、发送 prompt、验证退出与重启。

**涉及区域**：`host/` 构建脚本、`desktop/macos/`、`desktop/lib/src/pi_host_client.dart`、CI / release scripts。

**验收标准**：从 `Pi App.app` 启动时不需要系统 Node；sidecar 无法启动时 UI 显示诊断入口；host 协议不兼容不会发送任务；签名 / notarization 所需的嵌套 runtime 策略有文档和自动检查。

### 阶段 B：M2 项目 trust 与权限审批

**目标**：把当前“工具白名单 + 未信任项目资源”的安全默认落实为真实、可见的用户决策。

1. 先做 SDK capability spike：确认 Pi SDK 对 project trust、tool interception、extension / package 资源加载和取消的准确 API；将结论写入 solution 文档后再扩展 protocol。
2. 新增版本化 host contract：`project.getTrust`、`project.setTrust`、`permission.request` event、`permission.resolve` request；每个 request 绑定 host session、tool call 和过期时间。
3. Flutter 增加项目级 trust surface：展示项目路径、将加载的本地 `.pi` resources、风险说明和信任范围；默认拒绝，移除 trust 只删应用记录，不删除项目文件。
4. 第一版 approval 策略：读取工具按用户已选能力执行；`bash`、`edit`、`write` 在执行前请求用户确认，支持 Deny、Allow once、Allow for session。项目级长期授权只在已信任项目中开放。
5. 明确限制：approval 不是 OS sandbox。对外部绝对路径、危险 shell 模式和网络命令的规则先采用保守默认，后续再根据 Pi SDK 可拦截粒度扩展。

**涉及区域**：`host/src/protocol.ts`、SDK adapter、workspace dialog / settings、项目 metadata、测试 fake。

**验收标准**：未信任项目不会加载 project-local executable resources；工具执行在没有 Flutter 决策时不会继续；拒绝、超时、sidecar 重启和 session abort 都能结束等待中的 approval；所有状态均有 widget + host 测试。

### 阶段 C：M3 会话与运行控制

**目标**：让当前“一项目一个临时 host session”升级为可管理的 Pi 会话工作流。

1. Host 增加 session list、resume、new、fork / clone 和 delete / archive 的产品协议；Pi session 文件格式仍由 SDK 管理，Flutter 不直接解析或修改 JSONL。
2. 项目 metadata 保存最近 session、当前 model / thinking、最近工具策略和展示别名；继续使用 JSON index，等跨项目查询、过滤和历史量确实复杂后再评估 SQLite / drift。
3. Workspace 增加 session switcher、new session、resume、fork；切换时明确 transcript 是否可见、运行中 session 如何处理，避免 UI transcript 与实际 SDK context 不一致。
4. 运行中 composer 提供 `steer` / `followUp` 选择，而不是只显示 abort；queue 状态、自动重试和 compaction 统一由 host 转为稳定状态事件。
5. 增加 model / thinking picker：新会话和空闲会话可切换；运行中禁用并解释原因。配置保存后的“对新会话生效 / 应用于当前空闲会话”必须显式选择。
6. Auth 第一版只展示 provider 状态和跳转到受支持的 Pi 登录流程；OAuth 内嵌 UI 在 SDK API、回调和安全模型确认前不实现。

**验收标准**：用户可恢复历史 session、创建干净上下文、fork 当前上下文；切换项目不会串流；steer / follow-up 和 abort 在真实 host 中可观察；模型切换不会在运行中静默失败。

### 阶段 D：M4 工具 timeline 与工作区联动

**目标**：把 agent 执行从状态摘要升级为可审查的工作记录，同时不重新向 UI 暴露无限制原始工具输出。

1. 扩展 host tool event，提供受大小限制、经脱敏的结构化摘要：工具名、目标相对路径 / 命令分类、开始结束时间、状态、截断标记和错误摘要。
2. 对大输出使用受控 artifact 引用或“查看本地日志”操作，不直接塞入 JSONL / widget state；继续保留 1 MiB 协议限制。
3. Workspace 增加可展开 timeline、当前工具、失败详情、受限 / 被拒绝状态，以及与项目文件和外部打开动作的关联。
4. 对 edit / write 成功事件加入 changed-path 摘要，并刷新 overview / Git 状态；不自动打开或覆盖用户编辑器窗口。

**验收标准**：用户能回答“Pi 做了什么、在哪里失败、是否被拒绝、影响了哪些项目文件”；长命令输出不会卡死 host 或 Flutter；所有摘要不包含 auth / prompt secret 的原文。

### 阶段 E：M5 Config Center 与资源生态

**目标**：补齐高频 Pi 配置和资源入口，但所有会执行代码的资源必须经过阶段 B 的 trust 规则。

1. Config Center 阶段 4：runtime / delivery / compaction / retry 等高频设置，以读取、编辑、保存、重载语义为最小闭环。
2. Config Center 阶段 5：resources、advanced、auth、trust 入口；区分全局配置、项目配置和活跃 session 的即时生效范围。
3. 提供 command palette，展示 prompts、skills、commands 与 packages；默认仅展示元数据，执行 extension command 前复用 approval / trust contract。
4. 设计 extension UI bridge：confirm / select / input 先实现最小事件-响应协议；复杂自定义 TUI 明确降级为诊断，不在 Flutter 中静默失败。

**验收标准**：用户能看懂配置归属和何时生效；不信任项目的资源不可执行；extension UI 请求可取消、可超时、可显示来源。

### 阶段 F：M6 Windows / Linux 与发布保障

**目标**：将 M1 的 runtime contract 扩展到 Windows、Linux，并形成持续验证的发布链路。

1. 抽象各平台 bundle resolver、runtime path、日志目录和子进程终止策略；Windows 不使用 shell 启动 sidecar。
2. 在 CI 中分别构建 macOS、Windows、Linux，校验 bundle 包含 Node、host、生产依赖和版本清单。
3. 增加平台 smoke test：health、create session、malformed JSONL、sidecar crash / replacement、无系统 Node 启动。
4. macOS 完成签名、hardened runtime、notarization 兼容验证；Windows / Linux 根据发行方式补 installer / package metadata。

**验收标准**：三个目标平台都能在干净环境启动 bundled host；错误日志可定位；更新后 host / Flutter 版本不匹配可恢复或明确阻止。

### 已废弃的旧 `/goal` 建议（不可执行）

1. `/goal A1`：macOS bundle layout、生产 resolver、health version / diagnostics。
2. `/goal A2`：macOS clean-machine smoke test、日志与崩溃退避。
3. `/goal B1`：trust / approval SDK spike 与协议设计，不改 UI 行为。
4. `/goal B2`：trust persistence、Flutter trust UI、project-local resources gate。
5. `/goal B3`：tool approval request / resolve、超时 / abort / restart 回归。
6. `/goal C1`：session list / resume / new 的 host contract 与项目索引。
7. `/goal C2`：session switcher、steer / follow-up、model / thinking picker。
8. `/goal D1`：受限工具摘要 contract 与 timeline UI。
9. `/goal E1`：Config Center 高频设置与 auth 状态。
10. `/goal E2`：commands / prompts / skills、extension UI bridge。
11. `/goal F1`：Windows / Linux bundle 与 CI smoke test。

### 需要确认的产品决策

- 分发渠道：macOS 首版采用 Developer ID + notarization，还是仅内部 / unsigned 测试分发。
- 审批默认：推荐 `Deny`、`Allow once`、`Allow for session` 三档；是否需要已信任项目的长期允许。
- Auth 首版：推荐只显示状态并复用 Pi 现有登录流程，不在第一版内嵌 OAuth 浏览器流。
- 平台顺序：推荐 macOS 完整闭环后再并行推进 Windows / Linux，而不是三端同时实现打包。

## 目标

这个任务完成后，`desktop` 必须从“界面壳 + 设置 + 若干桥接能力”进入“可真实使用的 `pi` GUI client”状态，至少具备：

- 能启动 `pi` 运行时并创建/恢复会话
- 能发送 prompt、接收流式回复、abort、中途 steer / follow-up
- 能展示 tool call、bash 输出、文件操作结果和失败态
- 能管理 session、model、thinking level、基础 auth 状态
- 能和现有 workspace / settings / desktop runtime bridge 协同工作

## 范围

这次计划覆盖：

- `desktop/` Flutter GUI
- 本地 `pi-host` sidecar（建议新增 `host/` 或 `desktop_host/` 模块）
- `pi` SDK / RPC 集成
- session / model / auth / event stream / tool timeline
- 后续打包与本地分发链路

## 非目标

- 不在第一轮就补全所有 settings 分类
- 不一开始就做远程多人协作或云端会话同步
- 不为了 GUI 强行改造 `pi` 内核源码
- 不把 Flutter 直接做成 `pi` 全量 CLI 语义的镜像壳

## 影响区域

- 文件：`desktop/lib/**`、新增 `host/**`（或等效目录）
- 模块：workspace、settings、session surface、tooling surface、runtime integration
- 接口 / 约束：
  - `pi` SDK / RPC
  - 桌面端本地进程生命周期
  - 本地权限、路径、日志与打包策略

## 实现思路

1. 先确定 `pi` 集成主线：Flutter UI + 本地 `pi-host` sidecar + SDK
2. 再做最小 host spike，先证明 session / prompt / stream / abort / model 切换
3. 最后按“会话 -> 工具 -> 设置 -> 打包”顺序逐层上 GUI，而不是先堆界面再补底层

## 阶段拆分

### 阶段 0：集成面定版

- 目标：把 `pi` 集成面、进程边界、sidecar 位置和产品域 API 定下来
- 边界：只做架构决策和 host contract，不做完整 GUI
- 验收重点：明确 SDK / RPC 的角色分工，以及 Flutter 与 host 的通信边界

### 阶段 1：`pi-host` 最小可运行闭环

- 目标：做出本地 sidecar，打通 session、prompt、stream、abort、model
- 边界：先不做复杂 GUI，只提供最小 demo 对接能力
- 验收重点：同一轮会话可以真实跑起来，并输出结构化事件流

### 阶段 2：会话主界面接线

- 目标：把现有 `desktop` 壳层接到真实 host
- 边界：优先做主对话流，不急着把每个辅助页面都接全
- 验收重点：composer、消息流、状态栏、错误态可用

### 阶段 3：工具与工作区联动

- 目标：展示 tool call、bash 输出、文件结果，并和 workspace 行为联动
- 边界：先做核心工具面板，不强行复制 CLI 的全部 TUI 细节
- 验收重点：用户能看懂 agent 做了什么、失败在哪、作用于哪个路径

### 阶段 4：会话管理与模型/Auth 设置

- 目标：补 session 生命周期、model/thinking/auth 管理
- 边界：优先支持最常用 provider / model 切换，不一次做全 provider UI
- 验收重点：新建、恢复、fork、切 model、检查 auth 状态能走通

### 阶段 5：扩展与资源生态

- 目标：把 commands、skills、prompt templates、extensions、packages 拉进 GUI
- 边界：先做资源可见、可触发、可诊断；更复杂的编辑能力后置
- 验收重点：GUI 不再只是聊天窗口，而是完整的 `pi` 运行环境前端

### 阶段 6：打包与交付

- 目标：让 app 与 sidecar 可以稳定打包、启动、升级和诊断
- 边界：先覆盖 macOS，再评估 Windows/Linux
- 验收重点：用户机器上不依赖手工拼装开发环境也能启动主功能

## 执行单元

### 单元 1

- 所属阶段：阶段 0
- 目标：确定 sidecar 目录形态与通信协议
- 涉及文件 / 模块：新增 `host/**` 设计文档、`desktop/lib/**` 对接边界
- 前置依赖：`docs/solutions/2026-07-26-pi-integration-modes.md`
- 验证方式：设计评审与 demo contract 文档
- 完成标准：明确 Flutter <-> host 的 request/event 协议，说明哪些接口映射 SDK、哪些保留产品适配层

#### 当前执行细则（2026-07-27）

- host 目录固定为 `host/`，使用 ESM Node，并将 `@earendil-works/pi-coding-agent` 精确锁定为 `0.82.0`
- 输入输出均为严格 JSONL：只以 LF 分帧；启动时通过 Pi `output-guard` 将普通 stdout 转到 stderr，raw stdout 只输出协议对象；单条记录上限为 1 MiB
- request 采用 `id`、`method`、`params`；首批 method 为 `host.health`、`session.create`、`session.prompt`、`session.abort`、`session.getState`、`session.listModels`、`session.setModel`、`session.setThinkingLevel`
- host event 必须包含 host session id；首批 event 为 `session.created`、`run.started`、`message.delta`、`thinking.delta`、`tool.started`、`tool.updated`、`tool.completed`、`run.settled`、`run.aborted`、`run.failed`、`session.state`
- SDK 的 `agent_settled` 是一次 agent 任务真正完成的唯一事件，不以 `agent_end` 作为完成信号；extension command/input handler 本地完成时，host 合成带 `handledWithoutRun` 的 `run.settled`
- `session.create` 以受限 `tools` 白名单建立新 session：Flutter 新安装默认不传内置工具；“读取工具”会添加 `read`、`grep`、`find`、`ls`，“编码工具”再添加 `bash`、`edit`、`write`。host 省略参数时仍回退到只读集合，便于直接协议调用。该策略不是路径 sandbox 或逐工具 approval
- sidecar 退出或协议失败时，Flutter 清除所有 host session id 并标记活跃任务失败；不会向重启前仅存在于内存的 session 继续发请求
- 不把 SDK 原始 event 结构直接作为 Flutter public contract；host 负责规约为稳定的产品事件

### 单元 2

- 所属阶段：阶段 1
- 目标：创建 `pi-host` 工程并接入 `@earendil-works/pi-coding-agent`
- 涉及文件 / 模块：`host/package.json`、`host/src/**`
- 前置依赖：单元 1
- 验证方式：本地命令行启动 host，能创建 session
- 完成标准：host 能初始化 `ModelRuntime`、`createAgentSessionRuntime()`、并输出最小健康状态

### 单元 3

- 所属阶段：阶段 1
- 目标：打通 prompt / stream / abort
- 涉及文件 / 模块：`host/src/session/**`
- 前置依赖：单元 2
- 验证方式：脚本或测试驱动 prompt，能收到 text delta 和结束事件
- 完成标准：host 对外提供 `prompt`、`abort`，并能转发 streaming events

### 单元 4

- 所属阶段：阶段 1
- 目标：打通 model 与 thinking 控制
- 涉及文件 / 模块：`host/src/model/**`
- 前置依赖：单元 2
- 验证方式：列模型、切模型、切 thinking level
- 完成标准：GUI 不必直连 `pi` 原语，也能拿到当前 model/thinking state

### 单元 5

- 所属阶段：阶段 2
- 目标：将 Flutter composer 接到真实 host prompt
- 涉及文件 / 模块：`desktop/lib/src/desktop_shell.dart`、workspace 相关组件
- 前置依赖：单元 3
- 验证方式：手工发送 prompt，GUI 收到真实回复流
- 完成标准：当前空态工作区可变成真实对话入口

#### 当前执行细则（2026-07-27）

- 新增独立 `PiHostClient` abstraction，不扩展已有 `DesktopRuntimeController`
- production client 负责本地 Node sidecar 生命周期与 stdio JSONL；测试使用 `MemoryPiHostClient`
- shell 按 host session id 和 `sessionCwd` 隔离流事件，项目切换不能让旧项目的 event 污染当前视图
- composer 仅在 host 已接受 prompt 后清空输入；启动、失败、运行中和 abort 都必须是可见状态
- 当前模型与 thinking 由 host 状态展示；现有 Pi Config 保存仍以新 session 生效为默认，不伪造运行中热更新

### 单元 6

- 所属阶段：阶段 2
- 目标：实现消息流与运行状态栏
- 涉及文件 / 模块：`desktop/lib/src/workspace_feature.dart`、新 session/message 组件
- 前置依赖：单元 5
- 验证方式：多轮对话、abort、失败态手工验证
- 完成标准：用户能区分运行中、已完成、失败、已中止状态

### 单元 7

- 所属阶段：阶段 3
- 目标：实现 tool timeline 与 bash/file 输出面板
- 涉及文件 / 模块：workspace/tool 相关组件、host event adapter
- 前置依赖：单元 3、单元 6
- 验证方式：触发 `bash`、`read`、`edit` 等工具并验证事件显示
- 完成标准：工具调用和结果对用户可见，不再是黑盒

### 单元 8

- 所属阶段：阶段 3
- 目标：把 workspace 打开、路径、项目上下文与会话 cwd 对齐
- 涉及文件 / 模块：`desktop/lib/src/app_data.dart`、workspace 数据源、host cwd routing
- 前置依赖：单元 7
- 验证方式：选择不同项目/路径后，session cwd 与打开行为一致
- 完成标准：GUI 中选中的项目真正影响 agent 工作上下文

### 单元 9

- 所属阶段：阶段 4
- 目标：做 session list / resume / new / fork / clone
- 涉及文件 / 模块：session 管理页、host session runtime adapter
- 前置依赖：单元 2、单元 6
- 验证方式：多 session 切换与恢复手工验证
- 完成标准：session 生命周期从 CLI 层抽成 GUI 可见工作流

### 单元 10

- 所属阶段：阶段 4
- 目标：做 auth/model 设置最小闭环
- 涉及文件 / 模块：settings、host model/auth adapter
- 前置依赖：单元 4
- 验证方式：检查 auth 状态、切 model、切 thinking
- 完成标准：用户不必回到 CLI 才能完成最常用运行配置

### 单元 11

- 所属阶段：阶段 5
- 目标：把 commands / prompts / skills 暴露到 GUI
- 涉及文件 / 模块：命令面板、资源索引、host command adapter
- 前置依赖：单元 6、单元 9
- 验证方式：GUI 触发 `/prompt`、`/skill:*`、extension command
- 完成标准：资源生态不再只存在于 CLI

### 单元 12

- 所属阶段：阶段 5
- 目标：评估并接入 extension UI 子协议
- 涉及文件 / 模块：host UI bridge、Flutter dialog bridge
- 前置依赖：单元 11
- 验证方式：模拟 extension 的 confirm/select/input 请求
- 完成标准：extension UI 不会在 GUI 下直接失效或无反馈

### 单元 13

- 所属阶段：阶段 6
- 目标：明确 sidecar 打包方案
- 涉及文件 / 模块：桌面构建脚本、bundle 资源、版本策略
- 前置依赖：单元 2-12 至少主链可运行
- 验证方式：全新环境启动验证
- 完成标准：桌面包内可稳定启动 host，并能输出诊断信息

## `/goal` 建议作用域

- 当前建议先把 `/goal` 绑定到：`阶段 0 + 阶段 1`
- 不建议一开始就把整个“desktop 主功能开发”作为单个 `/goal`
- 推荐的连续闭环是：
  1. `pi-host spike`
  2. Flutter 接 prompt / stream
  3. tool timeline
  4. session / model / auth

## 验证方式

- 命令：
  - `cd host && npm test`（host 建立后）
  - `cd desktop && flutter analyze`
  - `cd desktop && flutter test`
  - `cd desktop && flutter build macos --debug`
- 手工检查：
  - 真实 prompt 可流式返回
  - abort、steer、follow-up 可观察
  - tool 调用和失败态在 GUI 中可见
  - session / model / auth 基本工作流成立
- 预期证据：
  - host 与 Flutter 之间存在稳定 request/event contract
  - GUI 能替代最常用 CLI 工作流，而不是只做静态外壳
  - 打包产物内能带起本地 `pi` 运行时

## 风险 / 待确认问题

- Flutter 最终与 host 的通信方式是 stdio、domain socket、named pipe 还是本地 websocket
- sidecar 是否随 app 一起打包 Node runtime，还是依赖系统已有 Node
- OAuth / `/login` 相关流程是否直接复用 `pi` 现有 auth 文件与 `ModelRuntime`，还是要做 GUI 包装
- extension UI 子协议在 Flutter 端做多少适配，哪些先降级
- Windows / Linux 打包时，host 启动和进程管理是否与 macOS 保持一致

## 沉淀跟进

- 当前已经值得沉淀：`docs/solutions/2026-07-26-pi-integration-modes.md`
- 后续 `pi-host` 真正落地后，建议再补一份 host contract 与 packaging 决策文档
