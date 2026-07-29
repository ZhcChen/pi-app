# Session 生命周期与产品完整性审查

- 主题：在基线验收前，盘点 Pi App 的产品完整性缺口，并收敛“同一项目多会话”和原生 Pi session 生命周期的实现边界。
- 状态：已完成；ACC-0 审查结果见 `docs/solutions/2026-07-29-acc-0-product-integrity-audit.md`，C1 实施以 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md` 为准。
- 负责人：Pi
- 日期：2026-07-29
- 关联计划：
  - `docs/plans/2026-07-28-current-baseline-acceptance-plan.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`

## 背景

当前基线验收计划主要验证已经声明交付的能力，不能替代“产品是否覆盖真实用户会自然期待的工作流”的审查。用户明确指出：一个项目可能有多个 Pi session，且 session 的新建、切换、恢复、fork、重命名、归档和删除必须以官方 Pi 的真实能力为依据。

用户已确认核心原则：Pi CLI / Pi Core 是 session 的唯一真相源，Pi App 只能增强官方 workflow，不能成为第二个 session manager 或改变 Pi 的 session 所有权。C1 的实施计划据此固定为 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`。

代码审查确认，当前 workspace 不是多会话工作区：它以项目 `sessionCwd` 为键，在 `desktop/lib/src/desktop_shell.dart` 的 `_sessionsByCwd` 中最多维护当前 attach 的临时 `WorkspaceSessionState`。首次提交创建 session，之后只在当前选中项目内复用该内存 session；一旦切换到其他项目，就主动丢弃本地 transcript 与 session 绑定，不形成可恢复的项目级会话记录。`sessionFile` 虽被读取，但没有用于索引、恢复或切换。

因此，C1 不是“后续可选增强”，而是产品完成定义中连续 coding workflow 的必要能力。它仍是路线图中明确未交付的单元，不应混入当前已交付功能的回归统计；但必须在验收前被显式盘点、设计和排期。

## 目标

1. 在开始基线验收前完成一份可追溯的产品完整性清单，区分回归、明确未交付能力、死控件和待决策语义。
2. 以官方 Pi `--mode rpc` 的公开协议定义 session 行为，不把 Interactive TUI 或 SDK 私有能力误认为 production RPC contract。
3. 让每个项目可以承载多个独立 session，并确保新建、切换、fork、clone 和重命名只通过公开 Pi RPC 完成；Pi App 不改变 session 文件、上下文树或原生删除语义。
4. 让所有显示为可点击的控件都有真实动作、禁用状态或明确的“尚不可用”解释，避免视觉完成度掩盖功能缺口。

## 当前事实盘点

| 区域 | 当前实际行为 | 判定 |
| --- | --- | --- |
| 项目内会话 | 每个 `sessionCwd` 只有一个内存 `WorkspaceSessionState`；后续 composer 提交复用同一个 `sessionId`。 | 已交付的最小单会话主链，不是多会话管理。 |
| 多项目并发 | transport 能同时维护多个 Pi process session；不同项目的 event 不应串流。 | 已交付的 transport 隔离，不等于用户可管理多个 session。 |
| 应用重启与 Pi process 退出 | session ID、消息和状态只在内存 map；失败后下一次提交创建新 session。 | C1/C2 未交付能力。 |
| 新建、恢复、切换、fork、clone、重命名 | UI 和 `PiHostClient` 都没有面向产品的入口或稳定方法。 | C1 未交付能力。 |
| 归档、删除 | 没有 UI、索引或 lifecycle contract。 | C1 未交付能力；归档不属于 Pi 原生语义，删除必须回退 Pi CLI。 |
| 顶栏搜索 | 显示为可点击 `IconButton`，回调为空。 | 死控件，必须修复、禁用或移除。 |
| 侧栏下载 Pi core | 显示为可点击按钮，回调为空；I2 尚未实现。 | 死控件，不能伪装为 installer。 |
| 设置中的 Import work | 显示为可点击动作，回调为空。 | 死控件，必须明确产品语义或移除。 |
| New task / Scheduled / Plugins / Pull requests | 点击只改变高亮，画布不读取选择结果。 | 不完整导航表面，不能计为已交付功能。 |
| Tasks 披露行 | 只渲染右箭头，无点击、语义、内容或状态。 | 静态占位，不能称为可收缩分组。 |
| 项目管理可访问性 | 部分操作只在 hover/selected 时出现，尚无完整纯键盘、焦点顺序和读屏回归。 | 验收前必须审查的小型交互缺口。 |

