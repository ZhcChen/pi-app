# Pi Core 外置运行时与受管理安装

- 主题：将 Pi App 从“捆绑 Node / Pi SDK 的独立运行时”调整为“增强已安装 Pi core 的桌面客户端”
- 状态：收敛中
- 负责人：Pi
- 日期：2026-07-27
- 关联计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`
- 关联契约：`docs/solutions/2026-07-27-pi-host-sdk-contract.md`

## 背景

此前 M1 假设把完整 Node runtime、`host/dist` 和 `@earendil-works/pi-coding-agent` 放入 Pi App bundle。该路径会让 Pi App 变成另一份 Pi runtime 的分发者，和产品定位冲突。

新的产品方向是：Pi App 只增强用户独立安装的 Pi core。用户在设置中只看到“Pi core”，可检查其安装、兼容性、版本、日志和更新状态；Node、`pi-coding-agent`、安装器和可选工作流 profile 都是 Pi core 的内部组成，不与 Pi App bundle 绑定。

用户提出使用 `https://github.com/ZhcChen/pi-light-ce` 初始化。已核对其 `v0.1.0`：它是 Pi-first 工作流模板和 bootstrap CLI，不是 `pi-coding-agent` runtime。当前 macOS 脚本会经 Homebrew 安装 Node、`pi-coding-agent` 与 Git，再 clone `pi-light-ce`；它可以演进为受管理安装的引导器，但当前形态不能直接被 GUI 下载并执行。

## 目标

1. Pi App bundle 不携带 Node runtime、`@earendil-works/pi-coding-agent` 或私有 SDK 副本。
2. 设置页能检测 Pi core，明确显示未安装、安装中、兼容、版本不兼容、损坏和诊断失败等状态。
3. 未安装时，用户可以显式触发安装；界面提供真实下载进度或明确步骤进度、取消、日志、失败恢复和重试。
4. Pi App 继续保持稳定的 workspace view model，不让业务 UI 直接依赖原始 Pi RPC event。
5. Pi core、workflow profile、项目初始化和 project trust 保持分离；安装 Pi core 不得自动改写用户项目。

## 约束

- 当前 `host/` 直接依赖 Node `>=22.19.0` 和 `@earendil-works/pi-coding-agent@0.82.0`，现有 `LocalPiHostClient` 固定启动 `node host/dist/src/index.js`。仅改安装入口不能满足新边界。
- Pi CLI `0.82.0` 已提供 `pi --mode rpc`，使用严格 LF JSONL，覆盖 prompt、abort、session、model、thinking、stream、工具 lifecycle、steer、follow-up、compaction 与 retry 等能力。
- direct RPC 的 event / command schema 不等于当前 host protocol；需要在 Dart transport adapter 内规约，而不是让 workspace 直接解析 RPC。
- 逐工具 approval 是后续编码能力的安全前置。尚未确认 Pi RPC 是否能在 builtin tool 执行前可靠暂停并等待 GUI 决策；在 spike 结论前，不能承诺 direct-RPC 下的写入或 shell 审批。
- 当前 `pi-light-ce` installer 跟随可变 `main`、没有 GitHub release asset、签名、checksum、结构化 JSONL 进度或可恢复 transaction；不能使用 `curl | bash` 或下载后直接执行远端脚本。
- 当前 `pi-light-ce` 只检查 Node `>=18`，而旧 host 需要 `>=22.19.0`；若其承担 Pi core 引导，需要统一版本范围与兼容矩阵。

## 备选方案

### 方案 1：直接使用已安装 Pi CLI 的 RPC

- 概述：Pi App 检测并启动用户安装的 `pi --mode rpc`；新增 `PiCoreRpcClient` 与 Dart adapter，将 Pi RPC 规约成现有 workspace 所需的 session / run / message view model。
- 优点：Pi App 不携带 Node、SDK 或额外 host；Pi core 是唯一 agent runtime；复用 Pi CLI 已发布的嵌入接口和 session/auth/config 语义。
- 缺点：Dart adapter 需要维护 Pi RPC 兼容性；此前 host 隐藏的 SDK event 差异会转移到 adapter；逐工具 approval 的可实现性尚未验证。
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

## 当前倾向

采用**方案 1：已安装 Pi CLI 的 RPC**作为生产主线，并把原本的 M1 改为“受管理 Pi core 检测、安装与兼容性”。理由是它最清晰地保持了产品边界：Pi 是唯一 runtime，Pi App 是其 GUI 增强客户端。

