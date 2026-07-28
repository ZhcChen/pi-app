# macOS Ad-hoc 发布与 GitHub 更新执行计划

- 任务：为 Pi App 建立 macOS ad-hoc 签名、tag 驱动 GitHub Release、架构匹配 DMG 资产，以及应用内下载并打开安装器的更新流程
- 状态：待首个正式 tag 验证（发布与更新实现已完成）
- 负责人：Pi
- 日期：2026-07-27
- 关联计划：
  - `docs/plans/README.md`（计划入口、状态约定与当前执行队列）
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`（唯一总看板）
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/brainstorms/2026-07-27-managed-pi-core-runtime.md`

## 当前进度

- [x] R1：移除 App Sandbox，增加 universal ad-hoc 重签、签名 / entitlement / DMG / 架构验证脚本，并完成本机构建。
- [x] R2：提交 tag 驱动 GitHub Actions workflow；尚未推送 release tag，因此远端构建与发布仍待首次正式版本验证。
- [x] U1：完成 GitHub latest release 检查、严格 asset URL、semver 和流式下载 domain service 及回归测试。
- [x] U2：完成 Settings 更新入口、打开 DMG 与 macOS 强制退出 bridge，并完成 widget / release build 验证。
- [ ] D1：在满足主路线图 P0-P3 前置后，创建 `v0.1.0`，验证 GitHub Actions、universal DMG、GitHub Release、应用内更新和手动覆盖安装闭环。

> 本计划的实现单元已完成；当前状态不是新的开发切片，而是等待正式 tag 的真实交付验收。tag 必须等于 `desktop/pubspec.yaml` 的 build name，即当前 `0.1.0+1` 对应 `v0.1.0`。

## 目标

macOS 版本可以在 GitHub Actions 中构建 universal Flutter release app，以 ad-hoc 签名验证后封装为 DMG 并发布到 GitHub Release。Pi App 能检查当前仓库的最新正式 Release，选择 universal DMG，显示真实下载进度、打开安装器，并在用户确认后退出当前应用以完成手动覆盖安装。

这一阶段继续采用 ad-hoc 签名，明确不承诺 Gatekeeper 信任、notarization、自动原地覆盖或静默更新。

## 已确认决策

1. macOS release 使用 `codesign --sign -` 的 ad-hoc 签名。
2. GitHub Release 由推送 `vX.Y.Z` tag 触发；tag 必须与 `desktop/pubspec.yaml` 的 build name 一致。
3. Flutter 当前 macOS 配置产出 universal (`arm64` + `x86_64`) bundle，首版只发布一个 DMG，资产名固定为 `Pi-App-<version>-macos-universal.dmg`。
4. 更新检查使用 GitHub Releases API；ad-hoc macOS 更新下载 DMG 并打开安装器，不尝试应用内二进制替换。
5. 当前 Release App Sandbox 必须移除。Pi App 是直接分发的 Pi core GUI，需访问网络、下载目录并启动外部 Pi core；这与 App Store sandbox 分发模型不兼容。
6. Developer ID、hardened runtime、notarization、delta update、Windows/Linux release 和自动更新服务不在本阶段。

## 范围

- `desktop/macos/Runner/*.entitlements` 的直接分发运行时边界。
- macOS release build、ad-hoc 重签、签名验证与 DMG 打包脚本。
- `.github/workflows/release-desktop.yml` 的 tag 校验、universal macOS 构建、artifact 汇总与 GitHub Release 发布。
- Flutter update domain model、GitHub API 访问、版本比较、DMG 选择、下载进度、打开安装器与退出应用。
- Settings General 页的版本、检查更新、下载状态与安装操作。
- 版本与发布流程文档。

## 非目标

