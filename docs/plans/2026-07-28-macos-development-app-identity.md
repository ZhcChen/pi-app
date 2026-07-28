# macOS 开发应用身份与图标隔离

- 任务：让 Pi App 的 Debug/Profile 与正式 Release 在 macOS 上可辨认、可并存，并为开发图标提供右下角圆点标识
- 状态：已完成
- 负责人：Codex
- 日期：2026-07-28

## 目标

macOS Debug/Profile 构建必须生成带开发标识的独立应用身份，能够与正式 `Pi App.app` 同时存在。开发应用在 Finder、Dock 和菜单栏中使用带右下角圆点的图标；Release 保持现有名称、Bundle ID、正式图标与 DMG 交付契约。

| 构建配置 | 应用名 | Bundle ID | App Icon | Pi App 自有数据根 |
| --- | --- | --- | --- | --- |
| Debug | `Pi App Dev` | `dev.pi.piDesktop.dev` | `AppIconDev` | `~/.pi-app-dev/` |
| Profile | `Pi App Dev` | `dev.pi.piDesktop.dev` | `AppIconDev` | `~/.pi-app-dev/` |
| Release | `Pi App` | `dev.pi.piDesktop` | `AppIcon` | `~/.pi-app/` |

`flutter run --release` 是 Release 构建，必须继续使用正式身份与正式数据根。

## 范围

- 为 macOS 生成完整的 `AppIconDev.appiconset`，在 Pi 标记右下角烘焙开发圆点。
- 配置 Debug/Profile 的 macOS product name、Bundle ID 与 app icon。
- 让 `AppDelegate` 从最终 bundle 元数据读取当前图标，保证 Dock 与菜单栏一致。
- 修正原生 XCTest host 路径，并提供可重复执行的 bundle identity 验证。
- 更新开发与发布说明及计划看板。

## 非目标

- 不改变 Pi core 的 `~/.pi`、认证、session、模型配置或项目 `.pi` resources。
- 不改变现有 Release DMG 文件名、签名方式、GitHub Release 或更新资产协议。
- 不在本阶段提供公开发布的开发 DMG；日常 `flutter run`、Debug/Profile `.app` 是开发环境交付物。
- 不提前实现 Windows/Linux 的开发应用身份，两个平台将在各自 native runtime/installer 交付时处理。

## 影响区域

- `assets/branding/scripts/generate_platform_icons.swift`
- `assets/branding/export/macos/AppIconDev.appiconset/`
- `desktop/macos/Runner/Assets.xcassets/AppIconDev.appiconset/`
- `desktop/macos/Runner.xcodeproj/project.pbxproj`
- `desktop/macos/Runner/AppDelegate.swift`
- `desktop/scripts/verify-macos-app-identity.sh`
- `desktop/README.md`、主路线图与 solution 文档

## 实现思路

1. 在现有确定性 Swift 图标生成器中增加 development variant，而不是手工维护单张导出 PNG。
2. 通过 Xcode target build settings 按配置覆盖 `PRODUCT_NAME`、`PRODUCT_BUNDLE_IDENTIFIER` 和 `ASSETCATALOG_COMPILER_APPICON_NAME`；Release 配置不改语义。
3. 原生运行时读取 `CFBundleIconFile`，不以 `#if DEBUG` 判断，确保 Profile 与 Debug 一致，且 `flutter run --release` 保持正式图标。
4. 以构建后的 `Info.plist`、`.icns` 资源和图标像素作为可执行证据，最后手工确认两套 app 同时出现在 Dock。

## 阶段拆分

### 阶段 1：图标与应用身份

- 目标：生成开发图标并将 Debug/Profile 绑定到独立名称、ID 和 asset catalog。
- 边界：不修改 Dart 持久化根目录选择。
- 验收重点：三个构建产物的 `Info.plist`、`.app` 名称和 `.icns` 资源符合目标表。

### 阶段 2：运行时与验证

- 目标：Dock/菜单栏使用当前 bundle 图标，原生测试 host 与构建验证可重复执行。
- 边界：不新增公开开发 DMG 或跨平台 identity 逻辑。
- 验收重点：Debug/Profile 有圆点，Release 无圆点；两个 app 可同时启动。

## 执行单元

### 单元 1：开发图标生成

- 所属阶段：阶段 1
- 目标：在所有 macOS icon size 中生成右下角圆点。
- 涉及文件 / 模块：品牌生成器、macOS export、Runner asset catalog。
- 验证方式：重新运行生成器，检查两个 `.appiconset` 的完整尺寸和 PNG 像素差异。
- 完成标准：正式图标保持不变，开发图标在右下角有清晰圆点。

### 单元 2：Xcode 配置隔离

- 所属阶段：阶段 1
- 目标：建立 Debug/Profile 与 Release 的独立原生身份。
- 涉及文件 / 模块：`project.pbxproj`、原生 test host。
- 验证方式：构建 Debug、Profile、Release 并检查 bundle metadata。
- 完成标准：三个产物满足目标表，Release script 仍找到 `Pi App.app`。

### 单元 3：运行时图标与验证脚本

- 所属阶段：阶段 2
- 目标：消除对 `AppIcon.icns` 的硬编码，并固化验证命令。
- 涉及文件 / 模块：`AppDelegate.swift`、验证脚本、文档。
- 验证方式：Flutter analyze/test、macOS build、bundle verification、人工 Dock/Finder 检查。
- 完成标准：菜单栏图标与当前 app icon 一致，开发/正式实例可以并存。

## `/goal` 建议作用域

- 本任务为连续的 macOS 原生配置闭环，可将 `/goal` 绑定到阶段 1 和阶段 2。
- 不将 Windows/Linux 身份隔离或公开开发 DMG 纳入本任务。

## 验证方式

```bash
swift assets/branding/scripts/generate_platform_icons.swift
cd desktop
flutter analyze
flutter test
flutter build macos --debug
flutter build macos --profile
flutter build macos --release
./scripts/verify-macos-app-identity.sh --configuration debug
./scripts/verify-macos-app-identity.sh --configuration profile
./scripts/verify-macos-app-identity.sh --configuration release
cd macos
xcodebuild test -workspace Runner.xcworkspace -scheme Runner -configuration Debug -destination 'platform=macOS'
cd ../..
desktop/scripts/build-macos-release.sh --arch universal
```

执行结果：`flutter analyze` 通过，完整 `flutter test` 共 77 项通过；Debug、Profile 和 Release bundle verifier 均通过；Debug XCTest 与 Release universal DMG 构建均通过。

手工检查：将 `Pi App Dev.app` 与 `Pi App.app` 放到同一临时目录或 `/Applications`，同时启动并确认 Finder、Dock 和菜单栏图标，开发版右下角圆点可见。

## 风险 / 待确认问题

- macOS 会缓存 Finder/Dock 图标；视觉验收必须使用新 app 名称或干净路径，不能仅依赖覆盖安装后的旧 Dock 缓存。
- `flutter run --release` 会与正式应用共享 identity 和数据，这是既有 Release 契约，不是开发环境。

## 沉淀跟进

完成后记录 macOS build-mode identity 与图标变体的实现和验证路径到 `docs/solutions/`。
