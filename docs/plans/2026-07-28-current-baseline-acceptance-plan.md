# 当前交付基线验收计划

- 任务：对当前 Pi App 已声明交付的能力做分层验收，建立可复现缺陷清单与修复优先级；ACC-0 是继续 P1 新实现前的当前质量门，后续 ACC-A 至 ACC-E 是持续执行的基线验证活动。
- 状态：草稿；必须先完成 ACC-0 产品完整性与 Pi 原生 contract 审查，再进入后续验收执行。
- 负责人：Pi
- 日期：2026-07-28
- 验收基线：`995da58 feat: 支持项目列表展开收起`
- 产品版本基线：`desktop/pubspec.yaml` 中的 `0.1.0+1`
- 适用平台：macOS；Windows、Linux 不在本轮验收范围。
- 上位计划：[Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md)

## 目标

本计划完成后，当前基线中的每一项已声明能力都必须有明确结论：`通过`、`失败`、`受外部条件阻塞` 或 `不适用`。每个失败项必须有最小复现步骤、预期与实际结果、影响范围、严重度、证据位置和后续修复单元。

在 ACC-A 之前，必须执行 ACC-0 产品完整性与 Pi 原生 contract 审查。它不验收未实现路线图能力是否“通过”，而是枚举真实用户路径、可见空操作控件、明确未交付能力与需要产品决策的语义；其中项目多 session、session lifecycle、archive/delete、键盘与小型披露交互必须单列。

本轮不是对“完整日常 coding workflow”做发布签字。当前路线图中 P1 的授权/修复 UI、I2 installer、C1 Pi CLI 权威的已知会话快捷方式、C2 运行恢复、O1/O2 timeline 与变更摘要，以及 P4/P5 功能尚未交付；它们必须作为产品缺口单列，不得被混入已交付能力的回归缺陷统计。

## 范围

