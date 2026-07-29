# Session 生命周期与产品完整性审查

- 主题：在基线验收前，盘点 Pi App 的产品完整性缺口，并收敛“同一项目多会话”和原生 Pi session 生命周期的实现边界。
- 状态：收敛中，等待产品语义确认。
- 负责人：Pi
- 日期：2026-07-29
- 关联计划：
  - `docs/plans/2026-07-28-current-baseline-acceptance-plan.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`

## 背景

当前基线验收计划主要验证已经声明交付的能力，不能替代“产品是否覆盖真实用户会自然期待的工作流”的审查。用户明确指出：一个项目可能有多个 Pi session，且 session 的新建、切换、恢复、fork、重命名、归档和删除必须以官方 Pi 的真实能力为依据。

代码审查确认，当前 workspace 不是多会话工作区：它以项目 `sessionCwd` 为键，在 `desktop/lib/src/desktop_shell.dart` 的 `_sessionsByCwd` 中只保留一个 `WorkspaceSessionState`。首次提交创建 session，之后只复用该内存 session；应用重启、进程失败或项目切换不会形成可选择的 session catalog。`sessionFile` 虽被读取，但没有用于索引、恢复或切换。

因此，C1 不是“后续可选增强”，而是产品完成定义中连续 coding workflow 的必要能力。它仍是路线图中明确未交付的单元，不应混入当前已交付功能的回归统计；但必须在验收前被显式盘点、设计和排期。

## 目标

1. 在开始基线验收前完成一份可追溯的产品完整性清单，区分回归、明确未交付能力、死控件和待决策语义。
2. 以官方 Pi `--mode rpc` 的公开协议定义 session 行为，不把 Interactive TUI 或 SDK 私有能力误认为 production RPC contract。
3. 让每个项目可以承载多个独立 session，并确保 session 切换、fork、命名、归档与最终删除不会破坏 Pi 的 session 文件和上下文树。
4. 让所有显示为可点击的控件都有真实动作、禁用状态或明确的“尚不可用”解释，避免视觉完成度掩盖功能缺口。

## 当前事实盘点

| 区域 | 当前实际行为 | 判定 |
| --- | --- | --- |
| 项目内会话 | 每个 `sessionCwd` 只有一个内存 `WorkspaceSessionState`；后续 composer 提交复用同一个 `sessionId`。 | 已交付的最小单会话主链，不是多会话管理。 |
| 多项目并发 | transport 能同时维护多个 Pi process session；不同项目的 event 不应串流。 | 已交付的 transport 隔离，不等于用户可管理多个 session。 |
| 应用重启与 Pi process 退出 | session ID、消息和状态只在内存 map；失败后下一次提交创建新 session。 | C1/C2 未交付能力。 |
| 新建、恢复、切换、fork、clone、重命名 | UI 和 `PiHostClient` 都没有面向产品的入口或稳定方法。 | C1 未交付能力。 |
| 归档、删除 | 没有 UI、索引或 lifecycle contract。 | C1 未交付能力；删除另有原生 API 限制。 |
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
| 切换 / 恢复已知 session | `switch_session(sessionPath)` | `/resume` picker | `runtime.switchSession(path)` | 可以直接映射，但要求先有可信的 sessionPath 来源。 |
| 项目级列举全部历史 session | 无 | `/resume`、`pi -r` | `SessionManager.list(cwd)` | 不能仅凭 production RPC 实现官方全量 catalog。 |
| fork | `get_fork_messages`、`fork(entryId)` | `/fork` | `runtime.fork(entryId)` | 可以直接映射；成功后是 replacement session，旧绑定必须失效。 |
| clone | `clone` | `/clone` | `runtime.fork(entryId, { position: "at" })` | 可以直接映射；与 fork 的上下文语义不同，UI 不可合并为模糊的“复制”。 |
| 重命名 | `set_session_name(name)`、`get_state.sessionName` | `/name`、resume picker 中 rename | `appendSessionInfo(name)` | 可以直接映射；名称的真相源必须是 Pi session，不写竞争性的名称副本。 |
| 当前 session 历史 / 树 | `get_entries`、`get_tree`、`get_messages` | `/tree` | `SessionManager` tree API | 可用于当前 session 的只读显示；完整 tree navigator 应单独设计，不能假装是简单 transcript。 |
| 删除 | 无 | resume picker 的 Ctrl+D + confirm，尽力使用 `trash` CLI | 文档只描述 session 文件删除 | 不得宣称为 RPC 能力，当前不得在 Flutter 中直接 `unlink`、移动或编辑 JSONL。 |
| 归档 | 无 | 无 | 无 | 只能是 Pi App 私有 catalog 的隐藏状态，绝不能写入或改名 Pi session 文件，也不得称为 Pi 原生 archive。 |

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
- Pi App 自有的 catalog / archived / recent-used 数据只能存入 `~/.pi-app*` 对应 build-mode 数据根，不能混入 `~/.pi/agent`。
- 所有 project-local resources 继续遵循 `--no-approve`、tools 与 trust 分离的现有契约。
- native session replacement 成功后，必须保留承载 replacement 后 session 的同一 RPC process；使旧 product session identity / event generation / 本地绑定失效，重新以 `get_state` 绑定当前 native session，并拒绝属于旧 generation 的迟到 event。不得仅因 Pi session replacement 杀掉该 process。
- 未有正式 delete RPC 时，任何“删除”方案都必须先得到明确产品决策与单独的 native capability 证据；默认不实现。

