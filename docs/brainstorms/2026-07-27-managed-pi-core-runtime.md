# Pi Core 外置运行时与受管理安装

- 主题：将 Pi App 从“捆绑 Node / Pi SDK 的独立运行时”调整为“增强已安装 Pi core 的桌面客户端”
- 状态：已决定
- 负责人：Pi
- 日期：2026-07-27
- 关联计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`
- 关联契约：`docs/solutions/2026-07-27-pi-host-sdk-contract.md`

## 背景

此前 M1 假设把完整 Node runtime、`host/dist` 和 `@earendil-works/pi-coding-agent` 放入 Pi App bundle。该路径会让 Pi App 变成另一份 Pi runtime 的分发者，和产品定位冲突。

新的产品方向是：Pi App 只增强用户独立安装的 Pi core。用户在设置中只看到“Pi core”，可检查其安装、兼容性、版本、日志和更新状态；Node、`pi-coding-agent`、安装器和可选工作流 profile 都是 Pi core 的内部组成，不与 Pi App bundle 绑定。

用户提出使用 `https://github.com/ZhcChen/pi-light-ce` 初始化。已核对其 `v0.1.0`：它是 Pi-first 工作流模板和 bootstrap CLI，不是 `pi-coding-agent` runtime。当前 macOS 脚本会经 Homebrew 安装 Node、`pi-coding-agent` 与 Git，再 clone `pi-light-ce`；Pi App 首版只把它作为 Pi core 健康后可单独安装的 workflow profile，不把它作为 Pi core 的来源。

## 目标

1. Pi App bundle 不携带 Node runtime、`@earendil-works/pi-coding-agent` 或私有 SDK 副本。
2. 设置页能检测 Pi core，明确显示未安装、安装中、兼容、版本不兼容、损坏和诊断失败等状态。
3. 未安装时，用户可以显式触发安装；界面提供真实下载进度或明确步骤进度、取消、日志、失败恢复和重试。
4. Pi App 继续保持稳定的 workspace view model，不让业务 UI 直接依赖原始 Pi RPC event。
5. Pi core、workflow profile、项目初始化和 project trust 保持分离；安装 Pi core 不得自动改写用户项目。

## 已确认决策

1. **生产 transport**：Pi App 直接启动用户安装的 `pi --mode rpc`，不安装或分发 `pi-app-host` companion。Dart 内的 RPC adapter 负责把 CLI protocol 规约为稳定 workspace view model。
2. **Pi core 来源**：设置页只安装官方 `pi-coding-agent`。Pi App 不随 bundle 提供 Node 或 Pi SDK，也不把 `pi-light-ce` 作为 Pi core 的来源。
3. **`pi-light-ce` 定位**：它是设置中的可选 workflow profile。用户可在 Pi core 健康后单独执行其安装脚本；不会随 Pi core 安装自动执行，也不会自动向任何项目写入文件。
4. **默认工具能力**：新安装与新 session 默认请求 `read`、`grep`、`find`、`ls`、`bash`、`edit`、`write`。旧偏好、用户关闭的工具策略或 runtime diagnostic 表明编码工具未启用时，Pi App 弹出授权对话；用户拒绝后保持受限模式。
5. **project trust 仍独立**：默认编码工具不等于自动信任项目级 `.pi` resources。初始 direct RPC 必须显式传入 `--no-approve`，并由 R1 验证该组合的实际行为后，才能作为生产默认值。
6. **平台顺序**：先完成 macOS 的 RPC、检测和官方安装闭环，再扩展 Windows / Linux。

## 约束

- 当前 `host/` 直接依赖 Node `>=22.19.0` 和 `@earendil-works/pi-coding-agent@0.82.0`，现有 `LocalPiHostClient` 固定启动 `node host/dist/src/index.js`。仅改安装入口不能满足新边界。
- Pi CLI `0.82.0` 已提供 `pi --mode rpc`，使用严格 LF JSONL，覆盖 prompt、abort、session、model、thinking、stream、工具 lifecycle、steer、follow-up、compaction 与 retry 等能力。
- direct RPC 的 event / command schema 不等于当前 host protocol；需要在 Dart transport adapter 内规约，而不是让 workspace 直接解析 RPC。
- 当前产品策略不实现逐工具 approval：新 session 默认请求完整 builtin tool allowlist。R1 需要验证 Pi RPC 对工具启用状态、diagnostic 和 project-local resources 的实际行为，避免 UI 把未启用工具误显示为已授权。
- 当前 `pi-light-ce` installer 跟随可变 `main`、没有 GitHub release asset、结构化 JSONL 进度或可恢复 transaction；它不能参与 Pi core 安装，只能作为用户显式触发的可选 workflow profile。
- 当前 `pi-light-ce` 只检查 Node `>=18`；该限制不再影响官方 Pi core 的安装路径，但 optional profile 安装必须在 Pi core 健康后单独呈现其前置条件。