- 验收 R1、R2、I1 已声明完成的 production direct RPC、Pi runtime 发现/诊断、协议边界和工具策略安全基线。
- 先执行产品完整性审查，覆盖同项目多 session、Pi 原生 session contract、死控件、导航占位、披露控件、键盘/读屏和最小窗口；审查证据见 `docs/brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md`，C1 的实施边界见 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`。
- 验收当前可见的项目管理、侧栏、composer、单项目会话展示、设置与偏好、错误反馈和中英文/主题等已实现桌面行为。
- 验收 Pi App 自有数据的 Debug/Profile 与 Release 隔离、macOS 应用身份、Debug/Release 构建产物和已实现的更新客户端状态机。
- 使用受控 fake runtime 覆盖确定性故障路径；仅在一次性 macOS 测试用户或已验证会向所有子进程注入隔离环境的测试启动器中，使用官方 Pi core 覆盖真实 RPC 主链。
- 建立脱敏的验收报告、缺陷台账和每项证据链接；修复只在验收结果确认后按单个缺陷闭环单独开始。

## 非目标

- 不在本计划中实现尚未交付的 P1/I2/C1/C2/O1/O2/M1/M2/S1/W1/E1/Q1/D1/D2 功能。
- 不把缺少 Pi App 已知会话快捷方式、打开/恢复、fork、官方安装器、完整工具 timeline 或首个 GitHub Release 标为“已交付回归”。它们应在报告中标为路线图缺口及其所属执行单元。
- 不在用户真实项目、真实 Pi session 或认证目录上进行具有副作用的 `bash`、`edit`、`write` 验证；真实 Pi 测试只使用临时项目和无敏感内容 prompt。
- 不使用继承自日常用户环境的 `HOME`、`PI_CODING_AGENT_DIR`、Pi 认证或 Pi session 执行真实 Pi smoke；不复制日常认证到测试目录。没有独立测试认证时，真实认证 smoke 必须标为外部条件阻塞。
- 不在未完成 P0-P3 与 Q1 前创建正式 tag、发布 GitHub Release 或声称可以完成 D1 发布验收。

## 验收规则

### 结果状态

| 状态 | 含义 |
| --- | --- |
| 通过 | 自动化检查通过，且本项需要的手工/真实运行证据已记录。 |
| 失败 | 预期行为可稳定复现地不成立，已创建缺陷记录。 |
| 受外部条件阻塞 | 需要用户认证、干净 macOS 环境、GitHub Release 或可见 Finder/Dock 等当前环境无法提供的条件；必须记录已完成的替代证据和缺失条件。 |
| 不适用 | 能力明确属于未开始或进行中的路线图单元，附上对应计划 ID；不得计入回归失败。 |

### 缺陷严重度

| 等级 | 判定标准 | 处理顺序 |
| --- | --- | --- |
| S0 | 数据丢失、权限静默扩大、认证/敏感信息泄露、生产路径错误使用旧 host、无法创建 direct RPC session，或跨项目串流。 | 停止后续功能开发，先修复。 |
| S1 | 核心已交付路径无法完成、错误状态不可恢复、runtime 诊断误导用户、项目/偏好持久化损坏、abort 后无法继续工作。 | 在继续 P1 前修复。 |
| S2 | 有明确可行绕过的功能错误、跨重启状态不一致、设置或视觉交互明显影响使用。 | 纳入紧邻修复批次。 |
| S3 | 文案、视觉、可访问性或低频边界问题，不影响数据、安全与主流程。 | 记录并按影响排期。 |

### 证据要求

- 每个用例记录基线 commit、Pi App build、Pi core 报告版本、运行环境、测试时间与执行人。
- 自动化用例记录命令、退出码与关键输出摘要；真实 Pi JSONL、认证信息、完整 prompt、路径中的个人信息不得提交。
- 手工 UI 用例记录截图或录屏、点击路径、预期与实际结果；含敏感信息的截图只保留本地受控位置，不进入 Git。
- 真实 Pi 用例必须记录隔离账户或测试启动器传入的 `HOME`、`PI_CODING_AGENT_DIR`、项目目录与 Pi App 数据目录；只记录目录清单和哈希/存在性，不记录认证或 session 内容。
- 缺陷编号格式使用 `ACC-<域>-<序号>`；修复后必须附回归命令和复验结果。

### 环境隔离硬门

ACC-A 在任何会启动进程的 fake、runtime health、真实 RPC、Pi config 或打包 app 用例之前，必须确认以下条件；否则只能做不触碰 Pi core 数据的静态/内存测试：

1. 原生 app 手工验收使用一次性 macOS 测试用户；不能通过在日常用户桌面直接运行应用来声称 Pi core 数据已隔离。
2. 命令行 fake、runtime health 和真实 smoke 使用统一测试启动器。该启动器必须显式向每个 Pi 子进程和配置服务传入隔离的 `HOME`、`PI_CODING_AGENT_DIR`、临时项目与 Pi App 数据目录；当前 `PiCoreRpcClient` 默认进程启动会继承宿主环境，尚不能单独满足此条件。
3. 测试认证只能由用户在该隔离环境中显式配置；不得复制、导出或读取日常认证。没有测试认证时，ACC-RPC-01/02 与 ACC-POL-02 标为“受外部条件阻塞”。
4. 执行前后都检查目录清单、活动进程和临时项目；确认无日常数据目录变更、无残留 Pi 进程和无残留临时认证/项目后才销毁夹具。

未通过此硬门时，不得执行会启动官方 Pi 的真实测试。

## 影响区域

- `desktop/lib/src/desktop_shell.dart`：应用启动、偏好加载、runtime 同步、项目与会话状态。
- `desktop/lib/src/pi_core_runtime.dart`：runtime 发现、health、路径优先级与状态机。
- `desktop/lib/src/pi_core_rpc_client.dart`：direct RPC、JSONL、进程隔离、工具与事件映射。
- `desktop/lib/src/workspace_*.dart`：侧栏、项目管理、composer、会话展示与错误反馈。
- `desktop/lib/src/settings_*.dart`、`app_preferences.dart`、`app_persistence.dart`、`project_registry_store.dart`：设置、偏好、项目和数据根。
- `desktop/lib/src/app_update_service.dart`、`desktop/macos/`、`desktop/scripts/`：更新、构建和 macOS 身份。
- `desktop/test/`、`desktop/tool/`：自动化基线、受控 fake 和真实 smoke。

## 验收矩阵

| ID | 域 | 场景与操作 | 通过条件 | 证据类型 |
| --- | --- | --- | --- | --- |
| ACC-0 | 产品完整性与原生 contract | 对照当前代码、路线图、官方 Pi RPC/TUI/SDK 文档，盘点多 session、生命周期、死控件、小型交互、可访问性和未交付功能；逐项检查 Tasks、Projects toggle、收起状态的 `+`、项目打开/管理、顶栏 search、runtime download、Import work 和四个 primary action 的鼠标、Tab/Enter/Space、Semantics 与窄窗口行为。 | 每项归为已交付回归、明确未交付、死控件/误导表面、外部协议缺口或待产品决策；C1 必须遵守 Pi CLI 唯一 session 真相源、仅保存 Pi App 已知会话快捷方式、全量历史/删除回退 Pi CLI 的已确认边界；固定输出 `C1 = 明确未交付（不计回归）` 与 `产品完整性/发布资格 = 未通过`。 | 只读审查 + 隔离 capability probe + 独立复核 |
| ACC-RT-01 | 冷启动诊断 | 在默认路径、已保存路径和 `PI_CORE_EXECUTABLE` 三种情况下启动应用并打开设置。 | runtime 自动从 `Checking` 转为 `ready`、`missing`、`invalidExecutable` 或 `healthCheckFailed`；不要求用户先手动刷新。 | widget + fake runtime + macOS 手工 |
| ACC-RT-02 | runtime 修复 | 分别提供不存在路径、不可执行文件、RPC health 失败文件和健康 fake。 | 状态、来源、绝对路径、诊断文案和刷新/选择/清除操作准确且可恢复。 | client/widget + fake runtime |
| ACC-RT-03 | 路径优先级 | 同时设置环境 override、保存路径和 PATH；切换路径时保持一个既有会话运行。 | 优先级为环境 override、保存绝对路径、PATH；只影响后续 session，不中断或串流既有会话。 | fake runtime + 手工 |
| ACC-RPC-01 | 真实主链 | 在一次性 macOS 测试用户或经统一隔离启动器创建的临时 Git 项目中，使用官方 Pi core 发出无敏感、低副作用 prompt。 | `get_state`、创建 session、文本流、`agent_settled` 和用户可见完成状态均成立；生产路径未启动旧 Node host。无独立测试认证则标为外部阻塞。 | 官方 Pi smoke + 进程观察 |
| ACC-RPC-02 | abort 与进程恢复 | 使用可控长运行 fake 和官方 Pi 各执行一次 abort；再提交新 prompt。 | 中止状态清晰、无残留运行/工具状态；后续 prompt 可创建可用 session。 | fake + 官方 Pi |
| ACC-RPC-03 | 隔离与协议容错 | A/B 两项目并发；分别注入 malformed JSON、CRLF、超过 1 MiB、无关 response 和进程退出。 | 一个 session 的异常不会污染另一项目/另一 session；协议失败可解释且可恢复。 | client/widget + fake runtime |
| ACC-POL-01 | 权限迁移 | 用新配置、无 `toolPolicyVersion` 配置和显式受限配置各创建一次 session。 | 新配置使用完整 builtin allowlist 且带 `--no-approve`；历史或受限配置不被静默扩大；偏好加载前保持 `--no-tools`。 | launch-argument fake + widget |
| ACC-POL-02 | tools / trust 边界 | 在未 trust 的隔离 fixture 项目中测试完整 builtin tools 与 project-local resource。 | 不把 allowlist 表示成 sandbox 或 trust；项目资源不因工具默认启用而自动获得执行权限。没有独立测试认证则标为外部阻塞。 | 官方 Pi fixture |
| ACC-PRJ-01 | 项目 registry | 添加 A/B、重复添加、别名、置顶、移除、选择并重启。 | 不重复、不删除用户项目文件；顺序、别名、置顶和选择的范围符合已声明语义。 | widget + 临时目录 + 手工 |
| ACC-PRJ-02 | 侧栏交互 | 收起/展开项目、在收起状态按 `+` 添加、窄窗口、键盘焦点和中英文切换；逐项检查 Projects toggle、Tasks 披露、收起状态的 `+`、项目打开/管理入口。 | 项目列表可预测显示；`+` 不误触收起；项目标题有 expanded/collapsed 语义；关键入口的鼠标、Tab/Enter/Space 和 Semantics 结论明确；无重叠或裁切，未交付入口必须禁用或移除。 | widget + macOS 手工 |
| ACC-WS-01 | composer 输入 | 无项目、空 prompt、有效 prompt、Pi 未 ready 各提交一次。 | 不创建无效进程；每个拒绝都有可操作反馈；有效 prompt 显示用户输入、流式正文和完成状态。 | fake + 官方 Pi |
| ACC-WS-02 | 项目会话边界 | 在 A 运行后切至 B，再返回 A；分别制造工具失败和进程错误。 | transcript、运行状态、工具事件和错误不跨项目泄漏；当前产品未实现跨重启 resume 时必须如实表现为内存会话。 | widget + fake/官方 Pi |
| ACC-SET-01 | 一般偏好 | 修改语言、主题、字号、密度、打开方式、休眠、菜单栏和建议提示后重启。 | 设置即时生效或按文案声明生效；持久化正确；不改写 Pi core auth/session/resources。 | widget + 文件系统隔离 + 手工 |
| ACC-SET-02 | Pi config | 读取、修改、保存与解析错误 Pi config fixture。 | 只写入用户明确操作的配置文件；失败不破坏原内容；不展示认证 secret。 | fake 文件系统 + widget |
| ACC-ISO-01 | 数据根 | 在隔离用户环境分别运行 Debug/Profile 和 Release。 | 前者仅使用 `~/.pi-app-dev`，后者仅使用 `~/.pi-app`；不自动迁移、复制或删除数据，且不影响 `~/.pi`。 | 打包 app + 文件检查 |
| ACC-ISO-02 | 原生身份 | 将 `Pi App Dev.app` 和 `Pi App.app` 放在同一目录/Applications 并同时运行。 | Finder、Dock、菜单栏、Bundle ID、图标和数据根分别正确；注意排除 macOS 图标缓存影响。 | 真实 macOS 手工 |
| ACC-REL-01 | 构建产物 | 构建 Debug 与 universal Release，运行 identity、签名和 DMG 校验。 | Debug/Profile 与 Release identity 不混淆；Release 包符合既有 ad-hoc 规则与双架构要求。 | 构建脚本 + 产物检查 |
| ACC-REL-02 | 更新客户端 | 使用本地/fixture GitHub 响应测试检查、下载、DMG 打开失败和退出状态。 | URL/asset 白名单、下载目录、失败不退出和用户手工安装语义正确。 | unit/widget + fake HTTP |

## 已知候选缺陷与路线图缺口

### 候选缺陷：ACC-RT-01 冷启动 runtime 未触发检测

代码审阅显示，`PiDesktopApp.initState()` 调用 `_syncRuntime()`，而 `_syncRuntime()` 当前只调用 `PiCoreRuntimeController.configure()`，不调用 `refresh()`。当保存路径未变化时，`configure()` 提前返回，runtime snapshot 保持 `checking`；现有 widget 测试也先断言 `Checking`，再通过手动刷新得到 `Ready`。

- 当前判定：候选 S1，必须先用 fake runtime 和实际冷启动复现。
- 不在本计划中直接修复：确认失败后创建独立修复单元，补冷启动自动检测和回归测试。
- 相关文件：`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/pi_core_runtime.dart`、`desktop/test/widget_test.dart`。

### 已知未交付能力

下列能力必须出现在最终报告的“路线图缺口”章节，而非缺陷台账：

- P1 剩余：授权完整工具/保持受限/取消 modal，以及 runtime 工具失能的修复路径。
- I2：官方 Pi core installer launcher 与可见 Terminal 流程。
- C1/C2：Pi CLI 权威的已知会话快捷方式、new/open/fork/clone/rename、steer/follow-up/retry 和重启恢复。
- O1/O2：完整工具 timeline、文件变更摘要和 Git 联动。
- M1/M2/S1/W1/E1：完整 model/thinking/auth、resources、trust、workflow profile 与 extension UI bridge。
- Q1/D1/D2：故障矩阵、首个真实 release、Windows/Linux parity。

## 阶段拆分

### 阶段 0：产品完整性与 Pi 原生 contract 审查

- 目标：在任何基线通过结论之前，先盘点真实用户期待的工作流、现有死控件和 Pi 原生 session 能力边界，特别是一个项目多个 session 的 lifecycle。
- 边界：不实现 C1，不将 SDK/TUI-only 行为伪装成 RPC，不解析或修改 Pi session JSONL；未决语义必须形成明确问题，不能通过视觉占位跳过。
- 验收重点：`new_session`、`switch_session`、`fork`、`clone`、`set_session_name`、list/delete/archive 缺口及其产品语义都已记录；C1 明确以 Pi CLI 为唯一 session 真相源，只实现 Pi App 已知会话快捷方式，未索引历史与删除回退 Pi CLI；Tasks、Projects toggle、收起状态的 `+`、项目打开/管理、顶栏 search、runtime download、Import work 和四个 primary action 都有鼠标、Tab/Enter/Space、Semantics、窄窗口和功能/禁用/移除结论；固定声明 `C1 = 明确未交付（不计回归）`、`产品完整性/发布资格 = 未通过`。

### 阶段 A：基线与可复现环境

- 目标：冻结 commit、建立一次性 macOS 测试用户或统一隔离启动器、临时项目、fake runtime、隔离偏好/项目 registry 路径和证据目录。
- 边界：不修改产品代码，不调用真实用户项目；未通过环境隔离硬门时不启动官方 Pi，不提交原始 RPC record 或敏感截图。
- 验收重点：每项测试可重复、可清理、不会污染用户 Pi 数据；验证进程启动器确实向所有测试子进程传入隔离环境。

### 阶段 A1：冷启动 runtime 强制门

- 目标：在继续任何桌面、RPC 或发布验收前，独立复现 ACC-RT-01，确认冷启动诊断是否从 `Checking` 自动完成。
- 边界：只用 `MemoryPiCoreRuntimeDetector` 或同等无副作用 fake；确认失败后只创建最小修复计划，不在本阶段混入其他功能修复。
- 验收重点：确认 S1 时停止 ACC-B、ACC-C、ACC-D 和 P1 的新实现，先完成修复与聚焦回归；确认非缺陷时记录交互契约和证据后继续。

### 阶段 B：自动化与静态验收

- 目标：运行现有静态检查、单元/widget 套件、build verifier 和受控 runtime health；审计测试断言是否证明产品行为。
- 边界：测试绿不等于验收通过；记录未覆盖的用户路径。
- 验收重点：ACC-RT-01、ACC-RPC-03、ACC-POL-01、ACC-PRJ-01、ACC-SET-01、ACC-REL-02 有可定位的自动化证据。

### 阶段 C：桌面用户路径验收

- 目标：在可交互 macOS 桌面测试项目管理、侧栏、composer、消息、错误、设置、语言、主题和窗口尺寸。
- 边界：不依赖远程桌面坐标注入；输入不可用时记录为环境阻塞，不能伪造手工通过。
- 验收重点：每个已声明 UI 路径有实际可见证据，尤其是点击命中、焦点、窄窗口、中文和深浅主题。

### 阶段 D：官方 Pi 与安全边界验收

- 目标：在受控临时项目使用官方 `pi --mode rpc` 验证 prompt、stream、abort、tools/trust 与 process isolation。
- 边界：不保存真实 prompt/event JSONL，不在真实项目写文件；无有效认证时标为外部阻塞。
- 验收重点：没有旧 host fallback、没有跨项目串流、没有静默扩大旧权限。

### 阶段 E：数据、原生身份与交付验收

- 目标：验证 build mode 数据根、Finder/Dock 并存、构建产物和更新状态机。
- 边界：首个真实 tag/DMG 安装只在满足 D1 前置后执行；本轮最多给出“未满足前置”的明确结论。
- 验收重点：开发/正式身份不混淆，且未完成发布前不产生虚假发布结论。

### 阶段 F：缺陷收敛与复验计划

- 目标：按 S0/S1/S2/S3 输出缺陷台账、去重、关联文件与最小修复单元。
- 边界：每个修复单元独立计划、独立验证、独立提交；不把所有缺陷合并为一个大改动。
- 验收重点：每个失败项有 owner、修复优先级、回归用例和是否阻断 P1/发布的结论。

## 执行单元

### ACC-0：完成产品完整性与原生 session contract 审查

- 所属阶段：0。
- 目标：完成 `docs/brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md` 中的代码、文档和隔离 capability probe 审查，确认 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md` 的 Pi CLI 权威边界，并收敛剩余死控件的产品语义。
- 涉及模块：`desktop/lib/src/desktop_shell.dart`、`workspace_*.dart`、`pi_host_client.dart`、`pi_core_rpc_client.dart`、`desktop/test/`、官方 Pi RPC 文档。
- 前置依赖：无；真实 prompt session 验证需要通过环境隔离硬门和独立测试认证。
- 验证方式：只读代码审查、官方协议/实现比对、无认证隔离 probe、对真实 authenticated session 的单独 capability spike 计划。
- 完成标准：多 session 与删除/归档不再是隐含假设；所有明确未交付项、误导控件和待决策项都有归类、owner 和后续执行单元，且不会将 C1 错计为当前回归；输出固定声明 `C1 = 明确未交付（不计回归）`、`产品完整性/发布资格 = 未通过`，并逐项记录关键控件的鼠标、键盘、Semantics 和窄窗口结论。

