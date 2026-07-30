# Pi Core Session Lifecycle Probe

- 日期：2026-07-30
- 状态：部分完成
- 关联计划：`docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`
- 关联工具：`desktop/tool/verify_pi_core_session_lifecycle.dart`

## 背景

C1.0 的关键阻断点不是 UI，而是官方 Pi RPC 的真实 lifecycle 语义：

1. fresh controller 启动时是否已经绑定一个原生 session。
2. 在 fresh controller 上再发 `new_session` 会不会额外创建第二个 session。
3. 跨进程打开已知会话时，`pi --mode rpc --session <sessionFile>` 是否可用。
4. 如果不用 `--session`，而是 fresh controller 启动后再发 `switch_session({ sessionPath })`，是否会先暴露一个不同的初始 session，从而留下孤儿 session 风险。

这些问题必须先用官方 RPC 自己回答，不能靠扫描 session JSONL、SDK `SessionManager.list()` 或 TUI 文本解析去补。

## 实现

新增工具：`desktop/tool/verify_pi_core_session_lifecycle.dart`

它做的事情是：

1. 创建隔离夹具目录：临时 `HOME`、`PI_CODING_AGENT_DIR`、Pi App dev 数据根和临时 Git 项目。
2. 在该隔离环境里直接启动官方 `pi --mode rpc`。
3. 用原始 JSONL RPC 依次探测：
   - `get_state`
   - `get_entries`
   - `set_session_name`
   - `prompt`
   - `new_session`
   - `--session <sessionFile>` 启动路径
   - fresh controller + `switch_session({ sessionPath })`
4. 输出结构化 JSON 报告，包含：
   - 启动/切换/重命名/跨进程结果
   - 关键 session path / sessionId / leafId
   - 是否复用了目标 transcript entry 结构
   - 推荐的产品打开路径
   - 风险和阻塞点

这个工具只用官方 RPC 和进程参数，不读取、不解析、不修改 Pi session JSONL。

## 本轮实际结果

执行命令：

```bash
cd desktop
flutter analyze
dart run tool/verify_pi_core_session_lifecycle.dart --report /tmp/pi-app-c1-lifecycle-report.json
```

本轮在隔离环境、当前本机 `pi 0.82.0` 下得到的关键信号如下：

1. fresh controller 启动后，首个 `get_state` 已返回真实 `sessionFile` 和 `sessionId`。
2. 在这个 fresh controller 上再发 `new_session`，会得到不同的 `sessionFile` / `sessionId`。
3. `pi --mode rpc --session <sessionFile>` 在当前环境可用，而且首轮 `get_state` 就绑定到了目标 `sessionFile`。
4. fresh controller 启动后再发 `switch_session({ sessionPath })`，会先暴露一个不同的初始 `sessionFile`，然后才 rebinding 到目标 `sessionFile`。
5. 即使本轮没有拿到可用的 `lastAssistantText`，`get_entries` / `leafId` / `messageCount` 的结构仍在 `--session` 启动路径和 fresh-controller-then-switch 路径中保持一致，说明 prompt 后的 session 结构可跨进程重现。

因此，本轮 probe 的当前产品结论是：

- **已证明**：fresh controller 不应再自动追加 `new_session`。
- **已证明**：跨进程打开已知会话时，应优先使用官方 `--session <sessionFile>` 启动路径。
- **已提示高风险**：fresh controller 再 `switch_session` 会先暴露不同初始 session，当前应视为孤儿 session 风险路径，不能作为默认 cold open 方案。

## 当前结论如何影响 C1

对 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md` 的实际收敛是：

1. `打开已知会话` 的首选路径可以从“待验证候选”收敛为“优先用 `--session <sessionFile>`”。
2. `new_session` 不能在 fresh controller 启动后无脑再发，否则会多创建一个 Pi 原生 session。
3. 当前 sidebar 已实现的同 controller `switch_session` replacement 仍然成立，但它不能外推出“新 controller cold open 也该这么做”。
4. 后续 C1.2 的 multi-controller adapter 应该围绕 `--session` 来设计，而不是围绕 fresh controller 再 `switch_session`。

## 未完成项

这次 probe 仍然不是完整的 C1.0 关闭证据，剩余缺口包括：

1. 还没有在独立测试认证下拿到可确认的 assistant text 内容，因此 prompt 持久化当前只证明了 entry/tree 结构保持一致。
2. 还没有覆盖 `fork`、`clone`、`get_fork_messages`、缺失 `sessionFile`、取消路径和并发 controller。
3. 还没有把这套 probe 接进正式验收文档或独立测试启动器流程。
4. 还没有在 Pi App 生产代码里接入跨进程多 controller open；当前只是先拿到了更清晰的上游 contract 证据。

## 建议的下一步

1. 用同一个隔离 probe 继续补 `fork` / `clone` / cancel / missing-session-file 证据。
2. 在独立测试认证就绪后，复跑同工具，补上可验证 assistant text 的 authenticated evidence。
3. 以本结论为依据，开始设计 C1.2 的 `--session` 多 controller adapter，而不是 fresh-controller-then-`switch_session` cold open。
