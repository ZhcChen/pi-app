# macOS ad-hoc 发布与手动更新

- 日期：2026-07-27
- 关联计划：`docs/plans/2026-07-27-macos-ad-hoc-release-and-update.md`

## 问题

Pi App 需要启动用户独立安装的 Pi core、访问下载目录并通过网络检查 GitHub Release，因此不适合使用 Mac App Store 的 App Sandbox 模型。应用同时需要可复制、可验证的 macOS 发布产物，以及不会误称为静默更新的升级路径。

## 方案

- `desktop/scripts/build-macos-release.sh --arch universal` 构建 `arm64 + x86_64` 的 Flutter release bundle，使用 `codesign --force --deep --sign -` 进行 ad-hoc 签名，并校验签名、非 sandbox entitlement、架构和 DMG。
- `.github/workflows/release-desktop.yml` 仅在 `v*.*.*` tag 与 `desktop/pubspec.yaml` build name 一致时发布固定资产 `Pi-App-<version>-macos-universal.dmg`。
- 应用内更新只信任 `ZhcChen/pi-app` 的 GitHub Release 页面和固定下载 URL。下载写入 `~/Downloads/Pi App Updates`，使用 `.part` 文件和真实字节进度。
- 下载成功后通过系统打开 DMG；用户必须显式点击“退出并安装”，由 macOS `NSApplication.shared.terminate(nil)` 退出，再手动替换 Applications 中的应用。此流程不是静默覆盖更新。
- 更新 client 只在打包后的 macOS release 检查网络。debug、test 和非 macOS runtime 返回不支持状态。失败打开 DMG 时应用保持运行，并异步清理受管下载目录中的安装包。

## 可复用约束

- ad-hoc 签名没有可用于安全无感替换应用 bundle 的稳定自动更新通道；直接分发应采用“打开 DMG -> 用户退出 -> 手动覆盖”的交互。
- 下载 URL 的 host、port、path、tag 和 asset name 都要验证；只校验 release JSON 中的文件名不足以防止重定向或路径替换。
- UI 不应直接删除任意 `File`。由更新 client 限制删除目标必须位于其管理的下载目录，便于测试和避免路径混淆。
- Flutter widget test 不应在按钮回调中阻塞等待真实文件系统 I/O；把文件清理责任保留在可替换的 client，测试使用 memory fake 验证状态机。

## 验证

```bash
cd desktop
flutter analyze
flutter test
cd ..
desktop/scripts/build-macos-release.sh --arch universal
```

2026-07-27 本地验证通过：`flutter analyze`、41 个 Flutter 测试、ad-hoc universal DMG 构建、`codesign --verify` 和 `hdiutil verify`。首次真实 GitHub Actions 发布仍需通过正式 version tag 验证。