### ACC-A：建立验收基线与测试夹具

- 所属阶段：A。
- 目标：记录环境、版本与 commit，准备临时项目、受控 fake、数据清理脚本和证据模板。
- 涉及模块：`desktop/test/`、`desktop/tool/`、临时目录与验收文档。
- 前置依赖：ACC-0。
- 验证方式：夹具运行后无用户目录/项目变更，清理后无残留进程与临时文件。
- 完成标准：全部后续用例可在独立目录执行。

### ACC-A1：复现冷启动 runtime 强制门

- 所属阶段：A1。
- 目标：先执行 ACC-RT-01，验证启动后是否自动发起 runtime health，并确认 UI 不会永久停留在 `Checking`。
- 涉及模块：`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/pi_core_runtime.dart`、`desktop/test/widget_test.dart`。
- 前置依赖：ACC-0、ACC-A；仅需要无副作用 fake runtime。
- 验证方式：新增或运行聚焦 widget/integration 夹具，记录 cold start 到终态的状态转换，不点击手动刷新按钮。
- 完成标准：通过则记录证据并进入 ACC-B；失败则登记 S1、暂停后续验收和 P1 新实现，另建最小修复单元。

### ACC-B：完成已交付 UI 与持久化验收

- 所属阶段：B、C。
- 目标：执行 ACC-PRJ、ACC-WS、ACC-SET 以及相关视觉/可访问性用例。
- 前置依赖：ACC-A、ACC-A1。
- 验证方式：widget 回归、手工 macOS 流程、截图/录屏和临时持久化文件检查。
- 完成标准：每项标为通过、失败或外部阻塞；失败项可最小复现。

