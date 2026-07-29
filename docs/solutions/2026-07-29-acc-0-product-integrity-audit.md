# ACC-0 产品完整性审查结果

- 任务：完成 `docs/plans/2026-07-28-current-baseline-acceptance-plan.md` 中的 `ACC-0`，确认当前产品表面、Pi 原生 session contract 和多会话边界。
- 状态：完成
- 负责人：Pi
- 日期：2026-07-29
- 上位计划：`docs/plans/2026-07-28-current-baseline-acceptance-plan.md`
- 相关审查：`docs/brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md`
- 相关细化计划：`docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md`

## 固定输出

- `C1 = 明确未交付（不计回归）`
- `产品完整性/发布资格 = 未通过`

这两个结论在 `ACC-B` 到 `ACC-E` 结束前都不应被改写为“通过”。

## 已确认边界

1. Pi CLI / Pi Core 是 session 的唯一真相源和唯一生命周期所有者。
2. Pi App 当前已交付的是单项目单内存会话主链，不是多会话 workspace。
3. C1 首版只允许实现“Pi App 已知会话快捷方式”，不得扫描、解析、复制、移动、重写或删除 Pi session JSONL。
4. 公开 RPC 未提供全量 list、delete 或 native archive；未索引历史会话和删除统一回退到可见 Terminal 中的 Pi CLI `/resume` / `pi -r`。
5. `C1.0` 仍是阻断性 capability spike，必须在隔离环境和独立测试认证中验证真实 prompt session 的跨进程恢复、fork/clone 语义和无孤儿 session 启动路径。

上述 session 结论已在 `docs/brainstorms/2026-07-29-session-lifecycle-and-product-completeness.md` 与 `docs/plans/2026-07-29-pi-cli-authoritative-session-enhancement.md` 固化，本次 ACC-0 不再存在待产品确认的 delete/archive/catalog 语义空档。

## 关键控件审查

| 控件 | 当前行为 | 鼠标 | 键盘 / Enter / Space | Semantics | 窄窗口 | 归类 / 严重度 | Owner / 下一执行单元 | 证据 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Projects 展开/收起 | 可展开/收起项目列表。 | 通过：点击可切换。 | 未有独立 Enter/Space 回归。 | 通过：`Semantics(expanded: ...)` 已验证。 | 未见已知溢出。 | 已交付。 | Pi / `ACC-B` 补键盘证据。 | `desktop/lib/src/workspace_components.dart`；`desktop/test/widget_test.dart` 中 `projects section can collapse and expand its project list`。 |
| 收起状态 `+` 添加项目 | 仅在 header hover 时显示；点击后会先展开再添加项目。 | 通过：hover 后点击可添加。 | 未有纯键盘发现性回归；隐藏时不可发现。 | 有 `IconButton` 语义，但仅在 hover 可见时可达。 | 未有专门窄窗口回归。 | 已交付主路径，仍有 S3 可访问性缺口。 | Pi / `ACC-B`。 | `desktop/lib/src/workspace_components.dart`；`desktop/test/widget_test.dart` 中 `projects header adds and manages a registry project`。 |
| 项目 Open 按钮 | 根据当前 open destination 打开项目根目录，并在失败时显示 notice。 | 通过。 | 未有独立键盘焦点顺序回归。 | `IconButton` 自带 button/tooltip 语义。 | 未有专门窄窗口回归。 | 已交付主路径，仍有 S3 可访问性缺口。 | Pi / `ACC-B`。 | `desktop/lib/src/workspace_components.dart`；`desktop/test/widget_test.dart` 中 `workspace open actions follow the current open destination`、`workspace open action shows failure feedback`。 |
| 项目 Manage 菜单 | hover 或 selected 时出现，可 rename / pin / remove。 | 通过。 | 未有独立键盘菜单回归；hover 依赖降低 discoverability。 | `PopupMenuButton` 有基础 button 语义，但无完整焦点顺序证据。 | 未有专门窄窗口回归。 | 已交付主路径，仍有 S3 可访问性缺口。 | Pi / `ACC-B`。 | `desktop/lib/src/workspace_components.dart`；`desktop/test/widget_test.dart` 中 `projects header adds and manages a registry project`。 |
| 顶栏 Search | `IconButton(onPressed: () {})`，点击无状态变化、无功能。 | 失败：可点击但无效果。 | 未有独立回归；若获得焦点只会触发空回调。 | 有 button/tooltip 语义，但与功能不一致。 | 图标本身无已知溢出。 | 死控件，S3。 | Pi / 待新建 UI 收敛修复单元。 | `desktop/lib/src/workspace_view.dart`。 |
| 侧栏 Download Pi Core | `DesktopIconActionButton(onPressed: () {})`，显示为可安装入口但无行为。 | 失败：可点击但无效果。 | 未有独立回归；若获得焦点只会触发空回调。 | 有 button/tooltip 语义，但与功能不一致。 | 图标本身无已知溢出。 | 死控件，S2。 | Pi / `I2` 前置的 UI 收敛修复单元，或 `I2` 实现时一并收口。 | `desktop/lib/src/workspace_view.dart`。 |
| Settings `Import work` | `_SettingsActionButton(onPressed: () {})`，无导入流程。 | 失败：可点击但无效果。 | 未有独立回归；若获得焦点只会触发空回调。 | 具有按钮语义，但与功能不一致。 | `_SettingsRow` 在窄宽度下会纵向堆叠，当前无功能但无已知布局错误。 | 死控件，S3。 | Pi / 待新建 UI 收敛修复单元。 | `desktop/lib/src/settings_view.dart`、`desktop/lib/src/settings_feature.dart`。 |
| `New task` | 默认选中的当前 workspace 标签；点击只保持选中，不改变画布。 | 当前可视为“当前页标签”，非独立动作。 | 未有独立回归。 | 依赖 `InkWell` 的基础点击语义。 | 未有专门窄窗口回归。 | 不是回归，但不是独立已交付功能。 | Pi / `C1.3` 需把文案与真实 `new_session` 对齐。 | `desktop/lib/src/app_data.dart`、`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/workspace_components.dart`。 |
| `Scheduled` / `Plugins` / `Pull requests` | 点击只改变高亮，画布不消费选择结果。 | 失败：视觉可选，但无真实工作流。 | 未有独立回归。 | 依赖 `InkWell` 的基础点击语义，但未暴露不可用状态。 | 未有专门窄窗口回归。 | 误导性导航表面，S3。 | Pi / 待新建 UI 收敛修复单元；对应未来能力分别归属后续计划。 | `desktop/lib/src/app_data.dart`、`desktop/lib/src/desktop_shell.dart`、`desktop/lib/src/workspace_components.dart`。 |
| Tasks 披露行 | 仅渲染标签和右箭头，没有点击、状态或内容。 | 不可点击。 | 不可聚焦。 | 不是 button，也没有 expanded/collapsed 语义。 | 仅有静态排版证据。 | 静态占位，S3。 | Pi / 待新建 UI 收敛修复单元；不要在 C1 前继续以披露控件呈现。 | `desktop/lib/src/workspace_components.dart`；`desktop/test/widget_test.dart` 中 `sidebar section labels keep text and icons centered`。 |

