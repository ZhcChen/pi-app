# 开发与正式包应用数据隔离

- 主题：将 Pi App 自有持久化数据按 Flutter 构建环境隔离
- 状态：已完成
- 日期：2026-07-28
- 引入提交：`4091f1d`
- 关联计划：`docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
- 关联说明：`desktop/README.md`

## 决策

Pi App 不应让默认 debug 的 `flutter run`、debug build 或 profile build 覆盖正式 DMG 用户的偏好、项目注册表或未来项目级元数据。应用以 Flutter 的 `kReleaseMode` 选择数据根目录：

| 构建环境 | Pi App 自有数据根目录 |
| --- | --- |
| debug / profile | `~/.pi-app-dev/` |
| 正式 Release / DMG / `flutter run --release` | `~/.pi-app/` |

`FileDesktopPreferencesStore` 与 `FileProjectRegistryStore` 均调用同一个 `resolvePiAppRootDirectory()`，因此 `settings.json`、`projects/index.json` 和 `projects/<project-id>/project.json` 一起隔离。测试可以继续通过显式 `rootDirectory` 注入完全控制存储位置；该注入优先于构建环境判定。

## 边界

本机制只管理 Pi App 自有数据。以下内容仍属于用户安装的 Pi core 或用户项目，不能被 Pi App 的 debug / Release 数据根目录迁移或复制：

- `~/.pi/agent`、`PI_CODING_AGENT_DIR`、认证、模型配置和全局 prompts
- Pi 管理的 session 文件
- 项目内 `.pi` resources

应用更新的 DMG 仍写入用户可见的 `~/Downloads/Pi App Updates/`。默认更新 client 只在 macOS Release runtime 启用，debug/profile 不会联网下载更新包，因此不会与开发数据根目录产生串用。

## 迁移策略

既有 `~/.pi-app/` 数据保留为正式 Release 数据；开发环境从 `~/.pi-app-dev/` 开始。Pi App 不自动移动、复制或删除任一目录，避免把历史本地数据错误归类为开发数据或正式数据。

## 验证

```bash
cd desktop
flutter test test/app_data_environment_test.dart
flutter analyze
flutter test
flutter build macos --release
```

新增 `desktop/test/app_data_environment_test.dart` 覆盖两个根目录映射，以及开发环境写入偏好和项目注册表后正式环境保持空白。验证结果：专项测试通过，`flutter analyze` 通过，完整 `flutter test` 共 74 项通过，macOS Release build 成功。

## 残余风险

- 用户如果主动在 debug/profile 与 Release 之间复制文件，Pi App 不会阻止或合并该操作；这是显式的用户文件管理行为。
- Pi core 配置与认证刻意保持共享。若未来需要完整隔离 Pi core runtime，本项目必须先设计单独的 auth、session、环境变量和迁移策略，不能复用本目录规则隐式实现。
