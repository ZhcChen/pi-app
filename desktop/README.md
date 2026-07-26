# desktop

`desktop/` 是当前仓库中的 Flutter 桌面端模块，用来开发基于 `pi.dev` 的 GUI 客户端。

## 当前定位

- 目标平台：`windows`、`macos`、`linux`
- 当前范围：初始化桌面端应用骨架与基础界面壳
- 后续接入：`pi agent` 进程托管、会话列表、日志流、工具调用面板

## 目录说明

- `lib/`：Flutter 应用代码
- `linux/`、`macos/`、`windows/`：各桌面平台 runner
- `test/`：基础 Widget 测试

## 常用命令

```bash
cd desktop
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

在 Windows 或 Linux 上运行时，将最后一条命令替换为对应设备，例如 `flutter run -d windows` 或 `flutter run -d linux`。

## 备注

当前模块还没有接入真实的 `pi agent` 运行时；现有界面主要用于承载后续桌面端交互和状态面板。