迁移不能一步删除现有 host。第一步应做 RPC compatibility spike，验证以下最小闭环后再切换生产 transport：无副作用 health、create / resume session、prompt、text / thinking stream、`agent_settled`、abort、model / thinking、extension 本地处理终态和工具事件。现有 SDK host 仅保留为开发期参考与回归基线，待 RPC adapter 稳定后另行决定移除策略。

若 spike 证明 RPC 无法支持必要的安全拦截，首版 direct RPC 必须限制为无工具或读取能力；不能用 GUI 弹窗伪造实际无法阻止的 `bash` / `edit` / `write` approval。

`pi-light-ce` 的定位应调整为两项可独立选择的能力：

1. **Pi core bootstrap / installer contract**：只在其具备固定版本、可验证 artifact、机器可读进度与可恢复安装后，才供 Pi App 调用。
2. **workflow profile**：Pi core 健康后可选安装。`pi-l-ce init <project>` 写入 `AGENTS.md`、`.pi/prompts/` 和 `docs/` 前必须再次显示目标路径和文件清单，不能在 Pi core 安装时自动执行。

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

Pi App 对用户展示“安装 Pi core”，但安装前必须展开其组成、来源、版本、写入位置、系统权限和 PATH 影响。内部 contract 至少需要：

1. 固定版本的 signed manifest：包含 schema、core version、支持的 OS/arch、Pi / Node / profile version、下载 URL、SHA-256、签名、最低 Pi App 版本和 RPC compatibility range。
2. Pi App 内置或可信获取 manifest 公钥；先校验签名，再下载固定 artifact 并校验 SHA-256。禁止接受环境变量覆盖下载源，禁止执行可变 `main` 分支脚本。
3. 安装器 stdout 只输出 JSONL：`hello`、`step.started`、`download.progress`、`step.completed`、`warning`、`failed`、`result`；stderr 仅供诊断。
4. 已知 `Content-Length` 的自有 artifact 可显示字节进度；Homebrew、npm、winget 等外部包管理器只能显示确定的阶段进度，不能伪造百分比。
5. 每次安装使用 transaction id 和独占锁，在 `~/.pi-app/runtime/` 原子记录状态、artifact hash、旧版本和日志位置；支持取消、重启恢复、health check 后切换和失败回滚。
6. 所有系统级安装、PATH 写入或管理员权限必须在 GUI 明示具体命令和影响，并由操作系统原生提权确认；默认优先用户目录安装。
7. 安装与更新分离，默认不自动更新。更新必须再次通过 manifest、兼容 gate、health check 和 rollback，不能以 `git pull` 作为产品更新机制。

## 版本记录

能力矩阵继续维护在 `docs/solutions/2026-07-27-pi-host-sdk-contract.md`。新 transport 落地后，应新增并记录：

- Pi App build version
- Pi core version range 与实际检测版本
- RPC adapter version
- Pi RPC compatibility schema / feature baseline
- `pi-light-ce` bootstrap version 与 workflow profile version
- manifest hash / signing key id
- capability 引入 commit、验收命令与残余风险

## 待确认问题

1. 是否确认生产主线改为 `pi --mode rpc`，并接受在 Dart 中增加 RPC adapter，而不是继续安装 `pi-app-host` companion？
2. macOS 首版的 Pi core 安装渠道是什么：要求用户已有 Homebrew、使用官方 Pi 安装方式，还是先在 `pi-light-ce` 建设签名 release installer？
3. `pi-light-ce` 是否只作为可选 workflow profile，还是要同时承担 Pi core bootstrap？建议前者默认可选，后者必须先完成 installer contract。
4. 逐工具 approval capability spike 未通过前，是否接受首版 direct RPC 仅启用无工具 / 读取工具，继续禁用 `bash`、`edit`、`write`？
5. 是否确认仍按 macOS 优先，待该 contract 稳定后再扩展 Windows / Linux？

## 下一步

在上述决策确认后，创建新的执行计划并替代旧 M1：

1. `R1`：Pi RPC compatibility spike，先不改 workspace UI。
2. `R2`：`PiCoreRpcClient` / adapter 与现有 product view model 的迁移、回归与旧 host 退场策略。
3. `I1`：Pi core runtime detector、状态机、设置页诊断和无副作用 health。
4. `I2`：在 `pi-light-ce` 或独立 installer 项目中实现签名 manifest、JSONL installer contract、固定 artifact 与 transaction / rollback。
5. `I3`：Pi App 安装界面、真实进度、取消、日志和恢复。
6. `S1`：direct RPC 下的 trust / approval spike；根据结果决定编码工具的开放范围。
