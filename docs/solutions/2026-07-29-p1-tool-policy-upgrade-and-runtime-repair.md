# P1 完整工具授权与运行时修复

- 主题：完成旧工具策略迁移授权对话、runtime 修复入口和相关回归，使完整 builtin tools 默认值在产品层真正可用
- 状态：已完成
- 日期：2026-07-29
- Pi App 基线：`0.1.0+1`
- 关联计划：
  - `docs/plans/2026-07-27-external-pi-core-rpc-runtime.md`
  - `docs/plans/2026-07-27-pi-app-complete-feature-roadmap.md`
  - `docs/plans/README.md`
  - `docs/solutions/2026-07-28-pi-core-rpc-adapter-migration.md`

## 结果

P1 已补齐 R2/I1 之后剩余的两条产品交互链：

1. 旧版无 `toolPolicyVersion` 的偏好文件在安全迁移为受限状态后，不再静默停留在无工具模式；首次新建 session 前会弹出三选一授权对话：`启用完整工具`、`保持受限`、`取消`。
2. 当 Pi App 准备为新 session 启动官方 `pi --mode rpc`，而当前 `PiCoreRuntimeController` 仍处于 `missing`、`invalidExecutable` 或 `healthCheckFailed` 时，不再只报通用失败字符串，而是弹出 runtime 修复对话：`重新检测`、`打开设置`、`取消`。

## 实现细节

### 工具策略来源建模

`desktop/lib/src/app_preferences.dart` 新增 `AppToolPolicySource`：

- `explicit`：用户已明确保存当前工具策略。
- `migratedLegacy`：旧版无 `toolPolicyVersion` 文件被安全迁移为受限状态，等待首次明确决策。
- `bootstrapRestricted`：持久化偏好尚未加载时的临时受限 bootstrap 状态，只用于避免启动窗口内的权限扩大。

`desktop/lib/src/app_persistence.dart` 现在会把无版本旧文件读成 `migratedLegacy`，把带 `toolPolicyVersion >= 1` 的文件读成 `explicit`。Pi App 保存偏好时继续写回 `toolPolicyVersion: 1`，因此用户一旦选择“保持受限”或“启用完整工具”，后续不再重复弹迁移对话。

### 首次新建 session 的授权对话

`desktop/lib/src/desktop_shell.dart` 在“首次创建新 session”前增加 `tool-policy-upgrade-dialog`：

- `启用完整工具`：将 `defaultPermissions` 与 `fullAccess` 一次性显式置为开启，并立即用完整 builtin allowlist 创建当前 session。
- `保持受限`：只把策略来源改为 `explicit`，保留无 builtin tools，并继续创建当前 session。
- `取消`：不创建 session，也不改写旧偏好。

对话文案明确说明：这里控制的只是 Pi App 请求的 builtin tool allowlist，不是 OS 权限、路径 sandbox 或逐工具审批。

### Runtime 修复路径

同一文件中新增 `pi-core-repair-dialog`，只在“准备创建新 session 且当前使用 production runtime gate”时触发。对话直接引用 I1 的 runtime 状态和诊断说明，给出：

- `重新检测`：再次执行受限 RPC health；若变为 `ready`，继续本次提交。
- `打开设置`：直接跳到 General 设置页的 Pi Core 诊断卡。
- `取消`：终止本次提交。

该修复对话默认只对 production `PiCoreRpcClient` 生效。显式注入的 `MemoryPiHostClient`、`LocalPiHostClient` 等开发/测试 host 不会被 runtime 修复路径拦截；测试需要覆盖该对话时，可显式打开 `enforcePiCoreRuntimeGate`。

### 设置页联动

权限开关现在会把工具策略来源标记为 `explicit`。同时补了一个一致性约束：

- 打开 `Coding tools` 时会隐含打开 `Read tools`。
- 关闭 `Read tools` 时会同时关闭 `Coding tools`。

这样 UI 不会留下“写/ shell 已启用，但只读工具显示关闭”的矛盾状态。

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

新增或更新的聚焦 widget 证据包括：

- legacy 受限偏好选择 `启用完整工具` 后立即以完整 tools 创建 session。
- legacy 受限偏好选择 `保持受限` 后显式保存受限策略，并以空 allowlist 创建 session。
- legacy 受限偏好选择 `取消` 时不创建 session，也不写回显式策略。
- runtime 修复对话可跳转到设置页。
- runtime 修复对话在 `重新检测` 成功后，会继续本次提交并创建 session。

## 残余风险

- `ACC-A1` 的冷启动 runtime `Checking` 候选 S1 仍未关闭；本次只补了“提交时的修复路径”，没有把 I1 的冷启动自动检测问题当作已修复。
- I2 仍未实现官方 installer launcher；runtime 修复对话当前只能重新检测或跳到设置页，不能直接在应用内安装 Pi Core。
- 旧 session 的工具 allowlist 仍由其创建时决定；P1 只影响新建 session，不会在已有 Pi process 上静默改写工具能力。
