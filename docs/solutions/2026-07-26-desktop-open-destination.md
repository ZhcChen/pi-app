# desktop openDestination 真实打开链路

- 主题：将 `openDestination` 从偏好摘要接成 workspace 内可触发的真实打开行为
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-follow-up-roadmap.md`

## 摘要

这轮把 `openDestination` 真正接到了工作区行为里：

- `PiDesktopApp` 新增显式 `workspaceRootPath` 输入
- `app_data.dart` 不再只给文案数据，还为 `pi-app` 项目产出真实 `workspacePath` / `targetPath`
- `DesktopRuntimeController` 新增 `openTarget(...)`
- `PlatformDesktopRuntimeController` 提供 VS Code / Cursor / Terminal 的跨平台启动策略
- workspace 里的项目和项目项新增真实打开按钮，并默认遵循当前 `openDestination`
- 打开失败时返回结构化结果，由 shell 用 snackbar 给出明确反馈

## 为什么先定义路径输入，再做启动

如果只做“根据 `openDestination` 启动 VS Code / Terminal”的命令层，而不先明确路径输入，最终会出现两类问题：

- 设置页里的默认打开方式已经存在，但没有真实行为可以消费它
- workspace 里能点的入口仍然只知道文案，不知道应该打开哪个项目、目录或文件

因此这轮先明确输入链路：

- app shell 持有 `workspaceRootPath`
- `app_data.dart` 把它解析成 `WorkspaceProjectGroup.workspacePath`
- 具体项目项再解析成 `WorkspaceProjectItem.targetPath`

这样 runtime 只关心“打开哪个路径”和“用什么 destination 打开”，不会再反向依赖页面状态。

## 当前结构

### 1. 应用级路径输入

`PiDesktopApp` 现在支持：

- `workspaceRootPath`

开发态默认来源：

- `PI_WORKSPACE_ROOT`
- 否则使用当前工作目录；若当前目录是 `desktop/`，则回退到其父目录

这保证当前仓库内预览时，`pi-app` 项目可以拿到真实仓库根路径，而不是继续依赖硬编码绝对路径。

### 2. workspace 数据模型

`workspace_feature.dart` 新增：

- `WorkspaceProjectGroup.workspacePath`
- `WorkspaceProjectItem.targetPath`
- `WorkspaceProjectItem`

这意味着：

- 项目本身可以打开到工作区根目录
- 项目项可以打开到具体文件或目录
- 没有真实路径的数据项可以继续保留，但不会伪装成可打开功能

### 3. runtime 打开协议

`app_runtime.dart` 新增：

- `DesktopOpenRequest`
- `DesktopOpenResult`
- `DesktopRuntimeController.openTarget(...)`

当前 `DesktopOpenRequest` 至少携带：

- `destination`
- `targetPath`
- `workspacePath`

返回值不再只靠抛异常，而是统一成 `DesktopOpenResult`，这样 shell 可以用一致方式处理失败提示。

## 跨平台启动策略

### VS Code

- macOS：优先 `code`，回退 `open -a "Visual Studio Code"`
- Windows：尝试 `code.cmd`、`code.exe`，再回退 `cmd /c start`
- Linux：尝试 `code`

### Cursor

- macOS：优先 `cursor`，回退 `open -a "Cursor"`
- Windows：尝试 `cursor.cmd`、`cursor.exe`，再回退 `cmd /c start`
- Linux：尝试 `cursor`

### Terminal

- macOS：`open -a Terminal <directory>`
- Windows：`cmd.exe /c start "" cmd.exe /K "cd /d <directory>"`
- Linux：依次尝试 `x-terminal-emulator`、`gnome-terminal`、`konsole`、`xfce4-terminal`

终端打开永远以目录为目标；如果传入文件路径，会自动回退到其父目录。

## workspace 层行为约定

当前真实入口包括：

- 选中项目后的项目打开按钮
- 选中项目下、带真实 `targetPath` 的项目项打开按钮

这些入口都不直接决定使用哪个应用，而是统一读取当前 `AppPreferences.openDestination`。

因此：

- 改设置页的默认打开方式后，不需要改 workspace 组件实现
- 后续新增更多“打开”入口时，也只要复用同一请求模型

## 失败与降级

这轮没有把缺少真实路径或外部命令缺失的情况静默吞掉。

当前约定是：

- 没有 `workspacePath` / `targetPath`：UI 不提供对应打开按钮，或由 shell 提示“当前项目还没有可打开的本地路径”
- 启动失败：runtime 返回 `DesktopOpenResult.failure(...)`
- shell 通过 snackbar 展示失败原因

这使得“能力未接上”和“命令存在但启动失败”可以被区分。

## 验证 / 证据

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`
- widget / runtime tests 已覆盖：
  - open request 委派
  - workspace 打开动作跟随 `openDestination`
  - 打开失败反馈
  - showInMenuBar 与 openDestination 共存下的运行时同步

## 后续事项

- 阶段 3 继续推进时，应把其余 seed data 也收成真实路径或明确空态
- 如果后续引入最近项目、会话或真实 worktree 数据源，优先继续产出 `workspacePath / targetPath`，而不是让 UI 直接拼路径
- 如需支持更多外部目标，例如 Finder / Explorer / 系统默认打开，应继续沿用 `DesktopOpenRequest` 与 `DesktopOpenResult` 这条链路