## Pi 原生 session 能力矩阵

依据本机官方 Pi `0.82.0` 的 `docs/rpc.md`、`docs/sessions.md`、`docs/session-format.md`、`docs/sdk.md` 和已安装 RPC 实现，能力边界如下。

| 产品意图 | `pi --mode rpc` 公开协议 | Interactive TUI | SDK / 文件格式 | Pi App 结论 |
| --- | --- | --- | --- | --- |
| 新建 | `new_session` | `/new` | `runtime.newSession()` | 可以直接映射。必须处理 `cancelled`，并回读 `get_state`。 |
| 切换 / 恢复已知 session | `switch_session({ sessionPath })` | `/resume` picker | `runtime.switchSession(path)` | 可以直接映射，但持久化引用必须来自 Pi `get_state.sessionFile`，并仅将该值作为请求参数 `sessionPath` 传回 Pi。 |
| 项目级列举全部历史 session | 无 | `/resume`、`pi -r` | `SessionManager.list(cwd)` | 不能仅凭 production RPC 实现官方全量 catalog。 |
| fork | `get_fork_messages`、`fork(entryId)` | `/fork` | `runtime.fork(entryId)` | 可以直接映射；成功后是 replacement session，旧绑定必须失效。 |
| clone | `clone` | `/clone` | `runtime.fork(entryId, { position: "at" })` | 可以直接映射；与 fork 的上下文语义不同，UI 不可合并为模糊的“复制”。 |
| 重命名 | `set_session_name(name)`、`get_state.sessionName` | `/name`、resume picker 中 rename | `appendSessionInfo(name)` | 可以直接映射；名称的真相源必须是 Pi session，不写竞争性的名称副本。 |
| 当前 session 历史 / 树 | `get_entries`、`get_tree`、`get_messages` | `/tree` | `SessionManager` tree API | 可用于当前 session 的只读显示；完整 tree navigator 应单独设计，不能假装是简单 transcript。 |
| 删除 | 无 | resume picker 的 Ctrl+D + confirm，尽力使用 `trash` CLI | 文档只描述 session 文件删除 | Pi App 不实现；只打开 Pi CLI 原生管理入口，绝不在 Flutter 中直接 `unlink`、移动或编辑 JSONL。 |
| 归档 | 无 | 无 | 无 | C1 不提供 Pi 原生 archive；可选本地隐藏只能改变 Pi App 快捷方式，不能写入或改名 Pi session 文件。 |

Pi session 是带 `id`/`parentId` 的 append-only JSONL tree，其中还包含 compaction checkpoint、branch summary、model/thinking change、labels 和 extension state。Pi App 不得直接编辑、复制、迁移、重写、移动或永久删除这些 JSONL 文件；这样会破坏 Pi 的上下文构造、旧格式迁移和已经加载的 session manager 状态。

## 已完成的隔离 capability probe

在一次性临时 `HOME`、`PI_CODING_AGENT_DIR`、空项目和临时 session 目录中，使用 `/opt/homebrew/bin/pi` 运行无认证、无 prompt 的 `--mode rpc` probe。所有临时目录和进程均已清理，未读取日常 Pi auth/session，也未留下仓库文件。

确认项：