## 备选方案

### 方案 1：直接使用已安装 Pi CLI 的 RPC

- 概述：Pi App 检测并启动用户安装的 `pi --mode rpc`；新增 `PiCoreRpcClient` 与 Dart adapter，将 Pi RPC 规约成现有 workspace 所需的 session / run / message view model。
- 优点：Pi App 不携带 Node、SDK 或额外 host；Pi core 是唯一 agent runtime；复用 Pi CLI 已发布的嵌入接口和 session/auth/config 语义。
- 缺点：Dart adapter 需要维护 Pi RPC 兼容性；此前 host 隐藏的 SDK event 差异会转移到 adapter；工具启用与 runtime diagnostic 的兼容性需要持续验证。
- 风险：用户或包管理器升级 Pi 后 RPC schema / 语义可能变化；必须维护支持的 Pi CLI 版本范围和真实 compatibility smoke test。

### 方案 2：安装独立的 `pi-app-host` companion

- 概述：Pi App 不 bundle runtime，但通过受管理 Pi core installer 在用户目录安装 Node、Pi SDK 和版本化 `pi-app-host` companion；Flutter 继续使用当前 product protocol。
- 优点：保留既有 host protocol、SDK adapter 和将来工具 interception 的扩展空间；Flutter 的迁移量较小。
- 缺点：本质上仍维护一份应用专属 runtime / SDK 组合，只是移出 app bundle；会形成 Pi CLI 与 companion SDK 的双版本兼容问题，不符合“Pi App 只是增强 Pi core”的目标。
- 风险：安装、升级、诊断和安全边界比方案 1 更复杂，且容易重新演变成隐形的第二份 Pi core。

### 方案 3：继续将 runtime 打进应用 bundle

- 概述：维持旧 M1 方案。
- 优点：干净机器启动路径可控，不依赖外部安装。
- 缺点：直接违背新的产品定位；应用承担 Node 和 Pi SDK 的分发、签名、漏洞升级与平台兼容成本。
- 风险：与独立 Pi CLI 的 auth、extension、session 和版本状态发生分叉。

## 已决定方案

采用**方案 1：已安装 Pi CLI 的 RPC**作为生产主线，并把原本的 M1 改为“受管理 Pi core 检测、安装与兼容性”。理由是它最清晰地保持了产品边界：Pi 是唯一 runtime，Pi App 是其 GUI 增强客户端。

迁移不能一步删除现有 host。第一步应做 RPC compatibility spike，验证以下最小闭环后再切换生产 transport：无副作用 health、create / resume session、prompt、text / thinking stream、`agent_settled`、abort、model / thinking、extension 本地处理终态和工具事件。现有 SDK host 仅保留为开发期参考与回归基线，待 RPC adapter 稳定后另行决定移除策略。

新安装和新 session 默认请求完整 builtin tool 集。旧无工具偏好、用户关闭的工具策略或 runtime diagnostic 表明工具不可用时，Pi App 显示授权 / 修复对话；该对话只控制 builtin tool allowlist，不实现逐工具审批或 sandbox。project-local resources 仍保持未信任策略。

`pi-light-ce` 只作为 Pi core 健康后的可选 workflow profile。它的安装和 `pi-l-ce init <project>` 都必须由用户显式触发；Pi core 安装不会自动执行其中任何一步。

## 建议运行时架构

```text
Pi App Flutter UI
  -> PiCoreRuntimeController
       -> 检测 / 安装 / 兼容性 / 日志状态
  -> PiCoreRpcClient
       -> pi --mode rpc (已安装 Pi core)
       -> Pi CLI RPC JSONL
  -> PiCoreRpcAdapter
       -> 稳定 workspace view model

可选：pi-light-ce workflow profile
  -> 用户显式为某个项目执行 pi-l-ce init
```

`PiCoreRuntimeController` 只检查可执行文件绝对路径、`pi --version`、受限 RPC health、已声明的兼容版本范围和日志位置；不得读取 auth 内容、自动加载项目资源或授予 project trust。

## 安装 Contract

Pi App 对用户展示“安装 Pi core”，首版只调用官方 `https://pi.dev/install.sh`，不将 `pi-light-ce` 混入该流程。该脚本会在缺少 Node 时读取 `/dev/tty` 选择 Homebrew、系统包管理器或 standalone Node 安装方式，因此不能作为普通无终端后台子进程静默执行。

