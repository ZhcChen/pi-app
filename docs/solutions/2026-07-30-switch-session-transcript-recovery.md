# 同 controller `switch_session` 的 transcript 恢复

- 日期：2026-07-30
- 状态：已落地
- 关联计划：`docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`

## 背景

Pi App 已经能在当前活跃 controller 上调用官方 `switch_session({ sessionPath })` 切到某个已知会话，但切换成功后如果只刷新 `get_state`，workspace 仍然只能看到空 transcript。

这会造成两个问题：

1. 用户已经进入了一个真实 Pi 原生 session，但桌面侧看起来像是“刚创建的空会话”。
2. sidebar 打开的已知会话虽然成功 replacement 了当前 controller，但无法证明 Pi App 真的在用官方会话内容，而不是只切了 metadata。

同时，当前阶段仍然不能扫描、解析、复制或改写 Pi session JSONL，也还没有完成跨进程 cold reopen 的无孤儿 session 证据，因此不能把这次实现扩展成“新 controller 打开已知会话”。

## 结论

当前阶段采用一个保守且可验证的产品语义：

1. 只在“当前项目已经 attach 且空闲的 controller”上开放已知会话点击。
2. 点击后调用官方 `switch_session({ sessionPath })` 做同进程 replacement。
3. replacement 成功后立刻调用官方 `get_entries`，以 `leafId + parentId` 重建当前活动分支。
4. Pi App 只把该分支上的用户/助手文本恢复为本地 transcript 视图；不扫描文件、不保存 transcript 副本、不伪造全量 catalog。

这意味着：

- 已支持“同 controller 切换到已知会话并恢复真实 transcript”。
- 仍未支持“跨进程 cold open 已知会话”。
- 仍未支持“Pi 全量历史 catalog”。
- 仍未支持“delete/archive/session JSONL 管理”。

## 实现要点

### 1. `PiHostClient` 增加稳定 transcript 接口

在 `desktop/lib/src/pi_host_client.dart` 增加：

- `PiHostTranscriptRole`
- `PiHostTranscriptMessage`
- `PiHostClient.getSessionTranscript({ sessionId })`

这个接口是产品层 contract，不把 raw RPC `SessionEntry` 直接泄漏给 widget。

### 2. `PiCoreRpcClient` 用官方 `get_entries` 恢复活动分支

在 `desktop/lib/src/pi_core_rpc_client.dart`：

- 发送官方 `get_entries`
- 解析返回的 `entries` 与 `leafId`
- 先建立 `id -> entry` 映射
- 从 `leafId` 沿 `parentId` 回溯当前活动分支
- 仅提取分支上的 `message` entry
- 仅把 `role == user / assistant` 的文本转成 `PiHostTranscriptMessage`

关键点：

- 不能直接按 append 顺序全量渲染，否则会把废弃 branch 也混进 transcript。
- 非消息 entry 仍要进入 branch 回溯图，因为当前 leaf 可能落在 `session_info`、`label`、`model_change` 等非消息节点之后。
- transcript 恢复是只读显示，不改变 Pi 原生 session。

### 3. `desktop_shell` 在切换成功后恢复 transcript

在 `desktop/lib/src/desktop_shell.dart`：

- `_openKnownSessionShortcut(...)` 在 `switchSession(...)` 成功后调用 `getSessionTranscript(...)`
- 将恢复结果映射为 `WorkspaceConversationMessage`
- 用恢复后的消息替换旧会话的本地 transcript
- 继续沿用 `_sessionViewGeneration` 和当前项目 cwd 检查，避免项目切换后迟到结果回填错误视图

### 4. fake host 也支持这条链路

在 `MemoryPiHostClient` 中增加按 `sessionPath` 注入 transcript 的能力，用于 widget test 验证 sidebar 点击后的真实恢复行为。

`LocalPiHostClient` 暂不扩展 legacy protocol，而是显式声明不支持 transcript restore。桌面层对该错误做 best-effort 忽略，不影响 production direct RPC 路径。

## 验证

已通过：

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`

本轮新增/更新的关键覆盖：

- `desktop/test/pi_core_rpc_client_test.dart`
  - `direct Pi RPC rebuilds the active transcript from get_entries`
  - 验证 `get_entries` 不会把废弃 branch 混进当前 transcript
- `desktop/test/widget_test.dart`
  - `selected project can switch the current controller to a known session shortcut`
  - 验证 sidebar 点击后恢复出真实 transcript，而不是空白视图

## 剩余边界

这次实现故意停在同 controller replacement：

1. 没有证明 `pi --mode rpc --session <sessionFile>` 的 cold open 语义。
2. 没有证明“新 controller 启动后再 `switch_session`”不会留下未请求的初始孤儿 session。
3. 没有实现跨进程 reopen、fork/clone controller 策略或多 Tab 原生 reopen。
4. 没有恢复 tool timeline、tree 或更细的 entry 类型，只恢复当前 transcript 所需的用户/助手文本。

后续若进入 C1.0 / C1.2 的真实 capability spike，应继续以这次的 transcript 恢复实现为基础，但不能把它误表述成最终的 cold reopen 方案。