- `new_session`、`set_session_name`、`switch_session`、`get_fork_messages` 和 `clone` 都有公开 RPC command；无 active leaf 时 `clone` 按预期被拒绝。
- 未知的 `list_sessions` 与 `delete_session` command 返回 `Unknown command`，与官方 RPC 类型和实现一致。
- `new_session`、`switch_session`、`fork`、`clone` 都可能返回 `cancelled`，产品 adapter 不得在取消后更新可见 session。

未确认项：

- 在该无认证 probe 中，只有 direct `bash` entry 的 session 在进程关闭后没有按返回 `sessionFile` 落盘；因而无法用它判定真实 prompt session 的持久化、resume、name 和 entry 恢复语义。
- 这不是对 Pi 上游的 bug 结论。它是 C1 的阻断性 capability spike：必须在独立测试认证和临时项目中，以真实 prompt 创建 session 后验证跨进程 `switch_session`、session name、entries、fork/clone 与取消生命周期。

## 约束

- 生产 runtime 只能使用用户安装的官方 `pi --mode rpc`；不能将本机 SDK 的 `SessionManager.list()` 或 runtime API 变成 Pi App 的隐藏 production fallback。
- `PiHostClient` 继续是产品边界；widgets 不读取原始 Pi RPC record，且不负责 session JSONL 解析或写入。
- Pi App 自有的已知会话快捷方式、隐藏状态和最近使用数据只能存入 `~/.pi-app*` 对应 build-mode 数据根，不能混入 `~/.pi/agent`；它们不是 Pi 原生 catalog 的真相副本。
- 所有 project-local resources 继续遵循 `--no-approve`、tools 与 trust 分离的现有契约。
- native session replacement 成功后，必须保留承载 replacement 后 session 的同一 RPC process；使旧 product session identity / event generation / 本地绑定失效，重新以 `get_state` 绑定当前 native session，并拒绝属于旧 generation 的迟到 event。不得仅因 Pi session replacement 杀掉该 process。
- 未有正式 delete RPC 时，Pi App 不实现删除、Trash 包装或文件操作；用户通过可见 Terminal 中的 Pi CLI 原生会话管理流程删除 session。

## 备选方案

### 方案 1：Pi App 已知会话索引，公共 RPC 负责 lifecycle

- 概述：Pi App 只记录自己成功创建、切换或 fork 过的 `sessionFile`、project identity、最近使用时间和 `hiddenInPiApp`；new/switch/fork/clone/rename 全部直接调用公开 RPC。
- 优点：不解析或改写 Pi JSONL，不依赖 SDK，不把 TUI-only 行为伪装成 RPC；能稳定支持一个项目多个 Pi App 工作会话。
- 缺点：初版不会自动列出纯 CLI 创建、且从未被 Pi App 打开过的历史 session。
- 风险：session 文件丢失、cwd 不匹配或 Pi 上游 session replacement 语义变化时，需要可解释的失效状态和 refresh/reopen 流程。

### 方案 2：直接扫描、解析或修改 Pi session 文件建立全量 catalog

- 概述：Pi App 枚举 `~/.pi/agent/sessions/` 并自行读取 header/entries，甚至移动或删除 JSONL 来实现全量 list、rename、archive、delete。
- 优点：表面上能立即覆盖 CLI 已有历史 session。
- 缺点：违反 Pi core 对 session 文件的所有权，也绕过公开 RPC contract；版本迁移、compaction、branch 与 extension state 均会成为 Pi App 的兼容性负担。
- 风险：高。不得采用。

### 方案 3：只打开 Pi 原生 TUI 的 `/resume` 管理界面

- 概述：Pi App 不提供 session catalog，而是引导用户在 Terminal 中使用 `/resume`、Ctrl+D 等原生动作。
- 优点：删除完全遵循 Pi 的现有交互与 Trash 优先语义。
- 缺点：不能形成桌面 session workflow，无法满足 Pi App 的 C1 产品完成定义，也不能支持桌面内的项目 session 切换。
- 风险：作为“管理未索引的历史会话”的明确回退可接受，但不能替代 C1。

