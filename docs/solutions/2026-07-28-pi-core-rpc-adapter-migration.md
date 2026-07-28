# Pi Core RPC Adapter 迁移

- 主题：R2 将桌面生产 composer 从历史 Node SDK host 迁移到已安装官方 Pi core 的 direct RPC
- 状态：已完成
- 日期：2026-07-28
- Pi App 基线：`0.1.0+1`
- RPC adapter 版本：`1`
- 引入提交：`6c457ec`
- Pi core 验证版本：`0.82.0`
- 关联计划：
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`

## 结果

生产 `PiDesktopApp` 现在默认注入 `PiCoreRpcClient`，直接启动用户环境中的 `pi --mode rpc`。历史 `LocalPiHostClient` 保留为 SDK 回归和显式测试注入实现，不再是 production fallback。

adapter 位于 `desktop/lib/src/pi_core_rpc_client.dart`。它继续实现既有 `PiHostClient` 产品接口，因此 workspace、composer 和 view model 不读取 Pi 的原始 RPC record。公开接口不包含 Pi RPC 的 `bash` 或 `abort_bash` user command。

## 运行时与安全边界

- 每个产品 session 启动一个独立 Pi process，并把 stdout、stderr、pending request、exit callback 和 event mapping 绑定到该 session 实例。
- 所有 process 以 `pi --mode rpc --no-approve` 启动。新配置默认请求 `read,grep,find,ls,bash,edit,write`；持久化偏好尚未读取时先以受限工具启动，已有无版本或显式受限的 `toolPolicyVersion` 也保持原有限制，不会被静默扩大。
- 工具 allowlist 不构成 OS sandbox、路径 sandbox、网络隔离或逐工具审批。`--no-approve` 只维持 R1 已验证的未信任项目资源基线。
- transport 只按 LF 分帧，兼容移除行尾 CR，单条 input/output record 均限制为 1 MiB。非 JSON object、malformed UTF-8/JSON 和超限 stdout 会终止对应 session。
- request 使用 adapter 生成的 ID 关联；无关 response 不会完成其他 request。
- Pi process 退出、stdout 不完整或协议异常只失效所属 session。shell 收到带 session ID 的 `hostError` 时只清理对应项目状态。

## 稳定事件映射

| Pi RPC | 产品事件 | 处理规则 |
| --- | --- | --- |
| `agent_start` | `runStarted` | 仅表示正常 agent run 已开始。 |
| `message_update.text_delta` | `messageDelta` | 追加到既有 assistant message。 |
| `message_update.thinking_delta` | `thinkingDelta` | 可缺失，当前 view 不依赖其出现。 |
| `tool_execution_start/update/end` | tool lifecycle | 保留关联键和受控数据；完整 timeline 留给 O1。 |
| `queue_update` | `queueUpdated` | 保留给 C2，当前 workspace 不依赖它。 |
| `agent_end` 的 `stopReason: aborted` | `runAborted` | 不等待 abort response。 |
| `agent_settled` | `runSettled` | 正常 run 的唯一完成事件。 |
| `extension_ui_request` | `extensionUiRequest` | fire-and-forget 本地命令在 response 后没有 `agent_start` 时合成 `handledWithoutRun` settled。 |
| process exit / protocol error | session-scoped `hostError` | 使活跃 run 可解释地失败。 |

`select`、`confirm`、`input` 和 `editor` 等需 response 的 extension dialog 目前会由 adapter 发送 `cancelled: true`，并报告稳定 `runFailed`。这避免 R2 composer 永久 waiting；可交互 UI bridge 仍属于 E1。

## 验证

离线 transport / widget 回归：

```bash
cd desktop
flutter analyze
flutter test
```

`desktop/test/pi_core_rpc_client_test.dart` 覆盖正常 event mapping、Unicode separator、CRLF、response correlation、malformed JSON、1 MiB stdout 边界、本地 extension completion、dialog 降级、extension/dialog 后下一普通 prompt、process exit 和跨 session 隔离。

真实 Pi smoke 不属于默认测试，避免日常回归消耗模型调用：

```bash
cd desktop
dart run tool/verify_pi_core_rpc.dart --pi /opt/homebrew/bin/pi
```

本次使用官方 Pi `0.82.0` 通过了 state、models、同模型 `set_model`、同 level `set_thinking_level`、文本流、agent builtin `bash` 启动后的 abort 和最终 aborted event。脚本只在系统临时目录创建项目，不录制原始 prompt/event JSONL，并在结束时删除该目录。

R1 trust fixture 仍需在升级 Pi core 或改变 `--no-approve` / tools 参数时重跑：

```bash
cd host
npm run verify:rpc-contract -- --pi /opt/homebrew/bin/pi
```

## 当前限制

- I1 已提供 `PiCoreRuntimeController`、用户路径持久化、报告版本采集、受限 RPC health 和设置页诊断卡，证据见 `docs/solutions/2026-07-28-pi-core-runtime-detector.md`。版本是验证与排障元数据，不是启动 gate；R2 client 的默认 resolver 现在会服从该 controller。I2 官方 installer launcher 仍未实现。
- C1 尚未建立 session catalog 或跨应用 resume。process 崩溃后，当前项目状态会失效，下一次提交创建新 session；Pi 管理的 session JSONL 不会被 Flutter 直接编辑。
- P1 尚未实现旧受限用户的授权或修复 dialog。新安装默认完整 tools，已有受限偏好保持受限。
- E1 尚未实现交互式 extension UI；本阶段只保证可恢复的拒绝和诊断。
- 本地 extension 的“response 后无 `agent_start`”判定使用短暂观察窗口。Pi `0.82.0` R1 fixture 已验证该顺序；升级 Pi core 时必须重跑 R1 和本 smoke。
- 当前没有远程显示环境下的真实 GUI visual smoke；Flutter widget 回归和 direct RPC smoke 已通过。
