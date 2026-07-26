# desktop 最大化启动与界面细化计划

- 任务：为 `desktop` 增加默认最大化启动，并继续细化主界面
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

让 `desktop` 在桌面端启动时默认进入最大化，同时把主界面继续向参考图收敛，重点细化侧栏密度、主工作区比例、底部输入器层级和整体视觉节奏。

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-shell-refinement.md`
- 调整 `desktop/lib/main.dart` 的窗口初始化与界面细节
- 更新 `desktop/pubspec.yaml` / `pubspec.lock` 以支持窗口控制
- 继续验证 `desktop/test/widget_test.dart`

## 非目标

- 不接入真实后端数据流
- 不处理窗口恢复、记忆尺寸、分屏偏好等持久化行为
- 不修改品牌素材

## 影响区域

- 文件：`desktop/lib/main.dart`、`desktop/pubspec.yaml`、`desktop/pubspec.lock`、`docs/plans/2026-07-26-desktop-shell-refinement.md`
- 模块：`desktop`
- 接口 / 约束：桌面端启动体验；深色 coding client 风格；默认最大化

## 实现思路

1. 使用跨平台桌面窗口控制能力，在应用启动阶段切到最大化。
2. 对照参考图继续压缩视觉噪声，收敛间距、字号、选中态和底部输入器结构。
3. 保持 Widget 测试和静态检查通过，再重启本地预览窗口。

## 执行单元

### 单元 1

- 目标：实现默认最大化启动
- 涉及文件 / 模块：`desktop/lib/main.dart`、`desktop/pubspec.yaml`
- 验证方式：启动预览窗口并观察启动状态
- 完成标准：应用启动后默认进入最大化

### 单元 2

- 目标：细化侧栏和工作区视觉层级
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 验证方式：桌面视口测试、手工预览
- 完成标准：布局更贴近参考图，信息密度更稳定

### 单元 3

- 目标：回归验证并重新启动预览
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 验证方式：`flutter analyze`、`flutter test`、`flutter run -d macos`
- 完成标准：命令通过，预览窗口可见

### 单元 4

- 目标：整理工作区基础组件
- 涉及文件 / 模块：`desktop/lib/src/workspace_view.dart`、`desktop/lib/src/workspace_components.dart`
- 验证方式：`flutter analyze`、`flutter test`
- 完成标准：工作区页面保留壳层与组合逻辑，提示卡、composer、底部状态面板、侧栏项、项目项等基础组件从页面中拆出

### 单元 5

- 目标：补充工作区组件开发文档
- 涉及文件 / 模块：`desktop/README.md`、`docs/solutions/**`
- 验证方式：阅读文档与代码路径
- 完成标准：工作区组件位置、职责与复用约定有明确记录

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter run -d macos`
- 手工检查：确认最大化启动、侧栏、空态区和输入器与参考图一致性更高
- 预期证据：窗口以最大化状态打开，界面结构清晰，测试通过
