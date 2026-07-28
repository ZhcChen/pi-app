# macOS 开发应用身份与图标隔离

- 主题：让 Pi App 的 Debug/Profile 与正式 Release 在 macOS 上可并存、可辨认
- 状态：已完成
- 日期：2026-07-28
- 引入提交：`bc06fbe`
- 关联计划：`docs/plans/2026-07-28-macos-development-app-identity.md`
- 关联说明：`desktop/README.md`

## 决策

Pi App 的开发环境不能只依赖 `flutter run` 的调试器状态来区分。macOS 的 Finder、Dock、LaunchServices、菜单栏和窗口都需要一个稳定的开发应用身份，才能与正式 DMG 安装的应用同时存在。

| 构建配置 | 应用名 | Bundle ID | 图标 | Pi App 自有数据根 |
| --- | --- | --- | --- | --- |
| Debug | `Pi App Dev` | `dev.pi.piDesktop.dev` | `AppIconDev`，右下角橙色圆点 | `~/.pi-app-dev/` |
| Profile | `Pi App Dev` | `dev.pi.piDesktop.dev` | `AppIconDev`，右下角橙色圆点 | `~/.pi-app-dev/` |
| Release | `Pi App` | `dev.pi.piDesktop` | `AppIcon` | `~/.pi-app/` |

`flutter run --release` 是 Release 构建，因此有意使用正式应用身份和正式数据根；它是 Release-mode smoke，不替代 DMG、签名和 Gatekeeper 的正式交付验证。

## 实现

- `assets/branding/scripts/generate_platform_icons.swift` 现在生成正式 `AppIcon` 和开发 `AppIconDev` 两个完整 macOS asset catalog。圆点烘焙进各尺寸 PNG，而不是依赖 Dock 的文本 badge，因此 Finder、未启动的 app bundle、Dock 和菜单栏都使用一致图标。
- Xcode 的 Debug/Profile target settings 覆盖 `PRODUCT_NAME`、`PRODUCT_BUNDLE_IDENTIFIER` 与 `ASSETCATALOG_COMPILER_APPICON_NAME`；Release 保留 `AppInfo.xcconfig` 中的正式身份。
- `AppDelegate` 从最终 bundle 的 `CFBundleIconFile` 动态加载 `.icns`，不再硬编码 `AppIcon`。菜单栏 tooltip 同步读取 `CFBundleName`。
- Dart 的 `piAppDisplayName()` 与已有的 `resolvePiAppStorageEnvironment()` 使用同一个 `kReleaseMode` 判定。窗口标题、`MaterialApp` title 和许可证页随构建模式改变。
- 原生 `RunnerTests` host 已更新为对应的 `Pi App Dev.app` 或 `Pi App.app` executable，避免 Xcode 继续引用旧模板的 `pi_desktop.app`。
- `desktop/scripts/verify-macos-app-identity.sh` 校验构建后 bundle 的名称、Bundle ID、图标名、可执行文件和 `.icns` 资源；tag 驱动的 macOS Release workflow 会在上传 DMG 前执行 Release verifier。

## 开发与正式交付

日常开发启动开发身份应用：

```bash
cd desktop
flutter run -d macos
```

如需独立启动 Debug bundle：

```bash
cd desktop
flutter build macos --debug
open "build/macos/Build/Products/Debug/Pi App Dev.app"
```

正式发布仍只使用现有 universal DMG 流程：

```bash
./desktop/scripts/build-macos-release.sh --arch universal
```

这不会生成公开 Dev DMG，也不会改变 GitHub Release 资产、应用内更新协议或 Release DMG 名称。

## 验证

执行并通过：

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

结果：`flutter analyze` 通过，完整 `flutter test` 共 77 项通过，三种 macOS bundle verifier 通过，`xcodebuild test` 通过，Release universal DMG 的 ad-hoc 签名、双架构和 `hdiutil verify` 均通过。构建后的 `AppIconDev.icns` 已渲染检查，右下角圆点可见。

## 残余风险与边界

- macOS 可能缓存 Finder/Dock 图标。验证时应使用新的 `Pi App Dev.app` 名称或干净路径，不能只覆盖旧 app 后观察缓存图标。
- Pi core 的 `~/.pi`、认证、Pi session、模型配置和项目 `.pi` resources 仍是外部 Pi 数据，不因本应用身份分离而隔离。
- Windows/Linux 仍使用单一 native application ID 和图标。后续实现各自平台的 installer/runtime 时，需要分别设计 Windows AppUserModelID、Linux GTK application ID、desktop entry、图标和可执行文件名；不能从 Dart 层假设它们已具备 macOS 等价隔离。