## 备选方案

### 方案 1：Pi App 已知会话索引，公共 RPC 负责 lifecycle

- 概述：Pi App 只记录自己成功创建、切换或 fork 过的 `sessionPath`、project identity、最近使用时间和 app-owned archived flag；new/switch/fork/clone/rename 全部直接调用公开 RPC。
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

## 当前倾向

采用方案 1，并保留方案 3 作为未索引历史 session 的显式外部回退：

1. C1 首版必须支持一个项目中多个“Pi App 已知”的 session：新建、最近使用索引、切换、恢复、fork、clone 和 Pi 原生重命名。
2. 每次 lifecycle operation 成功后，立即用 `get_state` 获取新的 session file、Pi session identity、名称和状态；只有 Pi 返回 `cancelled: false` 时才切换 UI。
3. `归档`定义为 Pi App 私有的 catalog 过滤状态。它不影响 Pi CLI、JSONL 文件、session name 或其他客户端；UI 必须写成“从 Pi App 归档/恢复”，不能写成“Pi 已归档”。
4. 当前建议是不在 Pi App 中实现 session 文件删除，除非用户明确批准独立的 native/Trash 设计并完成能力证据，或官方公开 delete RPC 出现。这个建议尚未覆盖总看板现有的“删除入口”完成门槛，故 C1 delete 是阻断性待决策项，不能静默降级或假装已交付。
5. 如果产品要求首次就展示所有由 Pi CLI 创建的历史 session，不能悄悄采用方案 2；必须先增加上游可支持的 catalog protocol，或由用户明确接受经过独立安全设计的受控 discovery 方案。

### 与总看板的关系

本 brainstorm 不改变 `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md` 的唯一权威性。该总看板当前仍将“归档 / 删除入口”列入 C1；在用户确认 delete 语义、官方协议能力或单独 native/Trash 设计之前，C1 的 delete 门槛保持未解决。确认后必须先更新总看板和 C1 的具体计划，再开始实现，不能通过本 brainstorm 单方面移除该完成条件。

## 待确认问题

1. session catalog 的首版范围是否接受“Pi App 已知会话”，还是必须在首次打开项目时展示所有历史 Pi CLI session？后者目前没有公开 RPC 支持。
2. 是否接受“归档仅影响 Pi App 列表、不影响 Pi CLI”的语义？
3. 删除是否严格等待官方 delete RPC；还是要另立设计，研究用户明确确认后的系统 Trash 包装？当前倾向是前者。
4. “New task”是否应在 C1 后直接映射为 `new_session`，而 Scheduled/Plugins/Pull requests 应先移除或禁用，直到各自真实工作流存在？
5. 计划是否需要把“所有可点击控件必须有功能或禁用状态”升级为基线验收的通用阻断规则？当前倾向是需要。

## 下一步

1. 在 `docs/plans/2026-07-28-current-baseline-acceptance-plan.md` 增加 `ACC-0` 产品完整性与 Pi 原生 contract 审查门；ACC-A1 和后续基线验收只能在其结论与上述待确认语义记录后开始。
2. 完成 P1、I2 后，为 C1 单独新建具体执行计划，先做真实 authenticated session capability spike，再实现 product adapter、私有 catalog、session switcher 与回归。
3. 在 C1 实现前，单独收敛并处理已发现的死控件、静态 Tasks 披露、空导航和可访问性问题；不能让它们继续作为表面可用的控件进入验收。
4. C1 capability spike 的最低验证集合：真实 prompt 持久化、跨进程 resume、fork/clone 上下文差异、rename 持久化、extension cancel、session 文件失效、同时运行 session 的迟到 event 隔离，以及 archive 不影响 Pi CLI。
