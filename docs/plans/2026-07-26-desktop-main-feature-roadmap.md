# desktop 主功能开发路线图

- 任务：为 `desktop` 建立围绕 `pi` 的主功能开发任务链路，覆盖集成形态、runtime host、会话、流式输出、工具面板与打包交付
- 状态：草稿
- 负责人：Pi
- 日期：2026-07-26
- 依赖文档：
  - `docs/plans/2026-07-26-desktop-follow-up-roadmap.md`
  - `docs/solutions/2026-07-26-pi-integration-modes.md`

## 当前优先切片

在主功能链路正式进入 `pi-host` 之前，先处理一条更靠前的设置侧任务：

- `docs/plans/2026-07-26-desktop-pi-config-center.md`

这条任务的优先级高于 host spike 的直接 UI 接线，因为它先把 `pi` 的全局配置面收进 GUI：模型偏好、全局系统提示词、追加系统提示词，以及全局 `AGENTS.md`。

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
