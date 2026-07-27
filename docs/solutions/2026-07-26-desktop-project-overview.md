# desktop workspace project overview 实现记录

- 日期：2026-07-26
- 范围：`desktop/lib/src/app_data.dart`、`desktop/lib/src/workspace_feature.dart`、`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/workspace_components.dart`
- 关联计划：`docs/plans/2026-07-26-desktop-follow-up-roadmap.md`

## 背景

此前 workspace 左侧 `Projects` 仍混有 seed data，右侧主体仍是空态标题和建议卡片。这会带来两个问题：

- 用户以为项目已经接成真实数据，但实际只有 `pi-app` 的部分打开能力是真的
- 右侧不会因为切换项目而展示可操作的项目信息，项目选择几乎没有业务意义

## 这轮落地

### 1. 项目数据从 seed data 收成真实 workspace root

`app_data.dart` 现在不再产出 `yuance` / `novel-1` 这类演示项目，而是：

- 先解析真实 workspace root
- 仅在本地目录真实存在时产出项目
- 从 `.git/HEAD` 读取 branch / detached head 信息
- 从真实目录中生成 `README.md`、`docs`、`desktop`、`assets` 等 recent targets；若这些入口都不存在，再回退到当前目录前几个非隐藏项

### 2. `WorkspaceProjectGroup` 承担更清晰的项目 contract

这轮增加了这些字段：

- `branch`
- `isGitRepository`
- `sessionCwd`
- `WorkspaceProjectItem.relativePath`
- `WorkspaceProjectItem.kind`

目的不是做“更复杂的模型”，而是让右侧 overview 和后续 `project -> session cwd` 链有明确输入，不再把 `workspacePath` 一项过度复用到所有语义上。

### 3. 右侧从空态升级成真实 `Project overview`

`WorkspaceCanvas` 现在在有项目时展示：

- `Project overview`
- 项目路径
- 仓库状态
- branch
- session cwd 预留位
- recent targets
- 继续保留建议卡片和底部 composer / status panel

这样右侧已经不再只是装饰性空态，而是当前项目的真实入口页。

### 4. 外部打开链继续复用 runtime bridge

这轮没有再做第二套打开逻辑：

- 项目根目录的打开
- recent targets 的打开

都继续复用已有 `DesktopRuntimeController.openTarget(...)`，并继续遵循当前 `openDestination` 偏好。

### 4. composer 开始显式绑定 `sessionCwd`

这轮继续把 workspace 主交互从“看起来像能用”推进到“状态上确实有项目上下文”：

- composer 会显示当前 `sessionCwd`
- 提交按钮不再是空壳
- 提交后会生成一条与当前项目绑定的 prepared task 状态

这还不是 `pi-host` 会话，但已经把最关键的输入链路收成：

- 选中项目
- 读取 `project.sessionCwd`
- 由 composer submit 生成绑定该 cwd 的任务意图

这样下一步接 `pi-host` 时，不需要再返工“项目选择如何影响任务上下文”这条链。

### 5. 左侧 `Projects` 改为扁平项目列表，并接上手动添加

这轮把左侧项目区往参考图继续收：

- 不再在 sidebar 内展开 recent targets
- 项目列表改成单行扁平结构
- `Projects` header 悬浮时才显示 `+`
- `+` 会调用本地目录选择器，并把选中的目录加入项目列表
- 手动添加的项目不再挂在 `AppPreferences` 上，而是写入 `~/.pi-app/projects/index.json` 项目注册表
- `FileProjectRegistryStore` 会把旧的 `settings.json.projectPaths` 自动迁移到项目注册表
- 项目行在 hover 或选中时提供 `…` 菜单，可固定 / 取消固定或从 Pi App 的项目列表中移除；移除不会删除源目录
- 项目选择会更新注册表的 `lastOpenedAt`，注册表排序会优先展示固定项目，再展示最近打开项目
- 正式 app 启动时不再把自身运行目录或容器 `Data` 目录误识别成项目；只有显式注入的 workspace root 或手动添加的项目才进入列表

这样右侧 overview 继续负责“项目细节和 recent targets”，左侧只承担“项目选择与切换”，信息密度和职责都更清楚。

## 关键决策

### 只显示真实项目，不再保留演示项兜底

如果当前 workspace root 无法解析或本地目录不存在，就显示明确空态，而不是再塞回假项目名。

### branch 允许为空

此前 `branch` 被强制要求一定存在，这让“本地目录但不是 Git 仓库”的情况只能伪造分支名。现在改为：

- `branch` 可空
- `isGitRepository` 单独表达是否是 Git 仓库

这样 contract 更贴近真实状态。

### overview 先做“真实可用”，不先做完整文件树

这轮没有引入 IDE 式 explorer。原因很直接：

- 当前更关键的是“项目是真的”与“右侧可操作”
- 完整文件树会引入更重的状态和交互成本
- 对后续 `pi-host` / session cwd 主链帮助没有前两者直接

## 验证

已验证通过：

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`

新增验证覆盖：

- `memory project registry store manages project lifecycle`
- `file project registry store migrates legacy project paths`
- `workspace open actions follow the current open destination`
- `projects header adds and manages a registry project`
- `workspace overview uses real project data instead of seed items`
- `composer submit binds task to the selected project session cwd`

## 后续建议

下一步继续做的应该是：

- 把 composer 发起任务与 `project.sessionCwd` 真正绑起来
- 再决定是否需要更细的 recent files / pinned paths / lightweight explorer
- 然后再进入 `pi-host` 的 session cwd 接线
