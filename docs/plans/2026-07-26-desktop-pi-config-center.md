# desktop Pi Config 可视化配置计划

- 任务：在 `desktop` 设置页中提供 `pi` 全局配置中心，识别并可视化编辑 `~/.pi/agent`（或等效配置根）下的关键配置与提示词文件
- 状态：已拆分（已完成 Config Center 基线；剩余配置、resources、trust、auth 与 extension 范围已迁入总路线图）
- 负责人：Pi
- 日期：2026-07-26
- 承接计划：`docs/plans/2026-07-26-desktop-main-feature-roadmap.md`
- 当前计划入口：`docs/plans/README.md`

> **文档状态，2026-07-28：** 本文件的阶段 1-3 已交付，作为当前 Config Center 基线保留。阶段 4-5 的剩余内容不得直接按旧假设执行：model/thinking/auth/config 进入 M1，resources 进入 M2，project trust 进入 S1，extension 交互进入 E1；均以 `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md` 的状态和前置为准。

## 当前进度

- 已完成：阶段 1 / 配置根识别与文件访问层
  - 新增 `desktop/lib/src/pi_config_store.dart`
  - 支持 `PI_CODING_AGENT_DIR` 优先，其次回落 `~/.pi/agent`
  - 建立 `settings.json`、`models.json`、`auth.json`、`SYSTEM.md`、`APPEND_SYSTEM.md`、`AGENTS.md` 的统一读取与保存入口
- 已完成：阶段 2 / Prompts / Context 可视化编辑
  - 设置页新增 `Pi Prompts` 分类
  - 支持编辑全局 `SYSTEM.md`、`APPEND_SYSTEM.md`、`AGENTS.md`
  - 空内容保存会删除对应文件，回到“无文件”状态
- 已完成：阶段 3 / Models 可视化配置
  - 设置页新增 `Pi Models` 分类
  - 支持结构化编辑 `defaultProvider`、`defaultModel`、`defaultThinkingLevel`、`enabledModels`
  - 支持 `models.json` 原始高级编辑器，并展示 custom providers / models / auth 摘要
- 已拆分：`settings.json` 其余高频项、resources / advanced / trust / auth 的后续入口分别由当前总路线图的 M1、M2、S1、E1 管理；当前不得从本文件直接创建执行任务。

## 目标

这个任务完成后，`desktop` 设置页需要至少具备一套可用的全局 `Pi Config` 配置中心，满足：

- 能识别 `pi` 的实际全局配置根，而不是只假定写死 `~/.pi`
- 能可视化配置高频模型相关设置
- 能编辑全局 `SYSTEM.md`、`APPEND_SYSTEM.md`、`AGENTS.md`
- 能把 `settings.json` 中高频、稳定、适合表单化的项收成结构化 UI
- 能为复杂或低频配置保留原始文件 / JSON 编辑入口，而不是强行全部做成表单

## 背景

根据 `pi` 官方文档，真正的全局配置根默认是：

- `~/.pi/agent/`

不是单纯的 `~/.pi/`。同时还存在环境变量覆盖：

- `PI_CODING_AGENT_DIR`

因此桌面端配置中心的第一步不是“扫描 `~/.pi`”，而是解析 **实际生效的 pi 配置根**：

1. 优先 `PI_CODING_AGENT_DIR`
2. 否则回落到 `~/.pi/agent`

而且 `pi` 的全局配置不是只有 `settings.json`，还包括：

- `settings.json`
- `models.json`
- `auth.json`
- `AGENTS.md`
- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- `trust.json`
- `prompts/`、`skills/`、`extensions/`、`themes/`

因此这次功能本质上是 **Pi Config Center**，不是单一的“模型设置页”。

## 范围

这次计划会覆盖：

- `desktop/lib/src/settings_feature.dart`
- `desktop/lib/src/settings_view.dart`
- `desktop/lib/src/settings_components.dart`
- 新增 `desktop/lib/src/pi_config/**` 或等效模块
- 必要时新增 `desktop/test/**`
- `docs/solutions/**`

配置文件范围：

- 全局 `settings.json`
- 全局 `models.json`
- 全局 `AGENTS.md`
- 全局 `SYSTEM.md`
- 全局 `APPEND_SYSTEM.md`
- 全局 `auth.json`（第一轮建议至少做只读状态或安全受限入口）

## 非目标

- 第一轮不处理 project-local `.pi/settings.json` 可视化编辑
- 第一轮不做所有 `pi` 配置项的表单化覆盖
- 第一轮不直接做 provider OAuth 全量 GUI 登录流
- 第一轮不管理第三方 package 的安装/卸载工作流
- 第一轮不把 `models.json` 全量 schema 全部翻译成复杂动态表单

## 影响区域

