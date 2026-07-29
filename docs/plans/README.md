# 计划索引与执行规则

- 状态：活跃
- 维护日期：2026-07-29
- 适用范围：Pi App 后续产品、runtime 与交付工作

## 入口

[Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md)是唯一的总看板：任务状态、执行顺序、前置依赖和完成门槛以该文件为准。

本文件只负责导航和计划治理，不重复维护各执行单元的技术细节。进入任何新 `/goal` 前，先从总看板确认状态，再进入对应的细化计划。

## 当前执行队列

| 顺序 | 单元 | 当前状态 | 进入条件 | 细化计划 |
| --- | --- | --- | --- | --- |
| 已完成 | I1：Pi Core Detector 与诊断卡 | 已完成 | R1、R2 已完成；证据见 [I1 运行时检测与诊断](../solutions/2026-07-28-pi-core-runtime-detector.md) | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 0 | ACC-0：产品完整性与 Pi 原生 contract 审查 | 进行中，当前执行单元 | 用户要求先完成多 session、死控件、小型交互和原生 session 语义审查；不实现产品代码 | [当前交付基线验收计划](2026-07-28-current-baseline-acceptance-plan.md) |
| 1 | P1：完整工具授权与旧偏好修复 UI | 进行中，等待 ACC-0 质量门 | ACC-0 关闭；I1 已提供 runtime diagnostic 状态 | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 2 | I2：官方 Pi Core Installer Launcher | 待前置 | P1 完成 | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 3 | C1：Pi CLI 权威的 Session 增强 | 待前置，排在 I2 后 | P1、I2 完成；C1.0 真实 probe 还须满足 ACC-A 环境隔离硬门和独立测试认证 | [Pi CLI 权威的 Session 增强执行计划](2026-07-29-pi-cli-authoritative-session-enhancement.md) |
| 4 | D1：macOS Production Acceptance 与首个正式 Release | 待前置 | Q1 和 P0-P3 工作流闭环 | [macOS Ad-hoc 发布与 GitHub 更新执行计划](2026-07-27-macos-ad-hoc-release-and-update.md) |

P1 已完成新配置的完整 builtin tools 默认、旧无版本/受限偏好的安全迁移，以及持久化加载期间的受限 bootstrap。I1 已提供 runtime diagnostic 状态；P1 仍是 ACC-0 关闭后的下一功能实现单元，剩余范围是授权/修复 modal、runtime 工具失能路径和相应回归，不能被重新当作“从零开始”的任务，也不能绕过 ACC-0 直接开始新实现。

## 活跃计划与证据

| 文档 | 角色 | 使用方式 |
| --- | --- | --- |
| [当前交付基线验收计划](2026-07-28-current-baseline-acceptance-plan.md) | 草稿验收覆盖层 | 先完成 ACC-0 产品完整性与 Pi 原生 contract 审查，再冻结当前基线、验收已声明能力并输出缺陷台账；不替代总看板的功能依赖与状态。 |
| [Session 生命周期与产品完整性审查](../brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md) | 已收敛 brainstorm | 记录审查证据与 Pi CLI 权威原则；C1 的实际实施范围以细化计划为准。 |
| [Pi CLI 权威的 Session 增强执行计划](2026-07-29-pi-cli-authoritative-session-enhancement.md) | C1 细化执行计划 | 将 Pi CLI 设为唯一 session 真相源；仅实现已知会话快捷方式与官方 RPC lifecycle，未索引历史和删除回退 Pi CLI。 |
| [Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md) | 唯一总看板 | 更新所有执行单元的状态、依赖、顺序与完成门槛。 |
| [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) | runtime 子计划 | 细化 R1/R2/I1/P1/I2/W1/S1；不与总看板竞争状态权威。 |
| [macOS Ad-hoc 发布与 GitHub 更新执行计划](2026-07-27-macos-ad-hoc-release-and-update.md) | 交付子计划 | 记录发布实现、首个 tag 验证与手动更新约束。 |
| [macOS 开发应用身份与图标隔离](2026-07-28-macos-development-app-identity.md) | 已完成 | 记录 Debug/Profile 与 Release 的原生身份、图标和可并存验证。 |
| [Pi Core RPC R1 能力矩阵](../solutions/2026-07-28-pi-core-rpc-capability-matrix.md) | 兼容性证据 | 记录 Pi CLI 实测版本、RPC 语义、tools/trust 边界；不作为 runtime 版本 gate。 |
| [Pi Core RPC Adapter 迁移](../solutions/2026-07-28-pi-core-rpc-adapter-migration.md) | R2 交付证据 | 记录 direct RPC adapter、真实 smoke、引入提交和当前限制。 |
| [Pi Core 运行时检测与诊断](../solutions/2026-07-28-pi-core-runtime-detector.md) | I1 交付证据 | 记录路径发现、版本信息、受限 health、设置卡、验证和限制。 |
| [开发与正式包应用数据隔离](../solutions/2026-07-28-app-data-environment-isolation.md) | 持久化边界证据 | 记录 debug/profile 与 Release 的 Pi App 自有数据根目录和迁移策略。 |
| [macOS 开发应用身份与图标隔离](../solutions/2026-07-28-macos-development-app-identity.md) | 原生身份证据 | 记录 macOS app identity、开发图标、构建验证和正式交付不变性。 |

## 状态约定

- `已完成`：实现、所需验证和证据文档均已完成。
- `进行中`：该单元已有已交付部分，仍有明确剩余范围。
- `可开始`：技术前置已满足，但尚未进入当前执行切片。
- `待前置`：依赖尚未完成，不得提前实现。
- `待验收`：实现已存在，等待真实环境、发布或用户流程证据。
- `待排期`：依赖和优先级均留待 macOS 核心闭环后决定。
- `已拆分`：历史计划的剩余内容已迁入当前总看板，不再作为独立执行入口。
- `已废弃`：保留历史决策或回归背景，禁止按其中的旧方案实现。

## 历史计划

`2026-07-26-*` 文件主要记录已完成的桌面、品牌和 Config Center 基线。除本文件明确列出的活跃计划外，它们不构成当前执行队列。

- `2026-07-26-desktop-main-feature-roadmap.md` 是历史 SDK host 基线，已废弃；不得恢复 Node host bundle 或 sidecar production fallback。
- `2026-07-26-desktop-follow-up-roadmap.md` 是基础设施收口记录；其剩余边界复核和兼容层清理需要在主路线图中重新排期。
- `2026-07-26-desktop-pi-config-center.md` 是已交付 Config Center 基线；其 resources、trust、auth 和高级诊断后续分别由 M1、M2、S1、E1 接管。
- 其余 `2026-07-26-*` 文件为已完成的设计和实现记录，可用于追溯，不应覆盖总看板的优先级。

## 更新规则

1. 开始一个执行单元前，在总看板和对应子计划中确认相同的状态、依赖和验收标准。
2. 完成一个执行单元后，先更新总看板，再更新子计划和 `docs/solutions/` 证据；记录 Pi App build、Pi core 版本、验证命令、引入 commit 与残余风险。
3. 发现 Pi RPC 语义、trust 边界或发布约束变化时，先更新 R1/R2 证据，再调整后续实现计划。
4. 正式 tag 必须等于 `v<build-name>`；当前 `desktop/pubspec.yaml` 基线为 `0.1.0+1`，对应的首个正式 tag 为 `v0.1.0`。
