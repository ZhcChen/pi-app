# desktop runtime capability 边界

- 主题：为桌面端设置页中的平台相关能力建立统一 runtime capability 边界
- 日期：2026-07-26
- 关联计划：`docs/plans/2026-07-26-desktop-follow-up-roadmap.md`

## 摘要

这轮先收口了 `showInMenuBar`：

- Dart 侧通过 `DesktopRuntimeCapabilities` 显式声明平台能力
- `PlatformDesktopRuntimeController` 负责把偏好同步到真实运行时
- macOS 通过原生 `AppDelegate.swift` 接入 menu bar status item 与窗口恢复
- Windows / Linux 暂时明确降级为 unsupported，而不是保留一个“能点但无约定”的开关

## 为什么要先加 capability 层

`showInMenuBar` 这种设置不是纯 UI 状态，而是强平台耦合能力：

- macOS 有 menu bar status item
- Windows / Linux 未必有同等 tray 行为，或者实现代价不同
- widget test 无法直接证明原生行为本身，只能验证 Dart 侧是否正确同步与降级

如果不显式定义 capability，设置页就只能二选一：

- 开关始终可点，但在部分平台静默无效
- 在 UI 层直接写死平台判断，导致运行时边界散落到页面里

前者会制造灰区，后者会让后续 `openDestination`、tray、外部启动等能力继续复制同样的问题。

## 当前做法

### 1. runtime controller 暴露 capability

`desktop/lib/src/app_runtime.dart` 中新增：

- `DesktopRuntimeCapabilities`
- `DesktopRuntimeController.capabilities`

当前先暴露：

- `supportsShowInMenuBar`

`PlatformDesktopRuntimeController` 会根据当前平台给出默认能力；`MemoryDesktopRuntimeController` 则允许测试显式注入支持/不支持状态。

### 2. 平台同步仍留在 runtime 层

设置页不会直接碰原生 channel。

它只接收 capability 并决定：

- 是否允许修改开关
- 应该展示正常说明，还是 unsupported 文案

真实平台同步仍由 `PlatformDesktopRuntimeController.sync(...)` 执行，这样后续 `openDestination` 也可以沿用同一分层。

### 3. unsupported 必须是显式状态

这轮没有在 Windows / Linux 上假装支持 tray。

当前约定是：

- `supportsShowInMenuBar = false`
- 设置页禁用 `showInMenuBar` 开关
- 说明文案改为“当前只有 macOS 支持此行为”
- runtime sync 对该项执行 no-op

这比“允许修改但实际上不生效”更清楚，也更容易在后续替换成真实 tray 实现。

## macOS 原生桥接约定

`desktop/macos/Runner/AppDelegate.swift` 当前负责：

- 通过 `FlutterMethodChannel("pi.dev/desktop_runtime")` 接收 Dart 同步
- 在 `showInMenuBar = true` 时创建 `NSStatusItem`
- 点击 menu bar icon 时恢复主窗口
- 关闭主窗口时，如果该能力开启，则隐藏窗口而不是退出应用
- `applicationShouldTerminateAfterLastWindowClosed` 根据该开关决定是否退出

这意味着：

- 同一份 `AppPreferences.showInMenuBar` 已经不仅是持久化字段，而是实际运行时行为
- 后续如果需要扩展 menu bar menu 项，而不是只有点击恢复窗口，也可以继续在这个 channel 下演进

## 适用边界

后续遇到以下能力时，优先沿用同样模式：

- `openDestination` 的真实外部启动
- tray / menu bar / dock 之类的壳层行为
- 需要按平台启用、禁用或降级的 runtime 开关

不适合放进 capability 层的，是纯 UI 偏好或纯 Dart 内可完全决定的行为，例如：

- `themeMode`
- `uiScale`
- `showBottomPanel`
- `suggestedPrompts`

## 验证 / 证据

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`
- widget / runtime tests 已覆盖：
  - supported runtime sync
  - unsupported show-in-menu-bar no-op
  - unsupported 平台下设置页 switch disabled

## 后续事项

- `openDestination` 开始真实化时，继续复用 `DesktopRuntimeCapabilities + runtime sync + UI degrade` 这套分层
- 如果未来为 Windows / Linux 接入真实 tray，实现后只需要调整 capability 和 bridge，不必重写设置页交互
