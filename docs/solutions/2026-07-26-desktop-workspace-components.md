# desktop 工作区基础组件约定

- 主题：桌面工作区基础组件与复用边界
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-shell-refinement.md`

## 摘要

为 `desktop` 工作区沉淀一组稳定的基础组件和尺寸约定，让 `workspace_view.dart` 只保留壳层结构与组合逻辑，提示卡、composer、底部状态面板、侧栏动作项和项目项单独维护。

## 背景

随着桌面端主界面逐步变复杂，`workspace_view.dart` 同时承担了两类职责：

- 工作区页面层级和状态组合
- 一批可复用的小型 UI 组件实现

这会让后续继续细化工作区时，开发者需要在一个文件里同时理解页面结构和基础组件细节。为降低维护成本，这轮把工作区 primitives 独立出来，并记录使用约定。

## 关键结论

- 工作区基础组件统一放在 `desktop/lib/src/workspace_components.dart`
- 页面容器和组合逻辑保留在 `desktop/lib/src/workspace_view.dart`
- 新增或调整工作区基础元素时，优先在 `workspace_components.dart` 中扩展，而不是把新控件直接堆回页面文件
- 工作区常用尺寸收口到 `_WorkspaceComponentSpec`，避免后续继续散写魔法数字

## 可复用建议

- 空态提示卡：使用 `_PromptCardTile`
  - 用于首页建议任务卡和类似的轻量选择块
- 底部输入区：使用 `_Composer`
  - 保持 tags、输入区、执行摘要和发送按钮的一体化结构
- composer 标签：使用 `_ComposerTag`
  - 不在页面层单独拼 folder / branch / runtime 小标签
- 执行预设面板：使用 `_WorkspaceBottomPanel`
  - 用于展示当前工作区执行上下文和偏好摘要
- 状态胶囊：使用 `_WorkspaceStatusPill`
  - 用于权限、打开方式、sleep、suggested prompts 这类低层级状态
- 侧栏动作项：使用 `_SidebarActionTile`
- 项目列表项：使用 `_ProjectTile` 与 `_ProjectItemRow`
- 分节标签：使用 `_SectionLabel` 与 `_CollapsedSectionRow`

## 验证 / 证据

- 命令：`cd desktop && flutter analyze`、`cd desktop && flutter test`
- 文件：`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/workspace_components.dart`
- 输出或观察：页面壳层与工作区基础组件职责分离，后续细化时可以直接定位到独立组件文件

## 后续事项

- 若后续把设置页和工作区的部分基础控件进一步统一，可继续抽成更上层的 `desktop` primitives
- 如果未来引入真实会话列表和消息流，可以按同样方式拆出 `conversation_components.dart`
