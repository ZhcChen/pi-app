# 计划索引与执行规则

- 状态：活跃
- 维护日期：2026-07-28
- 适用范围：Pi App 后续产品、runtime 与交付工作

## 入口

[Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md)是唯一的总看板：任务状态、执行顺序、前置依赖和完成门槛以该文件为准。

本文件只负责导航和计划治理，不重复维护各执行单元的技术细节。进入任何新 `/goal` 前，先从总看板确认状态，再进入对应的细化计划。

## 当前执行队列

| 顺序 | 单元 | 当前状态 | 进入条件 | 细化计划 |
| --- | --- | --- | --- | --- |
| 已完成 | I1：Pi Core Detector 与诊断卡 | 已完成 | R1、R2 已完成；证据见 [I1 运行时检测与诊断](../solutions/2026-07-28-pi-core-runtime-detector.md) | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 1 | P1：完整工具授权与旧偏好修复 UI | 进行中，当前下一单元 | I1 已提供 runtime diagnostic 状态 | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 2 | I2：官方 Pi Core Installer Launcher | 待前置 | P1 完成 | [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) |
| 3 | C1：Session Catalog、New、Resume 与 Fork | 可开始，排在 I2 后 | R2 已完成；先完成受管理 runtime 与权限路径 | [Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md) |
| 4 | D1：macOS Production Acceptance 与首个正式 Release | 待前置 | Q1 和 P0-P3 工作流闭环 | [macOS Ad-hoc 发布与 GitHub 更新执行计划](2026-07-27-macos-ad-hoc-release-and-update.md) |

P1 已完成新配置的完整 builtin tools 默认、旧无版本/受限偏好的安全迁移，以及持久化加载期间的受限 bootstrap。I1 已提供 runtime diagnostic 状态；P1 因此成为当前下一执行单元，剩余范围是授权/修复 modal、runtime 工具失能路径和相应回归，不能被重新当作“从零开始”的任务。

## 活跃计划与证据

| 文档 | 角色 | 使用方式 |
| --- | --- | --- |
| [Pi App 完整功能主路线图](2026-07-27-pi-app-complete-feature-roadmap.md) | 唯一总看板 | 更新所有执行单元的状态、依赖、顺序与完成门槛。 |
| [外置 Pi Core、RPC 与运行时管理执行计划](2026-07-27-external-pi-core-rpc-runtime.md) | runtime 子计划 | 细化 R1/R2/I1/P1/I2/W1/S1；不与总看板竞争状态权威。 |
| [macOS Ad-hoc 发布与 GitHub 更新执行计划](2026-07-27-macos-ad-hoc-release-and-update.md) | 交付子计划 | 记录发布实现、首个 tag 验证与手动更新约束。 |
| [Pi Core RPC R1 能力矩阵](../solutions/2026-07-28-pi-core-rpc-capability-matrix.md) | 兼容性证据 | 记录 Pi CLI 实测版本、RPC 语义、tools/trust 边界；不作为 runtime 版本 gate。 |
| [Pi Core RPC Adapter 迁移](../solutions/2026-07-28-pi-core-rpc-adapter-migration.md) | R2 交付证据 | 记录 direct RPC adapter、真实 smoke、引入提交和当前限制。 |
| [Pi Core 运行时检测与诊断](../solutions/2026-07-28-pi-core-runtime-detector.md) | I1 交付证据 | 记录路径发现、版本信息、受限 health、设置卡、验证和限制。 |
| [开发与正式包应用数据隔离](../solutions/2026-07-28-app-data-environment-isolation.md) | 持久化边界证据 | 记录 debug/profile 与 Release 的 Pi App 自有数据根目录和迁移策略。 |

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
