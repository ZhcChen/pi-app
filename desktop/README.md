# desktop

`desktop/` 是当前仓库中的 Flutter 桌面端模块，用来开发基于 `pi.dev` 的 GUI 客户端。

## 当前定位

- 目标平台：`windows`、`macos`、`linux`
- 当前范围：可按项目 cwd 创建 Pi session、发送 prompt、接收文本流并 abort 的桌面工作台
- 后续接入：session 列表/恢复、完整工具 timeline、trust/approval UI 与 sidecar 打包

## 目录说明

- `lib/`：Flutter 应用代码
- `linux/`、`macos/`、`windows/`：各桌面平台 runner
- `test/`：基础 Widget 测试

## 开发约定

- 字体与文字 token：`desktop/lib/src/desktop_design.dart`
- 公开偏好模型：`desktop/lib/src/app_preferences.dart`
- 偏好持久化：`desktop/lib/src/app_persistence.dart`
- 运行时桥接：`desktop/lib/src/app_runtime.dart`
- 共享 design helpers：`desktop/lib/src/desktop_design.dart`
- shared desktop primitives：`desktop/lib/src/desktop_primitives.dart`
- workspace feature root：`desktop/lib/src/workspace_feature.dart`
- settings feature root：`desktop/lib/src/settings_feature.dart`
- 设置页基础组件：`desktop/lib/src/settings_components.dart`
- 工作区基础组件：`desktop/lib/src/workspace_components.dart`
- settings 组件说明：`docs/solutions/2026-07-26-desktop-settings-components.md`
- workspace 组件说明：`docs/solutions/2026-07-26-desktop-workspace-components.md`
- shared primitives 说明：`docs/solutions/2026-07-26-desktop-shared-primitives.md`
- runtime capability 说明：`docs/solutions/2026-07-26-desktop-runtime-capabilities.md`
- openDestination 说明：`docs/solutions/2026-07-26-desktop-open-destination.md`
- Pi Config Center 说明：`docs/solutions/2026-07-26-desktop-pi-config-center.md`
- workspace project overview 说明：`docs/solutions/2026-07-26-desktop-project-overview.md`
- pi 集成形态说明：`docs/solutions/2026-07-26-pi-integration-modes.md`
- pi-host SDK contract：`docs/solutions/2026-07-27-pi-host-sdk-contract.md`
- import 边界说明：`docs/solutions/2026-07-26-desktop-import-modules.md`

当前 `desktop/lib/` 采用 hybrid 结构：
- `main.dart` 负责启动入口与对外导出公开类型
- `desktop_shell.dart` 作为当前应用编排层，负责全局偏好、route 切换、feature 注入与最外层壳体，并且本身已是普通 import 模块，不再依赖 `part`
- `workspace_feature.dart` 作为独立的 workspace feature root，挂接 `workspace_view.dart` 与 `workspace_components.dart`
- `settings_feature.dart` 作为独立的 settings feature root，挂接 `settings_view.dart` 与 `settings_components.dart`
- `desktop_design.dart` 与 `desktop_primitives.dart` 提供跨 shell / settings / workspace 共享的 design helpers 与基础 UI primitives
- `app_copy.dart` 与 `app_data.dart` 已迁为独立应用级 import 模块，分别承载双语文案与当前 workspace/project 数据注入
- `app_preferences.dart`、`app_persistence.dart`、`app_runtime.dart` 这类公开、跨层、低 UI 耦合的 core 模块优先使用 `import/export`
- `pi_config_store.dart` 负责 `pi` 全局配置根识别、模型配置读写与 prompt 文件编辑
- `pi_host_client.dart` 负责 Flutter 与本地 `pi-host` sidecar 的 JSONL 通信、进程生命周期和可注入测试实现
- `project_registry_store.dart` 负责 `~/.pi-app/projects/index.json` 项目注册表、`projects/<project-id>/project.json` 项目元数据、旧项目路径迁移与项目别名/固定/最近访问/移除操作
- `pi_config_view.dart` 承接 settings 内部的 `Pi Models` / `Pi Prompts` 页面实现
- `desktop_app.dart` 当前仅保留 `PiDesktopApp` 的兼容导出 shim，避免旧路径瞬时失效；`workspace_feature.dart` 与 `settings_feature.dart` 仍在各自 feature 内部使用 `part`

