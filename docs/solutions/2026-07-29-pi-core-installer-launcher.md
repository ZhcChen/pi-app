# Pi Core 官方安装器 Launcher

- 主题：I2 为 Pi App 提供官方 `pi.dev/install.sh` 下载、可见 Terminal 启动、本地日志与 runtime 重新检测闭环
- 状态：I2 已实现，待验收
- 日期：2026-07-29
- Pi App 基线：`0.1.0+1`
- 关联计划：
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/plans/README.md`
  - `docs/plans/2026-07-28-current-baseline-acceptance-plan.md`

## 结果

I2 的产品实现已经接入当前桌面壳，但还没有完成真实外部 `install.sh` 的干净 macOS 手工 smoke，因此状态保持为“待验收”，不提前写成“已完成”。

当前交付包括：

1. 设置页的 Pi Core runtime 卡新增“官方安装器”区块。
2. Pi App 只会下载固定官方来源 `https://pi.dev/install.sh`。
3. 下载后会在临时目录生成：
   - 原始 `install.sh`
   - 本地 wrapper `run-pi-core-installer.command`
   - `pi-core-installer.log`
4. 安装器只通过 macOS 可见 Terminal 启动；Pi App 不隐藏执行 `curl | sh`。
5. 应用内显示真实字节进度、来源 URL、脚本路径和日志路径，并在启动后轮询 `PiCoreRuntimeController`。
6. 用户可以停止等待而不取消外部安装器，并可重新继续等待或直接打开日志。
7. 侧栏原来的 `Download Pi Core` 死控件已改为打开设置页的 Pi Core 区域，不再是空操作表面。

## 实现细节

### 官方来源与本地文件

新增 `desktop/lib/src/pi_core_installer.dart`：

- `OfficialPiCoreInstallerClient.sourceUri` 固定为 `https://pi.dev/install.sh`。
- `prepareInstaller()` 使用流式 HTTP 下载脚本，并按真实字节数回调进度。
- 下载目录位于系统临时目录下的独立工作目录；失败时会清理半成品目录。
- wrapper `.command` 会把来源、脚本路径和日志路径打印到 Terminal，并尽量用 `script -aq` 记录交互日志；没有 `script` 时回退到 `tee`。

这里的设计刻意不宣称“本地下载完成 = 内容完整性校验通过”。Pi App 只展示官方来源 URL 和本地路径，不额外伪装成签名校验器。

### 可见 Terminal bridge

`desktop/lib/src/app_runtime.dart` 为 `DesktopRuntimeController` 新增 `runScriptInTerminal()`：

- macOS 使用 `open -a Terminal <wrapper.command>`。
- memory fake 会记录最后一次启动的脚本路径，便于 widget test 验证。
- 该 bridge 与普通“打开文件”“打开目录”分离，避免把 installer 错当作一般文件打开流程。

### Settings / Shell 状态机

`desktop/lib/src/desktop_shell.dart` 和 `settings_view.dart` 现在维护一条独立的 installer 状态链：

- `安装 Pi Core`：下载官方脚本并启动 Terminal。
- `停止等待`：停止应用内轮询，但不影响外部 Terminal 里的安装器。
- `继续等待`：恢复轮询 `PiCoreRuntimeController.refresh()`。
- `打开日志`：用系统文件打开器直接打开 `pi-core-installer.log`。

runtime 卡会显示：

- 当前 installer 状态文案
- 下载进度条
- 来源 URL
- 脚本路径
- 日志路径

当 runtime 转为 `ready` 后，installer 区块会停止等待，并保留日志路径供用户复查。

### 侧栏入口收口

`desktop/lib/src/workspace_view.dart` 中原本无行为的 `Download Pi Core` 图标按钮，现在直接打开设置页的 General/Pi Core 区域。这样当前界面上不再存在“看起来可安装但点击无效果”的入口。

## 验证

```bash
cd desktop
flutter analyze
flutter test
flutter build macos --debug
```

本次验证结果：

- `flutter analyze` 通过。
- `flutter test` 全量通过。
- `flutter build macos --debug` 成功，产物为 `build/macos/Build/Products/Debug/Pi App Dev.app`。

新增自动化证据包括：

- `desktop/test/pi_core_installer_test.dart`
  - 官方 installer 下载与文件生成
  - 下载流失败时清理半成品目录
  - `discardInstaller()` 删除工作目录
- `desktop/test/widget_test.dart`
  - runtime controller 的 `runScriptInTerminal()` delegate
  - 设置页 installer 主链：下载、Terminal 启动、等待 runtime ready
  - 停止等待 / 继续等待 / 打开日志
  - 侧栏 `Download Pi Core` 快捷入口打开设置页

## 残余风险

- 还没有在一次性 macOS 测试用户或满足 ACC-A 硬门的统一启动器下，跑真实官方 `install.sh` 手工 smoke；因此 I2 仍是“待验收”，不是“已完成”。
- `install.sh` 的真实外部行为、Node 缺失时的交互路径、PATH 刷新时机，以及 Terminal/Finder 焦点体验，仍需纳入 ACC-A / ACC-D 的手工证据。
- 当前侧栏快捷入口只负责把用户带到设置页的 Pi Core 区域；真正的安装动作仍在设置卡内进行，避免在主工作区直接弹出外部 installer。