1. 设置页先检测 `pi` 的绝对路径、`pi --version` 与受限 RPC health；只有未安装、损坏或版本不兼容时才显示“安装 Pi core”。
2. 用户确认后，Pi App 从官方 URL 下载 installer 到临时目录，显示该脚本的真实 HTTP 下载字节、来源 URL 和本地日志位置；下载完成后再执行本地文件，以便用户看见实际来源和脚本路径。该步骤不提供独立的内容完整性校验，首版的信任根是用户确认的官方 HTTPS 来源，不能把它描述为比 `curl | sh` 更强的验真机制。
3. 因官方 installer 可能需要 TTY 交互，macOS 首版在可见 Terminal 会话中执行下载后的脚本。Pi App 显示“等待官方安装完成”，轮询 `pi --version` 和无工具 RPC health；用户可停止等待并稍后重新检测，但不能把关闭等待误称为取消外部 installer。
4. Homebrew、npm、apt、winget 或官方 script 内部下载无法提供可信的统一字节百分比时，Pi App 只显示确定的阶段和实时检测状态，不伪造进度。
5. 检测成功的条件是：可执行文件可解析、Pi 版本在当前兼容范围内、可启动受限 `pi --mode rpc`，并能完成无副作用 state handshake。认证和项目 resources 不参与检测。
6. 安装前对用户披露官方来源、将由官方 script 安装的 Node / npm / Pi、可能的 PATH 或管理员权限变更，以及会打开 Terminal 的原因。安装与更新分离，默认不自动更新。
7. `pi-light-ce` 安装另设 workflow profile 操作。第一版可在用户明确确认来源、可变脚本与影响后下载并运行其脚本，但不提供固定版本或内容完整性保证；它永远不能替代 Pi core 安装，也不能自动运行 `pi-l-ce init`。

## 默认工具与授权语义

1. Pi App 启动新 RPC session 时默认请求完整内置工具集：`read`、`grep`、`find`、`ls`、`bash`、`edit`、`write`。
2. 新偏好默认保存完整工具策略。现有 `toolPolicyVersion: 1` 的无工具 / 受限状态不得静默升级：首次创建会话前弹出授权对话，说明将启用的工具和其文件 / shell 风险，用户可授权、继续受限或取消。
3. 若 RPC 启动参数、Pi diagnostic 或 session state 表明编码工具不可用，同样弹出授权 / 修复入口；不能只在设置页显示开关而让会话静默失能。
4. 这项授权只决定 Pi App 请求的 builtin tool allowlist，不是操作系统权限、路径 sandbox 或逐工具审批。`bash`、`edit`、`write` 可在 Pi 进程拥有的权限范围内工作。
5. project-local extension、command、skill 和 prompt 仍按未信任项目策略隔离；默认工具启用不改变项目 trust。

## 版本记录

能力矩阵继续维护在 `docs/solutions/2026-07-27-pi-host-sdk-contract.md`。新 transport 落地后，应新增并记录：

- Pi App build version
- Pi core version range 与实际检测版本
- RPC adapter version
- Pi RPC compatibility schema / feature baseline
- 官方 installer URL、下载后脚本的 SHA-256（用于诊断回溯，不表示已验证内容）与执行日志位置
- `pi-light-ce` workflow profile version
- capability 引入 commit、验收命令与残余风险

## 已确认边界与待验证事项

1. **已确认**：生产主线使用 `pi --mode rpc`，不继续安装 `pi-app-host` companion。
2. **已确认**：Pi core 使用官方安装入口；`pi-light-ce` 仅作为设置中的可选 workflow profile。
3. **已确认**：默认请求完整 builtin tool 集；检测到旧策略或运行时未启用编码工具时，先弹出授权 / 修复对话。
4. **待验证**：Pi RPC 的事件和 session 操作能否完整覆盖现有 workspace view model；必须由 `R1` spike 给出逐项证据。
5. **待验证**：在 `--no-approve` 的未信任项目模式下，完整 builtin tool allowlist 与 project-local resources 的实际行为；验证前不把工具启用描述为项目 trust。
6. **待验证**：官方 installer 的 Terminal 启动、PATH 刷新和安装完成后的进程内 `pi` 发现策略。

## 下一步

新的执行计划位于 `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`，并替代旧 M1：

1. `R1`：Pi RPC compatibility spike，先不改 workspace UI。
2. `R2`：`PiCoreRpcClient` / adapter 与现有 product view model 的迁移、回归与旧 host 退场策略。
3. `I1`：Pi core runtime detector、状态机、设置页诊断和无副作用 health。
4. `I2`：官方 installer 下载、Terminal 执行、状态轮询、日志和失败恢复。
5. `P1`：默认完整工具策略、旧偏好迁移授权对话与 runtime diagnostic 修复入口；前置条件是 R1 已验证 `--no-approve` 不自动加载 project-local executable resources。
6. `W1`：可选 `pi-light-ce` workflow profile 安装与显式项目初始化。
7. `S1`：在 R1 的未信任基线之上规划 project trust UI；不重复作为默认工具启用的安全前置。