### ACC-C：完成 runtime、RPC 与安全边界验收

- 所属阶段：B、D。
- 目标：执行 ACC-RT-02/03、ACC-RPC、ACC-POL；ACC-RT-01 必须已在 A1 通过。
- 前置依赖：ACC-A、ACC-A1；官方 Pi 主链还需要通过环境隔离硬门、独立测试认证和临时项目。
- 验证方式：fake runtime、client/widget 测试、`dart run tool/verify_pi_core_runtime.dart`、脱敏真实 smoke。
- 完成标准：runtime/transport 安全边界有明确证据，S0/S1 缺陷立即形成单独修复计划。

### ACC-D：完成原生、构建与发布前置验收

- 所属阶段：E。
- 目标：执行 ACC-ISO、ACC-REL，并标注 D1 仍缺的真实 release 证据。
- 前置依赖：ACC-A、ACC-A1；Finder/Dock 同时运行需要可交互 macOS 桌面，原生 app 路径必须使用一次性 macOS 测试用户。
- 验证方式：build scripts、bundle/DMG verifier、真实应用身份检查、更新 fake。
- 完成标准：开发/正式隔离结论明确；未满足的 D1 前置准确标为不适用/阻塞。

### ACC-E：输出缺陷台账和修复队列

- 所属阶段：F。
- 目标：将所有结果汇总为验收报告，更新总路线图仅涉及实际发现的状态变化或新增风险。
- 前置依赖：ACC-0、ACC-B、ACC-C、ACC-D。
- 验证方式：交叉检查每个用例均有结果、证据、严重度和下一步。
- 完成标准：形成可按 S0/S1 优先顺序执行的独立修复计划，不存在无证据的“很多缺陷”泛化结论；报告固定列出 `C1 = 明确未交付（不计回归）`、`产品完整性/发布资格 = 未通过`，并为每项给出 owner、后续执行单元、待决策状态和证据链接。