- 不将 Node、Pi SDK 或 `host/` 放入 DMG。
- 不使用 Developer ID certificate、Apple notarization 或 App Store distribution。
- 不把 ad-hoc 签名误表示为受 Apple 信任的发行签名。
- 不在应用内挂载 DMG、复制 app 或绕过用户的覆盖安装动作。
- 不自动检查并下载 prerelease；首版只消费 GitHub `releases/latest`。
- 不在本阶段实现 Pi core 本身的更新。

## 发布与更新契约

| 项目 | 契约 |
| --- | --- |
| Git tag | `v<build-name>`，例如 `v0.1.0` |
| Flutter 版本来源 | `desktop/pubspec.yaml` 的 `version: <build-name>+<build-number>` |
| macOS assets | `Pi-App-<build-name>-macos-universal.dmg` |
| 签名 | `codesign --force --deep --sign -`，随后 `codesign --verify --deep --strict` |
| Release 来源 | `https://api.github.com/repos/ZhcChen/pi-app/releases/latest` |
| 更新选择 | 仅接受 `https://github.com/ZhcChen/pi-app/releases/download/<tag>/` 下的 `macos-universal` DMG |
| 下载目录 | `~/Downloads/Pi App Updates/` |
| 安装行为 | 下载完成后使用 macOS `open` 打开 DMG；用户确认退出 Pi App 后手动拖拽覆盖 |

## 实现思路

1. 移除发布 app 的 App Sandbox entitlement。保留开发调试所需的 JIT entitlement，但不把 sandbox 假设带入直接分发 release。
2. 新增可在本机和 CI 复用的 shell scripts：校验 release tag、读取 pubspec version、构建 release、ad-hoc 重签、验证 bundle、生成 DMG、检查产物架构。
3. GitHub Actions 使用一个 macOS runner 构建并验证 universal bundle，上传一个 DMG；publish job 汇总后创建/更新 GitHub Release。
4. 新增 `AppUpdateClient`：通过注入式 HTTP / runtime 信息来源解析 GitHub latest release，严格比较 semver，并拒绝仓库外、错误平台、错误架构或非 DMG 的资产。
5. update downloader 使用流式下载回调驱动 UI；只有响应提供总大小时显示百分比，否则显示已下载字节和阶段状态。
6. 打开 DMG 后不静默终止进程。UI 显示“安装器已打开”，由用户点击“退出并安装”调用 macOS runtime bridge 强制退出，绕开 menu bar 的普通关闭拦截。

## 阶段拆分

### 阶段 1：R1 发布打包与 ad-hoc 签名

- 目标：本机与 CI 都能生成经过 ad-hoc 签名验证的 universal DMG。
- 边界：只做 macOS release 产物，不接入更新 UI。
- 验收重点：universal asset 名称、`CFBundleShortVersionString`、代码签名和 DMG 内容均可验证。

### 阶段 2：R2 GitHub Actions Release

- 目标：通过 semver tag 自动校验、构建、汇总并发布 GitHub Release。
- 边界：不推送 tag、不创建真实 Release；只提交 workflow。
- 验收重点：workflow 使用最小 `contents: write` 权限，build jobs 无发布权限；失败资产不会发布。

### 阶段 3：U1 更新服务

- 目标：实现 GitHub latest release 检查、semver、universal DMG 选择和真实下载状态。
- 边界：不自动安装、不读取 GitHub token、不支持 prerelease。
- 验收重点：网络 / 解析失败不影响主功能，资产 URL 白名单和版本比较有单元测试。

### 阶段 4：U2 更新设置界面与退出安装

- 目标：将 U1 接入 Settings General 页，提供检查、下载、打开 DMG、退出应用动作。
- 边界：只支持打包 release 的 macOS；debug / test 环境禁止安装操作。
- 验收重点：下载进度真实、错误可重试、DMG 打开后用户显式退出，menu bar 不会把“退出”降级成隐藏窗口。

## 执行单元

### R1：移除 Sandbox 与本地 macOS 打包脚本

