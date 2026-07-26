# pi 集成形态选型

- 主题：`desktop` 主功能开发时，`pi` 集成面应该选 SDK、RPC，还是自建 app-server sidecar
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`

## 摘要

基于 `pi` 官方 README、`docs/sdk.md`、`docs/rpc.md` 和 `examples/sdk/` 的现状，当前可用的官方集成面有两条：

- **Node SDK**：`@earendil-works/pi-coding-agent`
- **RPC mode**：`pi --mode rpc`，通过 stdin/stdout JSONL 协议集成

当前文档里**没有发现一个现成的、独立发布的 app-server 产品形态**，也没有类似“Codex CLI app-server”那样的官方独立服务端交付物。

如果我们要做 Flutter 桌面端的长期产品形态，推荐主线是：

- **Flutter UI**
- **本地 `pi-host` sidecar（Node/TypeScript）**
- **`pi` SDK**

RPC 仍然值得保留，但更适合作为：

- 早期协议验证路径
- 非 Node 宿主语言的兜底接法
- sidecar 不可用时的备用集成层

## 背景

当前 `desktop` 已经有：

- 桌面壳层与设置页
- 应用级偏好持久化
- 部分真实 runtime bridge（`showInMenuBar`、`openDestination`）

但真正的主功能还没开始：

- 会话生命周期
- prompt / steer / follow-up
- tool call 流式输出
- model / auth / session tree
- skills / prompts / extensions / packages

在开始主功能开发前，必须先把 `pi` 作为底层引擎的集成边界选定，否则 UI、runtime、打包和状态管理会来回返工。

## 调研结论

### 1. `pi` 官方提供 SDK

`docs/sdk.md` 明确说明：

- 可通过 `createAgentSession()` 嵌入单会话能力
- 可通过 `createAgentSessionRuntime()` 管理会话替换、fork、resume、import 等 runtime-backed 流程
- `ModelRuntime` 负责 models / auth / OAuth / API key 解析
- `DefaultResourceLoader` 可加载 extensions、skills、prompts、themes、AGENTS.md

`README.md` 也明确把 SDK 列为四种官方模式之一，并指向 `openclaw/openclaw` 作为真实 SDK 集成案例。

### 2. `pi` 官方提供 RPC mode

`README.md` 与 `docs/rpc.md` 明确说明：

- 可以直接启动 `pi --mode rpc`
- 通过 stdin/stdout JSONL 做 headless process integration
- 支持 prompt、steer、follow_up、abort、session switching、model 切换、bash 命令、event stream、extension UI 子协议

`docs/rpc.md` 还明确区分了适用场景：

- SDK 更适合同进程 Node.js/TypeScript 集成、需要类型安全和直接 agent state 的场景
- RPC 更适合跨语言和进程隔离场景

### 3. 没有现成“app-server 产品”

从当前官方 README、SDK、RPC、examples、extensions、packages 文档里，没有看到一个现成的独立 server 交付物，例如：

- 一个固定的 HTTP server
- 一个内建的 websocket app-server
- 一个专门面向 GUI 应用的 app-host 二进制

因此，如果我们需要“类似 Codex CLI app-server”的本地服务层，需要**自己做一个 `pi-host` sidecar**。

## 推荐架构

### 推荐主线：Flutter UI + 本地 `pi-host` sidecar + SDK

推荐结构：

- Flutter 负责桌面 UI、窗口、交互、渲染、平台壳层
- 本地 `pi-host` sidecar 负责会话、模型、工具、事件流、扩展资源加载
- `pi-host` 直接使用 `@earendil-works/pi-coding-agent` SDK

推荐原因：

1. **把 `pi` 的复杂状态留在 Node 侧**
   - `AgentSession`
   - `AgentSessionRuntime`
   - `ModelRuntime`
   - `ResourceLoader`
   - extensions / skills / prompts / themes

2. **Flutter 不必直接承接底层协议细节**
   - 不必在 Dart 里手写完整 RPC 协议层
   - 不必直接处理 extension UI 子协议细节
   - 不必把 session/runtime 替换逻辑翻译成 Dart 状态机

3. **后续演进空间更大**
   - 可以在 sidecar 暴露更贴近产品域的 API
   - 可以加入日志、诊断、崩溃恢复、资源缓存、包管理封装
   - 未来如果需要切到 RPC，也只改 sidecar，不直接冲击 Flutter 页面

### 备选路径：Flutter 直接对接 `pi --mode rpc`

这条路的优点：

- 更快验证端到端 prompt / event stream
- 不需要先做自己的 Node host
- 对 Dart 来说是天然的跨进程集成方式

问题也很明确：

- Flutter 端需要直接理解 `pi` RPC 命令和事件协议
- extension UI 子协议、session replacement、bash command、tool events 都会落到 Dart 层
- 以后想做产品域抽象时，UI 和底层协议容易耦合得过深

因此更适合作为：

- spike
- 验证链路
- sidecar 之前的短期桥接

不建议直接作为长期最终结构。

## 建议的宿主边界

`pi-host` sidecar 对 Flutter 暴露的，不应是 1:1 透传所有 `pi` SDK 细节，而应是更稳定的产品域接口，例如：

- session lifecycle
  - `createSession`
  - `resumeSession`
  - `forkSession`
  - `switchSession`
- conversation
  - `prompt`
  - `steer`
  - `followUp`
  - `abort`
- runtime state
  - `getState`
  - `getMessages`
  - `getSessionStats`
- model / auth
  - `listModels`
  - `setModel`
  - `setThinkingLevel`
  - `checkAuth`
- workspace/tooling
  - `bash`
  - tool event stream
  - command list / prompt template list / skill list
- extension UI bridge
  - dialogs
  - notifications
  - footer/widget state

也就是说，sidecar 应该是**产品适配层**，不是简单的 SDK 包装壳。

## 开发建议

### 第一阶段

先做 `pi-host` spike，证明这些链路打通：

- 启动 host
- 创建 session
- 发 prompt
- 收流式文本
- abort
- 切换 model
- 列 session / resume session

### 第二阶段

再把 Flutter 现有壳层对接到 host：

- composer -> prompt / steer / follow-up
- 聊天流视图
- tool execution timeline
- bash / file tool 输出面板

### 第三阶段

补完整产品能力：

- session tree / fork / clone / import/export
- settings -> model / thinking / auth / transport
- extensions / skills / commands / packages

## 验证 / 证据

- 文档：
  - `README.md`
  - `docs/sdk.md`
  - `docs/rpc.md`
  - `docs/extensions.md`
  - `docs/custom-provider.md`
  - `examples/sdk/README.md`
  - `examples/sdk/01-minimal.ts`
  - `examples/sdk/12-full-control.ts`
  - `examples/sdk/13-session-runtime.ts`
- 关键观察：
  - README 明确写了四种模式：interactive / print-or-json / RPC / SDK
  - `docs/sdk.md` 明确给出 `createAgentSession()`、`createAgentSessionRuntime()`、`runRpcMode()`
  - `docs/rpc.md` 明确给出 `pi --mode rpc` 的 JSONL 协议
  - 文档中未发现独立 app-server 产品形态

## 后续事项

- 主功能开发计划按 `docs/plans/2026-07-26-desktop-main-feature-roadmap.md` 推进
- 第一轮 `/goal` 建议绑定到 `pi-host spike + Flutter 对接最小闭环`