## `/goal` 建议作用域

- `/goal ACC-0`：只完成产品完整性、Pi 原生 contract、死控件和 session lifecycle 审查；不实现 C1。
- `/goal ACC-A`：仅建立可清理的验收基线和夹具。
- `/goal ACC-A1`：只复现并判定 ACC-RT-01 冷启动 runtime 强制门；确认 S1 后不继续后续验收。
- `/goal ACC-B`：仅验收当前桌面 UI、项目、composer、设置和持久化。
- `/goal ACC-C`：仅验收 runtime、direct RPC、权限与 trust 边界。
- `/goal ACC-D`：仅验收数据隔离、原生身份、构建和更新前置。
- `/goal ACC-E`：仅汇总结果、建立缺陷台账与后续修复计划。

不得把整个验收活动或修复活动放入单个 `/goal`。S0/S1 缺陷一经确认，应暂停尚未开始的后续验收阶段，先建立独立修复计划并获得修复后的聚焦回归。

## 验证命令基线

```bash
cd desktop
flutter analyze
flutter test
flutter build macos --debug
./scripts/verify-macos-app-identity.sh --configuration debug

# ACC-REL-01：必须先生成本次 universal Release/DMG，禁止复用陈旧 build 目录。
./scripts/build-macos-release.sh --arch universal
./scripts/verify-macos-app-identity.sh \
  --configuration release \
  --app "../release/macos-universal/Pi App.app"
hdiutil verify "../release/macos-universal/Pi-App-0.1.0-macos-universal.dmg"

# 仅在 ACC-A 环境隔离硬门和独立测试认证均通过后运行：
dart run tool/verify_pi_core_runtime.dart --pi /opt/homebrew/bin/pi
dart run tool/verify_pi_core_rpc.dart --pi /opt/homebrew/bin/pi
```

