# Pi Host SDK 契约

- 主题：Flutter 桌面端通过本地 `pi-host` 接入 Pi SDK 的运行时契约
- 日期：2026-07-27
- 关联计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`

## 摘要

桌面端首条可用主链已定为 `Flutter -> 本地 pi-host -> Pi SDK`。`host/` 是 Node/TypeScript sidecar，直接使用 `@earendil-works/pi-coding-agent` 的 SDK；Flutter 仅通过 stdio JSONL 接触稳定的产品协议，不直接实现 Pi RPC 或 SDK 状态机。

当前闭环已覆盖：按项目 cwd 创建持久化 session、发送 prompt、流式文本、tool lifecycle、abort、读取和设置 model/thinking。composer 已从“prepared task”展示状态替换为真实 session 状态与消息流。

## 背景

Flutter 适合承担桌面 UI 与平台壳层，但 Pi 的 `AgentSessionRuntime`、`ModelRuntime`、resource loading、session JSONL 和 extension 生命周期属于 Node 侧能力。让 Dart 直接实现 CLI RPC 的完整协议会导致 UI 绑定底层运行时细节，也会使后续 extension UI、session replacement 和打包难以演进。

官方 SDK 文档明确给出 `createAgentSessionRuntime()`、`createAgentSessionServices()`、`ModelRuntime` 和 session event 模型。因此 host 使用 SDK，而 `pi --mode rpc` 仅保留为排障或替代实现参考，不作为应用主链。

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

### 6. Flutter 通过可注入 client 隔离进程细节

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
  - 8 个测试通过，覆盖严格 LF JSONL、writer 顺序和 1 MiB 限制、stdout guard、请求与工具白名单验证、session/prompt event、abort/model/thinking 路由。
- 命令：`cd desktop && flutter analyze`
  - 静态检查通过。
- 命令：`cd desktop && flutter test`
  - 26 个测试通过；覆盖 `MemoryPiHostClient` contract、early delta 消息顺序、默认无工具与显式读取工具、旧偏好的安全迁移、composer -> cwd -> stream -> abort、host 崩溃后的 session 重建、本地处理 prompt 的终态，以及旧 sidecar 退出不能干扰替代进程。
- 命令：`cd desktop && flutter build macos --debug`
  - macOS debug bundle 构建通过。
- 手工证据：通过真实 `host/dist/src/index.js` 发送无副作用 prompt，收到文本 `Pi host integration works.` 及 `run.settled`；另以临时全局 extension command 验证本地处理 prompt 返回 `handledWithoutRun: true` 的 `run.settled`，未触发模型调用。

## 后续事项

- 把 Node runtime、SDK 依赖与 `host` 纳入 macOS/Windows/Linux bundle，补 sidecar 查找、版本协商、崩溃重启和诊断日志。
- 实现项目 trust UI，再允许加载 project-local `.pi` extensions、packages、skills 和 settings。
- 补 session list、resume、fork、clone 与 per-project session 索引。
- 将 `Pi Config` 中保存的 model/thinking 与活跃 host session 的刷新/切换时机做成明确交互。
- 将当前 tool lifecycle 摘要扩展为可展开 timeline，并接入 extension UI bridge。
- `npm audit --omit=dev --audit-level=high` 目前报告 Pi SDK 内嵌 `minimatch@10.2.5 -> brace-expansion@5.0.7` 的高危 DoS 公告。常规 `npm audit fix` 和根级 override 无法替换 SDK 的嵌套安装树；需随上游 Pi SDK 发布修复版本后升级并重新验证。