## 路线图缺口与当前回归的分界

下列能力在 ACC-0 中被明确记录为未交付路线图单元，不计入当前回归失败：

- `C1/C2`：多会话快捷方式、new/open/fork/clone/rename、steer/follow-up/retry、跨重启恢复。
- `I2`：官方 Pi Core installer launcher 与可见 Terminal 流程。
- `O1/O2`：完整工具 timeline、文件变更摘要和 Git 联动。
- `M1/M2/S1/W1/E1/Q1/D1/D2`：配置、resources、trust、workflow profile、extension UI、故障矩阵和正式发布。

这些路线图缺口的 owner 和后续执行单元固定如下：

| 路线图缺口 | Owner | 后续执行单元 |
| --- | --- | --- |
| 多会话快捷方式、new/open/fork/clone/rename、恢复 | Pi | `C1` / `C2` |
| 官方安装器与可见 Terminal 安装流 | Pi | `I2` |
| 工具 timeline、文件变更摘要 | Pi | `O1` / `O2` |
| model/thinking/auth、resources、trust、workflow profile、extension UI | Pi | `M1` / `M2` / `S1` / `W1` / `E1` |
| 故障矩阵、正式发布、跨平台 parity | Pi | `Q1` / `D1` / `D2` |

判定原则是：**未开始的路线图能力是产品缺口，不是已交付回归；但任何已显示为可点击、可展开、可切换的表面都必须有真实行为、准确禁用状态或明确移除。**

## 候选强门

`ACC-RT-01` 的冷启动 runtime `Checking` 候选 S1 仍未通过无副作用 fake 复现或排除，因此保持候选状态，不在 ACC-0 中直接定性。

- 当前 owner：Pi
- 下一执行单元：`ACC-A` 后立即执行 `ACC-A1`
- 当前结论：不能据此继续声称 runtime 冷启动诊断已经验收通过；也不能在未复现前把它升级为已确认缺陷。

## 本次采用的自动化证据

以下聚焦用例已在 `desktop/` 目录执行并通过：

```bash
flutter test test/widget_test.dart --plain-name "projects section can collapse and expand its project list"
flutter test test/widget_test.dart --plain-name "projects header adds and manages a registry project"
flutter test test/widget_test.dart --plain-name "workspace open actions follow the current open destination"
flutter test test/widget_test.dart --plain-name "workspace open action shows failure feedback"
flutter test test/widget_test.dart --plain-name "conversation transcript keeps message bubbles within a narrow light workspace"
```

这些用例仅覆盖当前已实现的 Projects / Open / 对话布局证据，不构成对 Search、Download、Import work、Tasks 或 primary nav 壳层的“通过”结论。

## ACC-0 收口结论

1. 多会话、delete、archive 和 catalog 的产品边界已经明确，不再是隐含假设。
2. `C1` 已被准确重述为“Pi CLI 权威的已知会话快捷方式增强”，不会再被误计为当前回归。
3. 当前桌面仍存在一组误导性表面：Search、Download Pi Core、Import work、`Scheduled` / `Plugins` / `Pull requests` 和 Tasks 披露行。
4. 当前可继续进入下一功能实现前的状态切换是：**关闭 ACC-0，恢复 P1 作为下一功能实现单元；同时保留 `ACC-A` / `ACC-A1` 作为后续验收覆盖层，其中 `ACC-A1` 仍可在确认 S1 时重新阻断 P1。**
5. 在上述死控件收口前，当前产品仍不能获得“产品完整性通过”或“发布资格通过”的结论。