Release DMG、真实 tag、GitHub Actions 和更新闭环属于 D1 以后；除非 D1 前置全部满足，不把它们的缺失解释为本轮代码回归。

## 风险与待确认问题

1. 真实 Pi prompt、tools 与 abort 会消耗用户模型额度；执行 ACC-RPC-01/02 与 ACC-POL-02 前必须先通过环境隔离硬门，并由用户确认隔离环境中的独立测试认证可以使用。
2. 当前远程桌面输入和 macOS 截图通道可能无法可靠投递 Flutter 文本输入或呈现前台窗口。遇到该问题应记录为环境阻塞，不能用虚假 UI 状态替代用户路径通过结论。
3. Finder/Dock 图标可能缓存旧 bundle；原生身份验收需要使用新路径或清理缓存后的可见桌面，并记录该条件。
4. 当前官方 Pi 实测证据基于 `0.82.0`。上游升级后应将协议差异作为兼容性风险，重新运行 R1/R2 的真实 smoke，不应因版本文本本身拒绝运行。
5. `ACC-RT-01` 已有静态审阅证据，必须在 ACC-0、ACC-A 后作为 A1 强制门先复现；确认 S1 时先修复并回归，避免在核心诊断失效的状态下扩大验收范围。
6. C1 的公开 contract 固定为 Pi CLI 唯一 session 真相源：Pi App 仅保存已知会话快捷方式，公开 RPC 未提供的全量 list、delete 和 native archive 不得通过 JSONL、SDK 或 TUI 解析补齐；具体实施边界见 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`。

## 沉淀跟进

- 验收完成后创建 `docs/solutions/YYYY-MM-DD-current-baseline-acceptance.md`，记录最终矩阵、环境、证据、缺陷结论和残余风险。
- 若确认 S0/S1，分别创建对应的最小修复计划，并在总路线图中更新阻塞关系。
- 若发现测试绿但用户路径失败，补充最小 widget/integration/真实 smoke 回归，避免只以静态或 fake 结论代替产品验收。