### 方案 4：等待 Pi 上游增加 session list / delete / archive RPC

- 概述：不实现 catalog/delete，直到官方协议提供版本化公开 command。
- 优点：最严格遵循 Pi core ownership。
- 缺点：会无限期阻塞完整多会话体验；archive 仍没有原生概念。
- 风险：可作为 delete 的前置，不应阻塞 new/resume/fork/rename 等已经公开的能力。

## 已确认的产品决策

用户已确认 Pi CLI / Pi Core 为唯一 session 真相源，Pi App 只能增强官方 workflow。由此确定：

1. C1 首版只支持一个项目中的多个“Pi App 已知会话快捷方式”：新建、最近打开、打开已知会话、fork、clone 和 Pi 原生重命名。
2. 每次 lifecycle operation 成功后，必须立即用 `get_state` 获取 Pi 返回的 session file、session identity、名称和状态；只有 Pi 返回 `cancelled: false` 且状态读取成功后才更新 UI 或本地快捷方式。
3. Pi App 本地只保存指向 Pi 原生 session 的不透明引用和 UI 元数据。它不是全量 Pi catalog，不能扫描或解析 Pi CLI 创建但从未被 Pi App 打开过的历史 session。
4. C1 不提供 Pi 原生 archive；可选“隐藏 Pi App 快捷方式”只影响本地列表，不能影响 Pi CLI、JSONL 文件、session name 或其他客户端。
5. C1 不提供 Pi App 内删除、Trash 包装或 session 文件操作。删除和未索引历史会话管理统一通过可见 Terminal 中的 Pi CLI `/resume` / `pi -r` 原生流程完成。
6. `New task` 只有在能够真实映射为 `new_session` 后才能保留；Scheduled、Plugins、Pull requests、Tasks 披露、Search、Import work 和 runtime download 等空操作表面必须在对应功能交付前移除、禁用或给出准确回退。
7. 所有可点击控件必须有真实功能、准确禁用状态或明确回退，键盘、Semantics 和窄窗口行为属于 ACC-0 的通用验收要求。

### 与总看板的关系

本 brainstorm 不改变 `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md` 的唯一权威性。C1 已由 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md` 细化：其完成门槛不再把 Pi App 内删除或全量 catalog 误写为可由当前 RPC 实现的能力，而是要求 Pi CLI handoff、已知会话快捷方式和官方 lifecycle 一致性。

## 尚待能力验证的事项

1. C1.0 必须在独立测试认证和隔离环境中验证真实 prompt session 的持久化、新 controller 的新建/打开不产生额外 Pi session、跨 process `switch_session`、rename 持久化、fork/clone source 与 derived session 的语义、取消、缺失 `sessionFile`、并发 controller 和迟到 event。
2. 如果 Pi 上游新增版本化的 `list_sessions` 或 delete RPC，必须先更新 capability matrix 和 C1.0 证据，再新增扩展执行单元；不能以当前的 SDK 或 TUI 行为倒推 production contract。
3. Pi CLI `/resume` / `pi -r` 的可见 Terminal handoff、cwd、退出和用户取消行为需要单独验证，但 Pi App 不读取其输出或选择结果。

## 下一步

1. 将本审查和 `docs/solutions/2026-07-29-acc-0-product-integrity-audit.md` 作为 ACC-0 的最终结果，后续验收直接从 `ACC-A` / `ACC-A1` 继续。
2. 按总路线图恢复 P1 为下一功能实现单元；若 `ACC-A1` 证实冷启动 runtime 为 S1，则先建立最小修复单元并暂停 P1 新实现。
3. C1.0 通过后，按 C1.1 至 C1.4 分别实现本地快捷方式模型、多 controller adapter、session workspace/Pi CLI handoff 和一致性验收。
4. C1 实现前不得重新引入 direct JSONL 操作、SDK session catalog、TUI 输出解析、Pi App 内删除或伪造原生 archive。