- 文件：`desktop/lib/src/**`、新增 `pi_config` 相关模块
- 模块：settings、global config store、file editors、raw JSON editors
- 接口 / 约束：
  - `settings.md`
  - `models.md`
  - `usage.md`
  - `environment-variables.md`
  - `packages.md`

## 关键结论

### 1. 配置中心要识别的是 `~/.pi/agent`，不是裸 `~/.pi`

UI 上可以展示成“Pi Home”或“Global Pi Config”，但底层解析必须遵守官方路径约定与环境变量覆盖。

### 2. 高价值配置分三层

#### A. 文件型 prompt / context 配置

这类不是 JSON，而是 Markdown / 文本文件，最应该优先支持：

- `~/.pi/agent/SYSTEM.md`
- `~/.pi/agent/APPEND_SYSTEM.md`
- `~/.pi/agent/AGENTS.md`

其中：

- `SYSTEM.md`：替换默认系统提示词
- `APPEND_SYSTEM.md`：追加系统提示词
- `AGENTS.md`：全局普通上下文 / 工作规则 / 偏好提示

#### B. 结构化高频配置

最适合做成表单或分组控件：

- `settings.json`
  - `defaultProvider`
  - `defaultModel`
  - `defaultThinkingLevel`
  - `enabledModels`
  - `theme`
  - `externalEditor`
  - `defaultProjectTrust`
  - `steeringMode`
  - `followUpMode`
  - `transport`
  - `compaction.*`
  - `retry.*`
  - `sessionDir`
  - `enableSkillCommands`
  - `httpProxy`
  - `warnings.anthropicExtraUsage`

#### C. 高复杂度高级配置

不建议第一轮硬做全动态表单，建议提供原始 JSON 编辑器或半结构化编辑：

- `models.json`
  - provider baseUrl / api / authHeader
  - custom models
  - modelOverrides
  - compat
  - thinkingLevelMap
  - headers
  - routing / cache / strict mode 等细项
- `auth.json`
  - API key / OAuth token 持久化状态
- `trust.json`
  - 已保存的项目 trust 决策
- `packages` / `extensions` / `skills` / `prompts` / `themes`

### 3. 第一轮模型配置要拆成两层

用户说的“主要是配置模型这块”，实际上应拆成：

- **日常模型偏好**：`settings.json`
  - 默认 provider / model / thinking / enabledModels
- **模型目录与自定义 provider**：`models.json`
  - custom provider
  - local model servers
  - modelOverrides
  - compat / headers / routing

也就是：

- 第一层做成结构化 GUI
- 第二层至少先给高级原始编辑器，不强行一次做满 schema-driven UI

## 推荐信息架构

建议在设置页新增一组 `Pi Config` 分类，至少包含：

1. `Pi Config / Models`
- 默认 provider
- 默认 model
- 默认 thinking level
- `enabledModels`
- `models.json` 高级编辑入口
- provider / auth 状态摘要

2. `Pi Config / Prompts`
- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- `AGENTS.md`

3. `Pi Config / Runtime`
- `defaultProjectTrust`
- `steeringMode`
- `followUpMode`
- `transport`
- `compaction`
- `retry`
- `sessionDir`

4. `Pi Config / Resources`
- `packages`
- `extensions`
- `skills`
- `prompts`
- `themes`
- `enableSkillCommands`

5. `Pi Config / Advanced`
- `httpProxy`
- telemetry / analytics 相关项
- `auth.json` 只读状态或受保护入口
- `trust.json` 查看 / 清理入口
- 原始 `settings.json` / `models.json` 打开按钮

## 实现思路

1. 先做一个 `PiConfigStore` / `PiConfigRepository`，统一解析全局配置根和相关文件路径
2. 将配置项按“文件型 / 结构化 JSON / 高级原始 JSON”分层，而不是全部塞进一个设置页
3. 优先完成 `Models + Prompts` 两个子页，这两块最直接影响主功能开发
4. 再补 `Runtime / Resources / Advanced`，并保留原始文件编辑兜底

## 阶段拆分

### 阶段 1：配置根识别与文件访问层

- 目标：建立 `pi` 全局配置根解析、文件读取、文件写入、错误处理
- 边界：先不做完整 UI，只先打通数据层
- 验收重点：能稳定解析 `PI_CODING_AGENT_DIR` / `~/.pi/agent`，并列出关键文件状态

### 阶段 2：Prompts / Context 可视化编辑

- 目标：优先支持 `SYSTEM.md`、`APPEND_SYSTEM.md`、`AGENTS.md`
- 边界：先做全局，不做 project-local
- 验收重点：可读、可编辑、可保存、可回退到空文件状态

### 阶段 3：Models 可视化配置

- 目标：支持 `defaultProvider`、`defaultModel`、`defaultThinkingLevel`、`enabledModels`，以及 `models.json` 高级入口
- 边界：结构化日常设置优先，高复杂 provider schema 后置
- 验收重点：用户能不碰 JSON 完成日常模型偏好设置

