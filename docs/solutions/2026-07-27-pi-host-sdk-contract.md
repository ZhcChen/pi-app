# Pi Host SDK 契约

- 主题：Flutter 桌面端通过本地 `pi-host` 接入 Pi SDK 的运行时契约
- 日期：2026-07-27
- 关联计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`
- Direct RPC 证据：`docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`

> **历史基线说明，2026-07-28：** 本文记录的是已完成的 `Flutter -> pi-host -> Pi SDK` 回归基线，不再定义生产运行时方向。当前生产方向是用户已安装官方 Pi core 的 `pi --mode rpc`；R1 证据见上述 direct RPC matrix。

## 摘要

桌面端首条可用主链已定为 `Flutter -> 本地 pi-host -> Pi SDK`。`host/` 是 Node/TypeScript sidecar，直接使用 `@earendil-works/pi-coding-agent` 的 SDK；Flutter 仅通过 stdio JSONL 接触稳定的产品协议，不直接实现 Pi RPC 或 SDK 状态机。

当前闭环已覆盖：按项目 cwd 创建持久化 session、发送 prompt、流式文本、tool lifecycle、abort、读取和设置 model/thinking。composer 已从“prepared task”展示状态替换为真实 session 状态与消息流。

## 能力与版本基线

### 当前运行时基线

| 项目 | 当前值 | 说明 |
| --- | --- | --- |
| Pi App build manifest | `0.1.0+1` | `desktop/pubspec.yaml` 的桌面应用构建版本；不是独立 SDK 兼容版本。 |
| `pi-host` package | `0.1.0` | 本地 private sidecar 的 package 版本。 |
| Flutter <-> host protocol | `1` | `host/src/protocol.ts` 的 `protocolVersion`；当前只在 protocol 发生破坏性变化时递增。 |
| Pi SDK | `@earendil-works/pi-coding-agent@0.82.0` | 精确锁定并完成实际 prompt 验证的版本。 |
| Node runtime | `>=22.19.0` | host 的最低运行时要求；当前开发机版本不构成产品兼容承诺。 |
| 能力引入基线 | `13e014e` | `feat: 接入 Pi host SDK 会话链路`；文档或计划提交不改变能力基线。 |

> 当前 `host.health` 会返回 protocol 和 SDK version，但尚未返回 host build version。M1 打包阶段应把 host build version、SDK version 和 bundle manifest 一起纳入 runtime handshake；在此之前，本表、`host/package.json` 和 Git commit 是回溯来源。

### 已交付能力矩阵

| 能力 ID | 用户可见能力 | 引入基线 | host protocol | Pi SDK 验证版本 | 当前状态与证据 |
| --- | --- | --- | --- | --- | --- |
| `HOST-001` | 本地 sidecar health 与严格 LF JSONL 通信 | `13e014e` | `1` | `0.82.0` | 已交付；`host.health`、1 MiB 限制、stdout guard 由 host 测试覆盖。 |
| `SESSION-001` | 按项目 `sessionCwd` 创建 Pi 持久化 session | `13e014e` | `1` | `0.82.0` | 已交付；使用 `SessionManager` / `AgentSessionRuntime`，Flutter 以 host session id 路由事件。 |
| `RUN-001` | prompt、文本流、thinking 流与 `run.settled` | `13e014e` | `1` | `0.82.0` | 已交付；真实无工具 prompt 验证文本 `Pi host integration works.` 与最终 settled。 |
| `RUN-002` | 用户中止运行 | `13e014e` | `1` | `0.82.0` | 已交付；`session.abort` 映射 SDK abort，widget / host 回归覆盖。 |
| `MODEL-001` | 读取和设置 model / thinking level 的 host API | `13e014e` | `1` | `0.82.0` | host 已交付；完整 model picker 与 auth UI 尚未交付。 |
| `TOOL-001` | 新 session 的工具白名单 | `13e014e` | `1` | `0.82.0` | 已交付；默认无工具，显式读取 / 编码能力映射内置工具，旧偏好安全迁移。 |
| `RELIABILITY-001` | stdout 隔离、过大记录防护、sidecar 重启后的 session 失效恢复 | `13e014e` | `1` | `0.82.0` | 已交付；包含真实子进程 replacement 回归，旧进程退出不能中断新进程。 |
| `EXTENSION-001` | 本地处理的 extension command / input handler 可正确结束 UI 运行状态 | `13e014e` | `1` | `0.82.0` | 已交付；host 合成 `handledWithoutRun: true` 的 `run.settled`。 |

### SDK 能力暴露矩阵

下表记录的是 Pi SDK `0.82.0` 已验证可提供的能力，与 Pi App 当前是否已包装为 host / GUI 能力的关系。`待设计` 不等于 SDK 不支持，只表示产品协议或交互尚未确定。

| SDK 能力 | SDK 验证版本 | host 暴露 | GUI 暴露 | 当前结论 |
| --- | --- | --- | --- | --- |
| `AgentSession` prompt、abort、事件订阅 | `0.82.0` | 已暴露 | 已暴露核心流程 | 可用。 |
| `AgentSessionRuntime`、`SessionManager` 持久化 session | `0.82.0` | 当前仅 create / state | 当前仅当前项目会话 | list / resume / fork / clone 待阶段 C。 |
| `ModelRuntime`、models / auth 文件读取 | `0.82.0` | 已暴露 model / thinking API | 仅状态展示 | model picker、auth 状态待阶段 C / E。 |
| 内置 coding tools 与 custom tools | `0.82.0` | 内置白名单已暴露 | 设置中的读取 / 编码选择已暴露 | custom tool 管理与逐工具审批待阶段 B / E。 |
| tool execution lifecycle | `0.82.0` | 已规约为开始 / 更新 / 结束 | 仅运行摘要 | 受限 timeline、artifact 引用待阶段 D。 |
| steering、follow-up、queue 状态 | `0.82.0` | `session.prompt.delivery` 已支持 | 未暴露 | 待阶段 C。 |
| compaction、auto retry、session tree navigation | `0.82.0` | 仅部分终态规约 | 未暴露 | 待阶段 C。 |
| settings、system prompts、`AGENTS.md`、skills、prompt templates | `0.82.0` | 资源加载已由 SDK 使用 | Pi Config Center 已覆盖部分 | 高频 runtime 设置和资源 UI 待阶段 E。 |
| global / project-local extensions、commands、packages | `0.82.0` | 全局资源按 SDK 运行；项目资源强制未信任 | 未暴露 | trust、command palette、资源入口待阶段 B / E。 |
| extension confirm / select / input 等 UI 请求 | `0.82.0` | 未定义产品 bridge | 未暴露 | 待阶段 E；复杂自定义 TUI 先降级诊断。 |

### 维护规则

1. 新增、删除或改变一个用户可见运行时能力时，必须在同一提交更新“已交付能力矩阵”；新增能力使用稳定 ID，例如 `SESSION-002`，不能复用已废弃 ID。
2. 每一行都记录引入 commit、host protocol 和 Pi SDK 验证版本。SDK 升级后，即使接口未改，也要更新验证版本和证据。
3. protocol 的新增可选字段 / event 可保持 `1`，但必须在矩阵记录引入 commit；破坏 Flutter <-> host 兼容性的变更必须递增 `protocolVersion` 并记录迁移路径。
4. `pi-host` package 版本记录 sidecar 实现版本，不替代 protocol version；bundle 发布后应在 `host.health` 返回 build version，供运行时诊断使用。
5. 计划中的能力不预先占用版本号。只有协议、实现和验证完成后，才从“SDK 能力暴露矩阵”的待办状态转入“已交付能力矩阵”。
6. 每次 Pi SDK 升级都执行 `npm run check`、`npm test`、真实无副作用 prompt 和 `npm audit --omit=dev --audit-level=high`，并在本节记录结果与残余风险。

## 背景

Flutter 适合承担桌面 UI 与平台壳层，但 Pi 的 `AgentSessionRuntime`、`ModelRuntime`、resource loading、session JSONL 和 extension 生命周期属于 Node 侧能力。让 Dart 直接实现 CLI RPC 的完整协议会导致 UI 绑定底层运行时细节，也会使后续 extension UI、session replacement 和打包难以演进。

官方 SDK 文档明确给出 `createAgentSessionRuntime()`、`createAgentSessionServices()`、`ModelRuntime` 和 session event 模型，因此历史 host 采用 SDK。此处的 host 继续仅作为回归参考；direct RPC 已在 `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md` 通过 R1 验证，并是后续生产主线。

## 关键结论

### 1. host 是产品适配层，不是 SDK 事件透传

`host/src/protocol.ts` 定义产品域 method 和 event。Flutter 只理解：

- request：`host.health`、`session.create`、`session.prompt`、`session.abort`、`session.getState`、`session.listModels`、`session.setModel`、`session.setThinkingLevel`
- event：session 状态、任务开始/完成/中止/失败、文本 delta、thinking delta、tool lifecycle 和 runtime diagnostic

这使 host 可以在未来替换 SDK 内部实现、添加协议版本兼容或接入 RPC fallback，而不改动 workspace UI。

### 2. JSONL 必须只按 LF 分帧，并隔离普通 stdout

host 和 Flutter 都不使用会额外识别 Unicode 分隔符的通用行读取器。Node 使用 `StringDecoder` 和 `\n` 分帧；Dart 使用缓冲字符串并仅查找 `\n`。host 在启动时复用 Pi SDK 的 `output-guard`：SDK、extension 或普通 `console.log` 对 stdout 的写入会重定向到 stderr，协议 writer 仅通过 raw stdout 输出 JSONL。输入和输出单条记录均限制为 1 MiB；UI 不消费的工具 args、partial result 和 result 不进入产品协议。

### 3. `agent_settled` 才是任务完成语义

SDK 的 `agent_end` 之后仍可能发生自动重试、自动压缩或排队消息继续执行。host 仅在 SDK `agent_settled` 时发出 `run.settled`。abort 则由 assistant error 的 `aborted` 原因映射为 `run.aborted`，避免 UI 把用户中止误显示为普通完成。

### 4. session 由 Pi SDK 持久化，不重复造 JSONL 格式

`PiSdkSessionFactory` 使用 `SessionManager.create(cwd)` 与 `AgentSessionRuntime`，让 Pi 自己管理标准 append-only JSONL session。Flutter 使用 host session id 路由事件，按 workspace 的 `sessionCwd` 保存视图状态；切换项目时，旧项目迟到的 stream event 不会污染当前项目。

### 5. 工具策略以显式 session 白名单传递，但不把它伪装成沙箱

`session.create` 的 `tools` 仅接受 host 内置白名单。Flutter 新安装默认不传内置工具；用户显式开启“读取工具”后传 `read`、`grep`、`find`、`ls`，开启“编码工具”后，新 session 才额外获得 `bash`、`edit`、`write`。host 省略参数时仍回退到只读集合，便于直接协议调用。旧版 `settings.json` 缺少 `toolPolicyVersion` 时会迁移为无工具，避免把旧视觉偏好的默认值误解释为新的能力授权。

创建服务时继续使用 `SettingsManager.create(..., { projectTrusted: false })`，因此未实现 GUI trust 确认前，不会自动加载项目级 `.pi` executable resources。该工具白名单不是路径隔离、shell sandbox 或逐工具审批；全局 Pi 配置与全局 extension 仍被视为用户已信任资源。完整 trust/approval UI 仍是后续必做项。

### 6. sidecar 失效必须使 GUI session 失效

`LocalPiHostClient` 将 stdout、stderr、退出回调绑定到启动它的 `Process` 实例。旧 sidecar 的延迟退出或残余 stdout 不会清理替代进程。收到全局 `host.error` 后，Flutter 会将所有保留的 host session id 清空、把活跃任务置为失败；下一次提交会创建新 session，而不是向已丢失的内存 session 发请求。

### 7. 本地处理的 extension prompt 也需要终态

Pi SDK 对 extension command/input handler 可在 `preflightResult(true)` 后直接返回，不发 `agent_start`/`agent_settled`。host 因此等待 `agent_start` 或 prompt 本地完成：前者照常开始流式任务，后者合成 `run.settled` 并附带 `handledWithoutRun: true`。Flutter 不再在 prompt response 后无条件把状态覆写为 running。

### 8. Flutter 通过可注入 client 隔离进程细节

`desktop/lib/src/pi_host_client.dart` 定义 `PiHostClient`、生产 `LocalPiHostClient` 与测试 `MemoryPiHostClient`。`desktop_shell.dart` 负责 session 映射、流状态和用户可见错误；`workspace_feature.dart` 与 workspace components 只持有纯 view model，不依赖 Node 或协议编码。

## 可复用建议

- 新增 host method 时，先扩展 `host/src/protocol.ts` 的请求/响应/event contract，再实现 SDK adapter，最后更新 Dart client；不要让 Flutter 直接解析 SDK 原始 event。
- 新增“任务已完成”视图时，使用 `run.settled`，不要只监听 `run.started`/`agent_end`。
- 所有 stdout 记录必须能够被 `JSON.parse`，调试信息只能去 stderr；host 启动时必须先接管普通 stdout，再创建 protocol writer。
- `agent_settled` 之外的本地处理 prompt 也要形成明确终态；不要让 accepted response 成为 GUI 的唯一生命周期依据。
- host 全局失败时，清空 Flutter 保留的 host session id；host session 只存在于 sidecar 内存，不能跨重启复用。
- 工具白名单只能作为显式能力选择，不应被称为 sandbox 或逐工具审批。
- host 的 SDK 依赖必须是项目直接依赖并精确锁定，不能引用 Homebrew Cellar 或全局 npm 安装路径。
- widget test 一律注入 `MemoryPiHostClient`；真实 Node/SKD 验证由 `host` 的独立测试与手工 host 测试承担。
- sidecar 打包前，不应承诺独立 app bundle 能运行 host；开发期仅从 `host/dist/src/index.js` 启动，并支持 `PI_HOST_ENTRYPOINT` 覆盖。

## 验证 / 证据

- 命令：`cd host && npm run check`
  - TypeScript 严格检查通过。
- 命令：`cd host && npm test`
  - 12 个测试通过，覆盖历史 host 的严格 LF JSONL、writer 顺序和 1 MiB 限制、stdout guard、请求与工具白名单验证、session/prompt event、abort/model/thinking 路由，以及 direct RPC harness 的 LF / CRLF / Unicode separator / 超限 / request-response 关联回归。
- 命令：`cd desktop && flutter analyze`
  - 静态检查通过。
- 命令：`cd desktop && flutter test`
  - 26 个测试通过；覆盖 `MemoryPiHostClient` contract、early delta 消息顺序、默认无工具与显式读取工具、旧偏好的安全迁移、composer -> cwd -> stream -> abort、host 崩溃后的 session 重建、本地处理 prompt 的终态，以及旧 sidecar 退出不能干扰替代进程。
- 命令：`cd desktop && flutter build macos --debug`
  - macOS debug bundle 构建通过。
- 手工证据：通过真实 `host/dist/src/index.js` 发送无副作用 prompt，收到文本 `Pi host integration works.` 及 `run.settled`；另以临时全局 extension command 验证本地处理 prompt 返回 `handledWithoutRun: true` 的 `run.settled`，未触发模型调用。

## 历史后续事项

- **不执行**：将 Node runtime、SDK 依赖与 `host` 纳入 macOS/Windows/Linux bundle 的旧方案已被外置 Pi core 方向替代；参见 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`。
- session list、resume、fork、clone 与 per-project session 索引转入 direct RPC 的 C1。
- model / thinking 的活跃 session 交互转入 direct RPC 的 M1。
- tool timeline 与 extension UI bridge 分别转入 O1 和 E1。
- `npm audit --omit=dev --audit-level=high` 目前报告 Pi SDK 内嵌 `minimatch@10.2.5 -> brace-expansion@5.0.7` 的高危 DoS 公告。常规 `npm audit fix` 和根级 override 无法替换 SDK 的嵌套安装树；需随上游 Pi SDK 发布修复版本后升级并重新验证。