设置页新增控件时，优先复用 `_SettingsCard`、`_SettingsRow`、`_SettingsFieldBlock`、`_SettingsDropdown<T>`、`_SettingsSegmentedControl<T>`、`_SettingsSwitch`，不要在页面里重新散写一套样式。

工作区新增卡片、侧栏项、状态胶囊或输入区细节时，优先复用 `_PromptCardTile`、`_Composer`、`_WorkspaceBottomPanel`、`_WorkspaceStatusPill`、`_SidebarActionTile`、`_ProjectTile` 等基础组件，不要直接把实现堆回 `workspace_view.dart`。

当同一种 visual pattern 已经跨 settings / workspace 重复出现时，优先继续上提到 `_DesktopSurface`、`_DesktopFieldSurface`、`_DesktopTextActionButton`、`_DesktopIconActionButton`、`_DesktopSelectionTile`、`_DesktopStatusPill` 这一层 shared primitives，而不是继续在两个组件文件里分别复制实现。

## 常用命令

```bash
cd ../host
npm install
npm run build
cd ../desktop
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

在 Windows 或 Linux 上运行时，将最后一条命令替换为对应设备，例如 `flutter run -d windows` 或 `flutter run -d linux`。

## macOS Ad-hoc 发布

Pi App 当前按直接分发模式构建 macOS release：使用 ad-hoc 签名，不使用 App Sandbox、Developer ID 或 notarization。移除 App Sandbox 是外置 Pi core、网络访问、下载更新和完整 coding tools 的必要条件；因此该 build 不能作为 Mac App Store sandbox 版本发布。

本机构建 universal DMG：

```bash
./desktop/scripts/build-macos-release.sh --arch universal
```

脚本会构建 Flutter release、以 `codesign --force --deep --sign -` 重签、验证签名和 entitlement、确认 `arm64` / `x86_64` 都存在，并输出：

```text
release/macos-universal/Pi-App-<version>-macos-universal.dmg
```

该目录已被 Git 忽略。ad-hoc 签名不具备 Developer ID 信任链，首次打开下载版本时用户可能需要在 Gatekeeper 中显式允许。

## GitHub Release

推送与 `desktop/pubspec.yaml` build name 相同的 semver tag 会触发 `.github/workflows/release-desktop.yml`：

```bash
git tag v0.1.0
git push origin v0.1.0
```

workflow 先校验 tag，再在 macOS 构建 universal ad-hoc DMG，最后创建或更新 GitHub Release。发布资产固定为 `Pi-App-<version>-macos-universal.dmg`，供应用内更新检查使用。不要为同一版本重复推送不同内容的 tag。

## 应用更新

打包后的 macOS release 可在“设置 -> 通用 -> 应用更新”手动检查 GitHub Release。发现更高的稳定版本后，Pi App 只下载本仓库发布的 universal DMG，并显示真实下载进度。

ad-hoc 签名不能安全地进行应用内二进制替换：下载完成后应用会打开 DMG，用户点击“退出并安装”后手动把 Pi App 覆盖到 Applications。下载或打开失败不会退出当前应用。默认更新 client 仅在打包后的 macOS release 启用；debug、test 和非 macOS runtime 会返回不支持状态，不会联网或提供安装包。

## 备注

当前模块已接入真实的本地 `pi-host` SDK runtime：composer 会按选中项目的 `sessionCwd` 创建 Pi session、发送 prompt、展示文本流并支持 abort。新安装的默认 session 不提供内置工具；在设置中显式开启“读取工具”后，新 session 才能使用 `read`、`grep`、`find`、`ls`，开启“编码工具”后还会使用 `bash`、`edit`、`write`。旧版偏好文件会安全迁移为无工具，避免把历史默认值当成能力授权。这不是 sandbox，也尚未实现逐工具 approval。

sidecar 的普通 stdout 会被隔离到 stderr，JSONL 协议保持独占 stdout；sidecar 退出后，旧 host session 会被标记失败，下一次提交会自动创建新 session。开发期需要先构建 `host/`，并使用 Node `>=22.19.0`；最终 app bundle 尚未包含 Node runtime 和 sidecar，这部分属于打包阶段。
