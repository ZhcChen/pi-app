# Pi Core RPC R1 能力矩阵

- 主题：Pi App 通过已安装官方 Pi core 的 `pi --mode rpc` 替代历史 SDK host 前的兼容性证据
- 状态：已完成，允许启动 R2
- 日期：2026-07-28
- Pi App 基线：`0.1.0+1`
- Pi core 验证版本：`0.82.0`
- 验证环境：macOS、本机 `/opt/homebrew/bin/pi`、当前已配置的 `sub2api/gpt-5.6-terra`
- 关联计划：
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`
- 历史基线：`docs/solutions/2026-07-27-pi-host-sdk-contract.md`

## 结论

R1 以真实 Pi CLI `0.82.0` 完成了 direct RPC 的最小产品能力验证。R2 可以开始实现 `PiCoreRpcClient` 和 Dart adapter，但必须遵守下文的事件、session、abort、extension 和进程生命周期限制。

这不表示 Flutter 已切换 production transport，也不表示 Pi App 已经支持任意 Pi CLI 版本。当前兼容范围仅为已验证的 `0.82.0`；每次扩大范围或升级 Pi core 都必须重新执行本矩阵的真实验证。

## 验证产物

R1 新增以下可复现产物：

- `host/src/pi_rpc_harness.ts`：严格 LF JSONL harness、1 MiB 保护、request/response 关联、超时、进程退出和临时录制。
- `host/test/pi_rpc_harness.test.ts`：不调用真实模型的 framing、CRLF、Unicode separator、超限和关联测试。
- `host/scripts/verify-rpc-contract.ts`：显式真实 Pi RPC 验证脚本。
- `host/fixtures/rpc-untrusted-project/`：仅含 project-local extension、prompt 和 skill 的 trust fixture。
- `host/package.json`：`npm run verify:rpc-contract`。

执行命令：

```bash
cd host
npm run check
npm test
npm run verify:rpc-contract -- --pi /opt/homebrew/bin/pi
```

真实验证默认把 request / event 原始 JSONL 和摘要写到 `$TMPDIR/pi-app-rpc-contract-*`。录制可能包含测试 prompt、模型文本、项目临时路径和 provider 返回内容，不能提交到仓库或附加到公开 issue。`--output` 仅接受仓库外目录。

## 实测矩阵

| 能力 ID | Pi RPC `0.82.0` 实测 | R2 适配要求 |
| --- | --- | --- |
| `RPC-001` | stdin/stdout 使用 LF JSONL；harness 对输入输出均执行 1 MiB 限制，且不把 `U+2028` / `U+2029` 当作行分隔符。 | Dart transport 仅以 `\n` 分帧，允许移除行尾 `\r`，拒绝超限或无效 JSON。 |
| `RPC-002` | `get_state`、`get_available_models`、`get_available_thinking_levels`、`set_model`、`set_thinking_level` 均成功。 | 按稳定产品 model / thinking view model 映射；运行中切换规则由 R2 / M1 明确，不能假装热切换成功。 |
| `RPC-003` | 空 session 的 `get_state.sessionFile` 是预定路径，但文件尚不存在；direct `bash` 也不会物化该文件。首次 accepted prompt 并完成后文件出现，`--session <path>` 可恢复同一 `sessionId`。 | 不得把 `get_state.sessionFile` 的字符串存在误显示为已保存 session；只有文件实际存在或 Pi 已确认持久化后才显示可恢复。 |
| `RPC-004` | `prompt` 先返回 accepted response，随后产生 `agent_start`、文本 `message_update`、`agent_end` 和 `agent_settled`。 | `agent_settled` 是 product `run.settled` 的唯一正常终态；不能以 prompt response 或 `agent_end` 作为完成。 |
| `RPC-005` | 文本 `text_delta` 在每个实测 prompt 中出现。`thinking_delta` 可在 reasoning-enabled tool / abort prompt 出现，但普通 prompt 可为零。 | thinking 是可选 stream，UI / adapter 必须允许本轮没有任何 thinking delta，不能因缺失卡住。 |
| `RPC-006` | agent 触发 `bash` 时依次观察到 `tool_execution_start`、一个或多个 `tool_execution_update`、`tool_execution_end`；direct `bash` 产生 `bash_execution_update`。 | timeline 按 `toolCallId` 关联；partial result 是累积快照，不能假设它是单次 delta。 |
| `RPC-007` | direct `bash` 的 60,000 字节输出返回 `truncated: true` 与 `fullOutputPath`，并保留流式 update。 | 大输出不得塞入 widget state 或产品 JSONL；只显示截断摘要和受控的本地 artifact 引用。 |
| `RPC-007A` | direct `bash` 即使在 `--no-tools` 下仍可执行，因为它是 RPC 用户 command，不受模型 builtin allowlist 控制。 | Dart adapter 不得向 Flutter 暴露或转发 raw `bash` / `abort_bash`；Pi App 的工具策略只通过 session 启动 allowlist 影响 agent。 |
| `RPC-008` | 在运行 `sleep 20` 的 `bash` tool 后发送 `abort`：tool end 为 `isError: true`、结果文本为 `Command aborted`，`agent_end` 含 assistant `stopReason: "aborted"`，随后出现 `agent_settled`。实测中 abort response 可晚于终态事件。 | 进入 aborting 状态后必须继续消费事件；不能等待 abort response 才结束 UI，也不能把 aborted 当成普通 settled。 |
| `RPC-009` | 运行中 `steer` 与 `follow_up` 均 accepted，收到 4 个 `queue_update`，所有排队消息完成后才出现 `agent_settled`。 | R2 保留 queue event；C2 可在此证据上实现 steer / follow-up UI。 |
| `RPC-010` | 完整 builtin allowlist `read,grep,find,ls,bash,edit,write` 加 `--no-approve` 时，fixture 的 project-local extension、prompt、skill 均不在 `get_commands` 中；`--approve` 对照时三者均加载。 | R2 的 production default 可使用经验证的完整 tools 加 `--no-approve`；tools 和 project trust 仍必须分开建模。 |
| `RPC-011` | trusted fixture 的 `/pi-app-rpc-project-probe` 产生 `extension_ui_request` 和 prompt response，但不产生 `agent_start` 或 `agent_settled`。 | 当 extension 本地处理 prompt 时，adapter 必须合成稳定终态，避免 composer 永久 running；R2 不能只等待 `agent_settled`。 |
| `RPC-012` | agent 开始后向 Pi 发送 `SIGTERM`，Pi 以 exit code `143` 退出且没有 `agent_settled`；harness 的 `process_exit` 是最后记录。 | 进程退出必须使该 generation 的活跃 run 失败；新 process 必须 generation-isolate，禁止旧 stdout / close callback 污染新 session。 |

## 事件规约结论

| Pi RPC 记录 | 稳定产品语义 | 说明 |
| --- | --- | --- |
| `response` for `prompt` | 请求已接受 | 不是运行开始或完成。 |
| `agent_start` | `run.started` | extension 本地处理可能完全没有此事件。 |
| `message_update.assistantMessageEvent.type = text_delta` | `message.delta` | 仅追加文本 delta。 |
| `message_update.assistantMessageEvent.type = thinking_delta` | `thinking.delta` | 可选，零条也是合法一轮。 |
| `tool_execution_start/update/end` | tool timeline 生命周期 | `toolCallId` 是关联键；输出必须受限。 |
| `queue_update` | 排队状态 | steer / follow-up 的可观察状态。 |
| `agent_end` | 非最终内部阶段 | 可能接 retry、compaction 或 queued continuation。 |
| `agent_settled` | `run.settled` | 正常 agent 流的唯一最终完成语义。 |
| `extension_ui_request` | extension UI bridge / 本地完成线索 | R2 先实现本地完成的终态；完整 dialog response 留给 E1。 |
| process `close` / `process_exit` | `run.failed` 或 runtime diagnostic | 没有 `agent_settled` 时必须显式结束 UI run。 |

## R2 Go / No-Go

**结论：GO，有条件进入 R2。**

R2 可以将 current composer 主链迁移至 direct RPC，但实现必须同时满足：

1. 生产只启动经过 I1 发现的 `pi --mode rpc`；历史 `LocalPiHostClient` 仅能作为明确开发回归工具，不能静默 fallback。
2. transport 沿用 R1 的 LF / 1 MiB / stdout JSON object / request correlation 规则，并对每个 process generation 绑定 stdout、stderr、exit callback 与 session mapping。
3. `agent_settled` 结束正常 run；extension 本地处理须以 response + 无 agent start 的已验证路径形成 `handledWithoutRun` 终态。
4. abort、process exit、malformed JSONL、迟到 event 都要结束或隔离活跃 run；abort response 的到达顺序不可作为 UI 状态机依据。
5. 默认启动参数必须保留 R1 验证通过的 `--no-approve` 与完整 builtin tools；这不是 OS sandbox、路径 sandbox、网络隔离或逐工具 approval。Dart adapter 绝不暴露或转发 Pi RPC 的 raw `bash` / `abort_bash` 用户 command。
6. thinking、tool progress、queue update、extension UI request 均必须允许缺失或延迟；view model 不能依赖固定事件次数。

## 未覆盖范围

- `get_entries`、`get_tree`、fork、clone、session catalog 等属于 C1 后续工作，不是 R2 最小迁移阻塞项。
- 显式 trust 后的资源加载和撤销行为属于 S1；R1 只证明默认 `--no-approve` 基线。
- extension `confirm` / `select` / `input` response bridge 属于 E1；R1 只验证本地 command 的 notify 与无 agent 终态。
- 跨平台 installer、Pi core 检测、auth UI、model picker、完整 tool timeline 和 release smoke test 均未因 R1 自动完成。
- Pi process 退出后不会再发 stdout；“旧 generation 的迟到 stdout 不污染新 generation”是 R2 transport 自身必须用 fake / process race 回归覆盖的职责。

## 后续维护

1. 每次升级 Pi core 都重新运行 `npm run verify:rpc-contract`，在本矩阵新增版本行或更新验证记录。
2. R2 完成时，将 product event mapping、adapter version、真实 prompt / abort / process-race 结果写入新的 solution 文档，并更新完整路线图任务状态。
3. 任何改变 `--no-approve`、tools allowlist、session persistence 或 extension completion 判定的实现，都必须重新运行 trust fixture 和 live agent 场景。
