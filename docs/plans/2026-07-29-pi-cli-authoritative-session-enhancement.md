# Pi CLI 权威的 Session 增强执行计划

- 任务：在不改变 Pi CLI / Pi Core session 所有权与生命周期的前提下，为 Pi App 提供项目内多会话工作区、已知会话快捷方式、原生 RPC 生命周期操作和 Pi CLI 管理回退。
- 状态：草稿，待 P1、I2 完成后执行；C1.0 真实 capability spike 还必须通过 ACC-A 环境隔离硬门并具备独立测试认证。
- 负责人：Pi
- 日期：2026-07-29
- 上位计划：`docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
- 前置审查：`docs/brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md`
- 验收覆盖：`docs/plans/2026-07-28-current-baseline-acceptance-plan.md`

## 核心决策

Pi CLI / Pi Core 是 session 的唯一真相源和唯一生命周期所有者。Pi App 是其桌面增强层，不是第二个 session manager。

因此必须遵守以下规则：

1. 所有会话创建、切换、fork、clone、重命名、树读取和导出只通过官方 `pi --mode rpc` 的公开 command 完成。
2. Pi App 不扫描、解析、复制、迁移、重写、移动、重命名或删除 Pi session JSONL。
3. Pi App 本地数据只保存“已知会话快捷方式”和纯 UI 元数据，不保存或竞争 Pi 原生 session 真相。
4. 公开 RPC 尚未提供的全量列举、删除和原生归档，不得通过 SDK、TUI 抓取、文件系统扫描或伪造 UI 补齐。
5. Pi CLI 的 `/resume` / `pi -r` 是未被 Pi App 知道的历史会话及原生删除的唯一回退入口；Pi App 只负责打开可见 Terminal，不解析或接管该 TUI。
6. Pi App 如需提供本地隐藏能力，只能命名为“隐藏 Pi App 快捷方式”或等价文案，不能称为 Pi 原生归档，也不得影响 Pi CLI、session 文件或其他 Pi 客户端。
7. 只有 Pi 上游新增版本化、公开的相关 RPC 后，Pi App 才能扩展全量 catalog 或图形化删除能力。

## 目标

完成 C1 后，用户可以在一个项目内同时打开多个 Pi 原生 session，并在 Pi App 中可靠完成：

- 新建会话。
- 打开 Pi App 已知的会话。
- 在不同会话 Tab 间切换，且可并发运行。
- fork、clone、Pi 原生重命名、查看当前 session tree/entries，以及导出官方支持的内容。
- 在应用重启、RPC process 退出、Pi CLI 外部删除 session 后得到准确且可恢复的状态。
- 将未索引历史会话和删除动作交还 Pi CLI 原生流程。

完成后，Pi App 创建或操作的 session 在 Pi CLI 中仍是原生 session；Pi CLI 对 session 所做的变更也不会被 Pi App 覆盖、重建或伪装。

## 术语与边界

| 名称 | 所有者 | 含义 | Pi App 是否可写 |
| --- | --- | --- | --- |
| Pi 原生 session | Pi CLI / Pi Core | session file、session ID、名称、entries、tree、fork/clone 结果和删除语义。 | 仅通过官方 RPC command；禁止文件操作。 |
| 已知会话快捷方式 | Pi App | 指向 Pi 原生 session 的本地引用，用于最近打开、置顶和本地隐藏。 | 可以写入 Pi App 数据根。 |
| 会话 Tab / controller | Pi App | 一个已打开的 UI 工作区与其 RPC process、event generation、请求和运行状态。 | 仅管理 process 与视图状态。 |
| 全量 Pi session catalog | Pi CLI / Pi Core | 当前项目的全部历史 session，包括未曾由 Pi App 打开的会话。 | 当前公开 RPC 不支持，Pi App 不实现。 |

`PiSessionReference` 只应保存下列最小数据：

- 稳定的 Pi App project identity 与项目 cwd。
- 从 Pi `get_state` 返回的 `sessionFile`，作为不透明引用保存；打开时仅将它作为 `switch_session` 请求中的 `sessionPath` 参数传回 Pi，不打开或解析文件。
- 最后一次由 Pi 返回的 `sessionId`、session name 和可选状态摘要，仅作显示缓存。
- `lastOpenedAt`、`pinned`、`hiddenInPiApp` 等纯 UI 元数据。

本地引用失效时，Pi App 只能显示“会话不可用”并提供重新打开或移除本地快捷方式；不得检查、修复或删除其所指向的 Pi 文件。

## 范围

- 为一个项目建立多个 Pi App 已知会话的本地快捷方式和 Tab。
- 将 Pi 公开 `new_session`、`switch_session`、`fork`、`clone`、`set_session_name`、`get_entries`、`get_tree`、`get_session_stats`、`export_html` 等能力规约为稳定 Dart 产品接口。
- 建立每个已打开 session 的 process ownership、generation isolation、abort 和 process-exit 行为。
- 为 Pi App 已知会话提供新建、打开、fork、clone、重命名、隐藏快捷方式和 Pi CLI 管理入口。
- 清理或禁用与真实 workflow 不匹配的会话/导航控件，尤其是 `New task`、Tasks 披露和无实际内容的 primary navigation。
- 在隔离测试环境中验证 Pi 原生 session 与 Pi App 引用之间的一致性。

## 非目标

- 不枚举、扫描或显示所有仅由 Pi CLI 创建且未被 Pi App 打开过的历史 session。
- 不使用 SDK `SessionManager.list()`、TUI 文本解析或 session JSONL 构建全量 catalog。
- 不实现 Pi App 内的 session 文件删除、移动、Trash 包装或永久删除。
- 不提供名称为“归档”的 Pi 原生 lifecycle action；本地隐藏不改变 Pi。
- 不替换 Pi CLI 的 `/resume`、删除确认、Trash 策略、session format migration 或 compaction 语义。
- 不在 C1 中实现 C2 的 steer/follow-up/retry 运行控制、O1 工具 timeline 或 O2 文件变更摘要。

## 产品交互契约

| 用户意图 | Pi App 动作 | Pi Core 动作 | 成功后的 Pi App 状态 |
| --- | --- | --- | --- |
| 新建会话 | C1.0 先确认新 controller 的官方初始 session 语义：若启动即由 Pi 创建一个可用新 session，则直接以 `get_state` 绑定；只有在验证不会额外留下初始 session 时才发送 `new_session`。 | 创建 Pi 原生 session。 | 恰好创建一个用户请求的原生 session 后，才新建 Tab 与已知会话快捷方式。 |
| 打开已知会话 | C1.0 先选定经过证实的无孤儿 session 启动路径：优先验证官方 `pi --mode rpc --session <sessionFile>`；只有在证明新 controller 再发送 `switch_session({ sessionPath: sessionFile })` 不会留下未请求的初始 session 时，才可使用该回退路径。 | 校验并加载原生 session。 | 只有 `cancelled: false` 且 `get_state` 成功后才创建/更新 Tab。 |
| 切换会话 Tab | 切换当前 Pi App controller。 | 不发送 session replacement command。 | 保留各 Tab 的独立 process 与运行状态。 |
| fork / clone | 优先在独立 controller 中先发送 `switch_session({ sessionPath: sourceSessionFile })` 并以 `get_state` 确认源会话，再执行官方 lifecycle operation；该顺序必须先由 C1.0 证明。 | 创建 replacement/derived Pi session。 | 成功后由同一 controller 返回的 `get_state` 绑定新的 Tab/快捷方式；若该策略不受 Pi 支持，则按已验证的当前 Tab replacement 语义处理，不伪装为保留源 Tab 的复制。 |
| 重命名 | 调用 `set_session_name`，随后 `get_state`。 | 写入 Pi 原生 session 名称。 | 只用 Pi 返回的名称更新显示缓存。 |
| 查看 tree / entries | 调用 `get_tree` / `get_entries`。 | 返回当前原生 session 数据。 | 只读显示，不重写 transcript 或 tree。 |
| 隐藏快捷方式 | 写入 Pi App 本地 `hiddenInPiApp`。 | 无。 | 仅本地列表变化，UI 文案不使用“Pi 已归档”。 |
| 删除 session | 打开可见 Terminal 中的 Pi 原生会话管理入口。 | 由 Pi CLI TUI 执行确认和可用的 Trash 行为。 | Pi App 不接收或伪造删除结果；后续打开失败时显示失效引用。 |
| 管理未索引历史会话 | 打开可见 Terminal 中的 `pi -r` / Pi 原生流程。 | Pi CLI 列举和管理自己的 session。 | Pi App 不抓取列表或选择结果。 |

## Process Ownership 与 Event Isolation

1. 每个已打开的 Pi App session Tab 应拥有一个独立的 `PiCoreRpcClient` process instance。process、stdout/stderr、pending request、abort、timeout、exit callback 和 event generation 必须按 Tab 隔离。
2. 打开已知 session 默认创建新的 controller，但 C1.0 必须先证明不会产生未请求的 Pi 原生 session：优先使用经验证的官方 `--session <sessionFile>` 启动路径；若改用新 controller 后的 `switch_session({ sessionPath: sessionFile })`，必须有真实证据证明其不会留下初始孤儿 session。无证据时不得实现打开已知会话。
3. `fork` / `clone` 的 C1.0 必须在以下两种策略中选定有证据的一种：
   - 优先策略：独立 controller 先以源 `sessionFile` 调用 `switch_session`，读取匹配源 identity 的 `get_state`，再执行 fork/clone；成功后承载 replacement/derived session 的同一 controller 升格为新 Tab，源 Tab 不变。
   - 回退策略：若 Pi 不允许上述并发源加载，则在源 Tab 的 controller 中执行 replacement；UI 必须事先明确该动作会替换当前 Tab，且不得伪装为保留原 Tab 的“复制”。
4. 任何 native session replacement 成功后，承载 replacement 的同一 RPC process 必须继续存活。Pi App 使旧 product session identity、event generation 与本地绑定失效，再调用 `get_state` 建立新绑定，并拒绝旧 generation 的迟到 event。
5. 关闭 Tab 只终止 Pi App 启动的 RPC process；不删除或改写 Pi 原生 session。重新打开必须重新通过 Pi 官方 command 验证引用。
6. Pi CLI 在 App 外部删除、移动或失效某个 session 时，Pi App 以官方 command 的错误为准，将快捷方式标为不可用；用户只能移除本地快捷方式或转入 Pi CLI 管理。

## 阶段拆分

### 阶段 C1.0：隔离的 Pi 原生 Lifecycle Capability Spike

- 目标：在真实、隔离、独立认证的 Pi 环境中确认本计划依赖的公开 RPC 行为与 process ownership。
- 边界：不改 production UI、不读写日常 Pi 数据、不提交真实 prompt/event JSONL。
- 验收重点：真实 prompt session 的持久化、新 controller 新建会话恰好创建一个 Pi 原生 session、跨 process `switch_session`、经官方 `--session` 或等价路径打开已知 session 时不产生孤儿 session、rename 持久化、独立 controller 先加载源 `sessionFile` 后 fork/clone 的可行性与 source/derived 语义、cancel、missing sessionFile、并发 controller 与迟到 event。

### 阶段 C1.1：稳定产品引用模型与持久化

- 目标：以 Pi App 自有数据根保存 `PiSessionReference`，替换“每个 cwd 一个内存 session”的数据模型。
- 边界：本地记录仅是快捷方式，不成为 Pi session 真相，不读取 Pi session file。
- 验收重点：重启后引用可见；所有真实打开操作重新交由 Pi 验证；Debug/Profile 与 Release 数据根仍隔离。

### 阶段 C1.2：多 Tab RPC Controller 与原生 Lifecycle Adapter

- 目标：扩展稳定 `PiHostClient` 产品接口，并为每个打开 session 建立隔离 controller/process。
- 边界：不让 widgets 读取 raw RPC；不重新引入 bundled SDK 或旧 Node host。
- 验收重点：new/open/fork/clone/rename 成功、取消、错误和 late event 都不串流；replacement process 不被误杀。

### 阶段 C1.3：Session Workspace 与 Pi CLI 回退

- 目标：在已选项目中提供会话列表、Tab、真实 action 和未索引/删除的 Pi CLI handoff。
- 边界：不恢复旧静态项目概览；无真实行为的 Search、Tasks、Import work、导航项必须移除、禁用或实现。
- 验收重点：Tab/Enter/Space、Semantics、窄窗口、中文/英文和深浅色下所有可见控件均有真实动作或准确禁用状态。

### 阶段 C1.4：回归、兼容与交付证据

- 目标：证明 Pi App 是 Pi CLI 的增强层，而非第二个 session manager。
- 边界：真实测试仍遵循环境隔离硬门；不使用日常认证或 session。
- 验收重点：Pi App 创建/重命名/fork 的 session 与 Pi CLI 一致，Pi CLI 删除后 Pi App 不重建或覆盖数据，本地隐藏不影响 Pi CLI。

## 执行单元

### C1.0：真实 Pi Lifecycle Capability Spike

- 所属阶段：C1.0。
- 涉及文件 / 模块：`desktop/tool/`、隔离测试启动器、受控临时项目、`docs/solutions/`。
- 前置依赖：P1、I2、ACC-A 环境隔离硬门和独立测试认证。
- 验证方式：用临时 `HOME`、`PI_CODING_AGENT_DIR`、Pi App 数据根和项目运行真实无敏感 prompt；记录脱敏结果与命令摘要。
- 完成标准：每项公开 lifecycle command 的 request/response、取消、跨 process 结果、打开已知会话的无孤儿 session 启动路径、fork/clone controller 策略和残余风险有版本化证据；若任一关键语义不稳定，先修改本计划，不进入 C1.1。

### C1.1：PiSessionReference 与 Project Session Registry

- 所属阶段：C1.1。
- 涉及文件 / 模块：`desktop/lib/src/app_models.dart`、`app_persistence.dart`、`project_registry_store.dart`、`desktop_shell.dart`、对应测试。
- 前置依赖：C1.0 的 session identity、sessionFile 与 persistence 证据。
- 验证方式：临时 Pi App 数据根中的持久化测试、项目 A/B 隔离、损坏引用、重启、Debug/Profile 与 Release 路径隔离。
- 完成标准：本地数据只包含快捷方式字段；不存在 session JSONL 读取/写入逻辑；过期引用不会被自动修复为新 session。

### C1.2：Native Lifecycle Adapter 与 Multi-Controller Ownership

- 所属阶段：C1.2。
- 涉及文件 / 模块：`desktop/lib/src/pi_host_client.dart`、`pi_core_rpc_client.dart`、`desktop_shell.dart`、memory fake、client/widget tests。
- 前置依赖：C1.0、C1.1。
- 验证方式：fake 覆盖成功、取消、未知 path、process exit、旧 generation event、并发 Tab、abort；隔离真实 Pi 覆盖关键 lifecycle。
- 完成标准：每个 Tab 的 process 与事件严格隔离；所有状态切换先以 Pi `get_state` 确认；没有 SDK 或 raw RPC 泄漏到 widgets。

### C1.3：Session Switcher、Tabs 与 Native Handoff

- 所属阶段：C1.3。
- 涉及文件 / 模块：`desktop/lib/src/workspace_view.dart`、`workspace_components.dart`、`workspace_feature.dart`、`app_copy.dart`、macOS Terminal/open bridge、widget tests。
- 前置依赖：C1.1、C1.2。
- 验证方式：鼠标、Tab/Enter/Space、Semantics、窄窗口、中文/英文、深浅色、无项目、无快捷方式、失效快捷方式、并发运行和 Terminal handoff。
- 完成标准：每个会话/导航控件有真实行为、准确禁用或被移除；未索引历史与删除操作明确进入 Pi CLI，不产生假删除/假全量列表。

### C1.4：Pi CLI 一致性与回归验收

- 所属阶段：C1.4。
- 涉及文件 / 模块：`desktop/test/`、`desktop/tool/`、验收报告、`docs/solutions/`。
- 前置依赖：C1.3、ACC-A 环境隔离硬门。
- 验证方式：Pi App 创建/重命名/fork 后在 Pi CLI 原生管理界面验证；Pi CLI 外部变更/删除后测试 Pi App 引用；完整静态、unit/widget、macOS build 与隔离真实 smoke。
- 完成标准：Pi App 从不改变 Pi session 文件所有权；全部测试和手工证据通过或明确标注外部阻塞；将真实结论写入 solution 文档。

## `/goal` 建议作用域

不得将整个 C1 作为单个 `/goal`。推荐顺序：

1. `/goal C1.0`：只完成真实 Pi lifecycle capability spike 与证据，不改 production UI。
2. `/goal C1.1`：只完成本地快捷方式模型、持久化和迁移。
3. `/goal C1.2`：只完成 adapter、多 controller/process ownership 和回归。
4. `/goal C1.3`：只完成 session UI、死控件收敛和 Pi CLI handoff。
5. `/goal C1.4`：只完成 Pi CLI 一致性验收、文档沉淀和残余风险。

## 验证方式

### 自动化

- `cd desktop && dart format --set-exit-if-changed lib test tool`
- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`
- `cd desktop && ./scripts/verify-macos-app-identity.sh --configuration debug`
- 仅在隔离硬门与独立认证满足后，运行新增的脱敏真实 Pi lifecycle smoke。

