# Pi Core 运行时检测与诊断

- 主题：I1 为 Pi App 提供已安装 Pi core 的路径发现、报告版本采集、受限 RPC health 与设置页诊断
- 状态：已完成
- 日期：2026-07-28
- Pi App 基线：`0.1.0+1`
- 引入提交：`c254f29`
- 版本策略修正提交：`f1926bc`
- Pi core 验证版本：`0.82.0`
- 关联计划：
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-capability-matrix.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`

## 结果

新增 `desktop/lib/src/pi_core_runtime.dart`，由 `PiCoreRuntimeController` 规约四个稳定状态：`missing`、`invalidExecutable`、`healthCheckFailed` 和 `ready`；`checking` 仅作为短暂 UI 状态。

探测优先级固定为 `PI_CORE_EXECUTABLE`、保存的用户绝对路径、`PATH` 中的 `pi`。设置页的 Pi Core 卡展示来源、绝对路径、Pi 报告的版本和安全诊断，并提供刷新、选择可执行文件和清除已选路径操作。选择路径保存到 `~/.pi-app/settings.json` 的 `piCoreExecutablePath` 字段。

`PiCoreRpcClient` 新增动态 executable resolver 与 runtime gate。路径变更只影响后续新建 session；既有 session 继续拥有原有 Pi process，不会被重新配置或串流。health cache 以 executable 为键，切换路径后会重新检测该 runtime。

## 安全与兼容性边界

- `--version` 只作 best-effort 元数据采集。任何版本号、新版、预发布、扩展版本段、无法识别输出、空输出或命令失败都不会阻止启动；页面将其显示为报告版本或“未检测到”。
- health 使用系统临时目录启动独立 `pi --mode rpc --no-approve --no-tools` process，只发送 LF JSONL 的 `get_state` 请求。它不使用项目 cwd、不加载项目 resources、不读取 auth，也不向 UI 暴露原始 RPC record。
- health stdout 严格按 LF 分帧，允许行尾 CR，单条 record 上限 1 MiB；无效 JSON、拒绝 response、超时和启动失败分别规约为稳定诊断码。
- `--version` 与 health process 都在受控 `try/finally` 中清理：先关闭 stdin，再等待退出，必要时升级为 `SIGTERM` 与 `SIGKILL`。
- `PI_CORE_EXECUTABLE` 是显式开发/测试 override，优先于用户选择；设置页会明确显示其来源，避免把 override 误标为普通 `PATH` 发现。

## 验证

```bash
cd desktop
flutter analyze
flutter test
dart run tool/verify_pi_core_runtime.dart --pi /opt/homebrew/bin/pi
flutter build macos --debug
```

本次验证结果：`flutter analyze` 通过，完整 `flutter test` 共 71 项通过，官方 `/opt/homebrew/bin/pi` `0.82.0` 的受限 `get_state` health smoke 通过，macOS debug app 构建成功。

`desktop/test/pi_core_runtime_test.dart` 覆盖缺失、无效路径、不可执行、PATH 发现、`PI_CORE_EXECUTABLE` 优先、新版/预发布/扩展版本、版本信息缺失和 health 失败；`widget_test.dart` 覆盖路径的保存、选择、清除和版本缺失时仍为 Ready；`pi_core_rpc_client_test.dart` 覆盖 runtime gate、executable 切换后的 health cache，以及版本元数据失败后仍能创建 session。

## 残余风险

- Pi `0.82.0` 是当前真实验证证据，不是产品启动上限。上游升级后应重跑 R1 contract、R2 smoke 和本 health smoke，记录结果并修复实际暴露的 schema/语义差异；runtime 不会以版本号拒绝用户已安装的 Pi。
- I2 尚未实现官方 installer launcher；未安装、路径不可用或 health 失败时，I1 只能提供诊断和路径选择，不能在应用内安装。
- 超时清理路径已由代码审查和 process lifecycle 实现覆盖，但尚未加入针对真实故意挂起可执行文件的 PID 级回归；后续 runtime reliability 工作可补充此场景。
- 当前没有真实 GUI 截图驱动的 composer 交互回归；设置卡已有 widget 回归和 macOS debug build 验证。