- 所属阶段：阶段 1。
- 涉及文件 / 模块：`desktop/macos/Runner/Release.entitlements`、`desktop/macos/Runner/DebugProfile.entitlements`、新增 `desktop/scripts/*.sh`、`.gitignore`、`desktop/README.md`。
- 验证方式：`flutter build macos --release`、`codesign --verify --deep --strict --verbose=2`、`codesign -d --entitlements :-`、`hdiutil verify`、`lipo -archs`。
- 完成标准：生成 universal DMG，bundle 为 ad-hoc 签名且不含 `com.apple.security.app-sandbox`。

### R2：GitHub Actions Release Workflow

- 所属阶段：阶段 2。
- 涉及文件 / 模块：`.github/workflows/release-desktop.yml`、release tag 校验脚本、发布文档。
- 前置依赖：R1。
- 验证方式：workflow YAML 语法检查、tag/version script 的正反例、GitHub Actions dry review。
- 完成标准：universal build artifact 仅在校验通过后进入 publish job；publish job 用 `gh release create/edit` 发布固定资产名。

### U1：Update Domain Service

- 所属阶段：阶段 3。
- 涉及文件 / 模块：新增 `desktop/lib/src/app_update_service.dart`、`pubspec.yaml`、测试。
- 前置依赖：R2 的 release asset contract。
- 验证方式：mock GitHub API、stable/prerelease semver、错误 asset、错误 URL、arch selection、streamed download progress。
- 完成标准：只接受预期仓库的 `macos-universal` DMG；失败返回可显示状态，不抛出到主 UI。

### U2：Settings Update Surface 与 Quit Bridge

- 所属阶段：阶段 4。
- 涉及文件 / 模块：`desktop_shell.dart`、`settings_feature.dart`、`settings_view.dart`、`app_copy.dart`、`app_runtime.dart`、`macos/Runner/AppDelegate.swift`、widget tests。
- 前置依赖：U1。
- 验证方式：Memory update client 驱动的 widget tests；macOS packaged app 手工检查下载 / 打开 / 退出路径。
- 完成标准：UI 仅在 release 且发现更新后允许下载；下载完成后明确显示手动覆盖步骤，退出按钮真正终止应用。

## `/goal` 建议作用域

1. `/goal R1`：entitlement、ad-hoc sign、DMG script 和本机构建验证。
2. `/goal R2`：GitHub Actions workflow、tag validator 和发布文档。
3. `/goal U1`：更新 domain service 与纯 Dart tests。
4. `/goal U2`：Settings UI、macOS quit bridge 与 widget / packaged smoke test。

## 验证方式

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --release`
- `desktop/scripts/build-macos-release.sh --arch universal`
- `codesign --verify --deep --strict --verbose=2 "release/macos-universal/Pi App.app"`
- `hdiutil verify "release/macos-universal/Pi-App-<version>-macos-universal.dmg"`
- 手工检查 GitHub Actions 的 tag/version gate 和发布资产名。
- 手工检查：在 ad-hoc signed release app 中发现更新、下载 DMG、打开 DMG、点击退出后完成覆盖安装。

## 风险 / 待确认问题

- ad-hoc 签名不具备 Developer ID 信任，用户可能需要在 Gatekeeper 中显式允许首次打开。notarization 后续再评估。
- GitHub `releases/latest` 只返回最新稳定 release；预发布渠道需要单独设计。
- GitHub API 未认证请求有速率限制；更新检查必须用户触发且失败静默可恢复，不能阻塞会话。
- direct distribution 移除 App Sandbox 是外置 Pi core 和完整 coding tools 的必要条件，也意味着 Pi App 不再符合 Mac App Store sandbox 发布要求。
- 退出应用只在 DMG 已成功打开后允许；下载或打开失败不得关闭正在运行的 Pi session。

## 沉淀跟进

- 完成后将 ad-hoc 签名、DMG 资产和手动更新限制写入 `docs/solutions/`。
- 每次发布在能力版本矩阵记录 Pi App build version、Git tag、asset hash、签名模式和验证证据。
