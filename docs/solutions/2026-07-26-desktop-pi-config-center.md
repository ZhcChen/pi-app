# desktop Pi Config Center 实现记录

- 日期：2026-07-26
- 范围：`desktop/lib/src/pi_config_store.dart`、`desktop/lib/src/pi_config_view.dart`、`settings_feature.dart`
- 关联计划：`docs/plans/2026-07-26-desktop-pi-config-center.md`

## 背景

这轮不是继续扩一般应用偏好，而是把 `pi` 自己的全局配置面收进 `desktop` 设置页。核心约束有两个：

1. `pi` 的实际全局配置根默认是 `~/.pi/agent`，并受 `PI_CODING_AGENT_DIR` 覆盖
2. `pi` 配置不是单一 JSON，而是 `settings.json`、`models.json` 与多份 prompt/context 文件的组合

因此实现上不能把它塞回 `~/.pi-app/settings.json`，也不能只做一个“模型设置”假页。

## 这轮落地

### 1. 单独的数据层

新增 `desktop/lib/src/pi_config_store.dart`：

- `PiConfigStore`
- `FilePiConfigStore`
- `MemoryPiConfigStore`
- `PiConfigSnapshot`
- `PiModelPreferences`
- `PiPromptFileKind`

职责边界：

- 解析全局配置根
- 读取 `settings.json` / `models.json` / `auth.json`
- 读取 `SYSTEM.md` / `APPEND_SYSTEM.md` / `AGENTS.md`
- 将结构化模型偏好合并写回 `settings.json`
- 将高级原始 JSON 写回 `models.json`
- 将空 prompt 内容保存为“删除文件”而不是空壳文件

### 2. 设置页按“结构化 + 原始编辑器”分层

在 `settings` feature 内新增两类真实页面：

- `Pi Models`
- `Pi Prompts`

其中：

- `Pi Models` 承接高频结构化项：
  - `defaultProvider`
  - `defaultModel`
  - `defaultThinkingLevel`
  - `enabledModels`
- `models.json` 保留高级原始编辑器

这样做的原因是：

- 日常默认模型切换应该不需要用户手改 JSON
- 但 `models.json` 涉及 provider schema、compat、headers、routing、thinking map 等复杂结构，第一轮硬做全动态表单会把复杂度抬得过高

### 3. prompt 文件直接作为文件编辑面

`Pi Prompts` 直接对应：

- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- `AGENTS.md`

这里没有再抽成 JSON，是因为它们本来就是文本文件，直接保留文件语义更符合 `pi` 的真实配置模型。

## 关键决策

### 配置根优先级

- 显式注入目录（测试/宿主注入）
- `PI_CODING_AGENT_DIR`
- `~/.pi/agent`

### 结构化编辑只改动模型高频字段

`saveModelPreferences(...)` 只负责：

- `defaultProvider`
- `defaultModel`
- `defaultThinkingLevel`
- `enabledModels`

其余未知字段保持原样，避免这轮 GUI 把别的设置无意覆盖掉。

### 空内容保存等价于删除文件

对 prompt 文件和 `models.json`：

- 保存空内容 -> 删除目标文件

这样比写一个空字符串文件更接近用户对“取消全局覆盖”的预期。

## 验证

已验证通过：

- `cd desktop && flutter analyze`
- `cd desktop && flutter test`
- `cd desktop && flutter build macos --debug`

测试覆盖新增包含：

- `FilePiConfigStore` 的环境变量路径解析与 `settings.json` 合并写回
- 设置页中的 `Pi Models` 交互保存
- 设置页中的 `Pi Prompts` 文件保存

## 后续建议

下一轮继续按计划补：

- `settings.json` 的 runtime / delivery / compaction / retry 高频项
- `resources / advanced` 分类
- `auth.json` / `trust.json` 的更明确状态面与受限入口