### 必需手工证据

1. Pi App 新建的 session 可在 Pi CLI 原生 `/resume` 中看到。
2. Pi App 对已知 session 的重命名在 Pi CLI 中一致。
3. Pi App fork/clone 后，源会话和派生会话的原生上下文符合 C1.0 的实测语义。
4. 在 Pi CLI 中删除 session 后，Pi App 只显示失效快捷方式，不修改或创建任何 Pi 文件。
5. Pi App 隐藏快捷方式不会改变 Pi CLI 列表、session name 或其他 Pi 客户端状态。
6. 多个项目和多个 Tab 的 transcript、工具事件、abort、错误与 process exit 不串流。

## 风险与待确认事项

1. 当前官方 RPC 没有全量 `list_sessions`、delete 或 native archive。C1 不得把未支持能力写成已交付；全量 catalog 必须等待上游公开 contract。
2. `fork` / `clone` 是否能在独立 controller 中安全保留 source session，必须由 C1.0 真实验证决定；未证明前不能承诺“复制后保留原 Tab”。
3. Pi CLI 的 `/resume` TUI 在 Terminal 的启动、cwd、可见性和退出行为需要单独测试；Pi App 不解析其内容。
4. 本地 `sessionFile` 引用可能因用户在 Pi CLI 中删除、移动或迁移 session 而失效。失效处理只能是 Pi 命令失败后的可解释 UI，不能自行文件修复。
5. 新 RPC controller 的初始启动语义必须先验证。新建会话不得因启动和 `new_session` 的组合创建两个 session；打开已知会话时，若 `--session <sessionFile>` 不适用于 RPC mode，而 `switch_session` 会留下初始孤儿 session，则该路径不可采用，必须等待官方无副作用启动 contract 或调整产品交互，不能由 Pi App 删除这些 session 作为清理。
6. 全量 catalog、图形化删除或更深的 native metadata 需要上游 API 设计。建议向 Pi 上游提出只读 list 与可确认 delete 的版本化 RPC 请求，而不是在 Pi App 逆向实现。

## 沉淀跟进

- C1.0 完成后，在 `docs/solutions/` 记录 Pi CLI 版本、公开 lifecycle contract、真实验证命令、证据摘要与残余风险。
- C1.4 完成后，记录 Pi App 快捷方式模型、process generation 策略、Pi CLI handoff 和删除/隐藏边界。
- 若 Pi 上游新增 session catalog 或 delete RPC，先更新 C1.0 capability matrix，再新增后续执行单元，不 retroactively 修改本计划的已验证边界。