### 阶段 4：其他 `settings.json` 高频项

- 目标：补齐 runtime / delivery / compaction / retry / sessionDir 等高频项
- 边界：优先高频稳定项，不急着全覆盖所有冷门开关
- 验收重点：有明确的信息架构，不把低频高级项混进主设置流程

### 阶段 5：高级配置与诊断入口

- 目标：补 raw editor、auth 状态、trust 状态、resource arrays
- 边界：允许部分功能先只读或只提供外部打开入口
- 验收重点：高级用户可完整触达底层配置，但普通用户不被复杂度淹没

## 执行单元

### 单元 1

- 所属阶段：阶段 1
- 目标：解析 `pi` 全局配置根
- 涉及文件 / 模块：新建 `pi_config` 数据层
- 前置依赖：`environment-variables.md`
- 验证方式：单测 / 调试输出验证路径解析
- 完成标准：优先 `PI_CODING_AGENT_DIR`，否则回落 `~/.pi/agent`

### 单元 2

- 所属阶段：阶段 1
- 目标：建立关键文件索引
- 涉及文件 / 模块：`settings.json`、`models.json`、`AGENTS.md`、`SYSTEM.md`、`APPEND_SYSTEM.md`、`auth.json`
- 前置依赖：单元 1
- 验证方式：本地文件状态读取
- 完成标准：UI 能知道文件是否存在、路径在哪、最后内容是什么

### 单元 3

- 所属阶段：阶段 2
- 目标：做 `SYSTEM.md` / `APPEND_SYSTEM.md` / `AGENTS.md` 编辑页
- 涉及文件 / 模块：settings 页面与文本编辑组件
- 前置依赖：单元 2
- 验证方式：手工编辑保存
- 完成标准：三类提示词文件都能可视化编辑

### 单元 4

- 所属阶段：阶段 3
- 目标：做模型偏好结构化表单
- 涉及文件 / 模块：settings 页面、`settings.json` 读写层
- 前置依赖：单元 2
- 验证方式：修改后检查 `settings.json`
- 完成标准：`defaultProvider`、`defaultModel`、`defaultThinkingLevel`、`enabledModels` 可编辑

### 单元 5

- 所属阶段：阶段 3
- 目标：做 `models.json` 高级入口
- 涉及文件 / 模块：raw JSON editor / provider summary UI
- 前置依赖：单元 2
- 验证方式：编辑后检查 `models.json`
- 完成标准：至少可安全查看、编辑并保存 `models.json`

### 单元 6

- 所属阶段：阶段 4
- 目标：补 runtime / delivery / compaction / retry 高频配置
- 涉及文件 / 模块：`settings.json` 表单页
- 前置依赖：单元 4
- 验证方式：修改后检查 `settings.json`
- 完成标准：高频项不必再依赖手工编辑 JSON

### 单元 7

- 所属阶段：阶段 5
- 目标：补资源数组与 auth/trust 高级入口
- 涉及文件 / 模块：resources / advanced 页面
- 前置依赖：单元 2、单元 6
- 验证方式：文件读写与状态展示验证
- 完成标准：高级用户可触达 `packages/extensions/skills/prompts/themes` 及 `auth.json`/`trust.json`

## 历史 `/goal` 记录

阶段 1-3 已完成。以下旧建议只用于追溯当时的交付边界，不能作为当前 `/goal` 入口；后续配置工作必须按 `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md` 的 M1、M2、S1、E1 前置拆分。

- 历史第一条闭环依次覆盖配置根识别、prompt/context 编辑和模型偏好结构化配置。
- 不应将整个 Pi Config Center 作为单个 `/goal`。

## 验证方式

- 命令：
  - `cd desktop && flutter analyze`
  - `cd desktop && flutter test`
- 手工检查：
  - 设置页能显示解析后的 `pi` 配置根
  - `SYSTEM.md` / `APPEND_SYSTEM.md` / `AGENTS.md` 可读写
  - `settings.json` 的模型相关项可视化编辑后落盘正确
  - `models.json` 至少存在高级编辑入口
- 预期证据：
  - 用户不必先开编辑器手改 `~/.pi/agent/*` 才能完成高频全局配置
  - 高复杂配置仍有安全兜底入口，不会被 UI 完全遮蔽

## 风险 / 待确认问题

- 模型列表来源是否直接读取当前 `pi` 可用模型目录，还是只编辑静态默认值
- `auth.json` 是否允许明文 GUI 编辑，还是只做状态展示与受保护操作
- `models.json` 第一轮是否需要 schema-aware 表单，还是 raw editor 足够
- 后续 host 接入后，这套配置中心是否继续由 Flutter 直接读写文件，还是迁到 host 统一管理

## 沉淀跟进

- 这轮完成后，建议补一份 `Pi Config` 文件分层与 UI mapping 的 solution 文档
