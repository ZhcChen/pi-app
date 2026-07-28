# desktop 模块初始化计划

- 任务：初始化 `desktop/` Flutter 桌面客户端模块
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在仓库根目录创建一个可独立运行的 `desktop/` 模块，使用 Flutter 构建，并且仅启用 `windows`、`macos`、`linux` 三个桌面平台。初始化完成后，应能在本机执行依赖获取和基础静态检查。

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-module-bootstrap.md`
- 新增 `desktop/` Flutter 应用骨架
- 补充模块级基础说明，明确该模块用于 `pi.dev` 的 GUI 客户端开发

## 非目标

- 不实现具体业务界面
- 不接入 `pi agent` 运行时、IPC、进程托管或会话管理
- 不引入多模块工作区工具（如 melos）
- 不处理移动端、Web 平台

## 影响区域

- 文件：`docs/plans/2026-07-26-desktop-module-bootstrap.md`、`desktop/**`
- 模块：`desktop`
- 接口 / 约束：Flutter 3.41.x；目标平台仅 `windows/macos/linux`

## 实现思路

1. 先记录初始化范围、边界和验证方式，避免后续把桌面端长期任务直接当成单次大改。
2. 使用 `flutter create` 生成 `desktop/` 应用骨架，并限制平台为 `windows,macos,linux`。
3. 调整默认说明文字，使模块语义指向 `pi.dev` GUI 客户端；随后执行 `flutter pub get` 与基础检查。

## 阶段拆分

### 阶段 1

- 目标：完成 `desktop/` 初始化脚手架
- 边界：仅限 Flutter 默认骨架和最小必要元数据调整
- 验收重点：目录完整、桌面平台配置存在、命令可运行

### 阶段 2

- 目标：为后续接入 `pi agent` 预留清晰模块定位
- 边界：只写说明，不落具体接入实现
- 验收重点：模块用途明确，后续工作入口清晰

## 执行单元

### 单元 1

- 所属阶段：阶段 1
- 目标：生成 `desktop/` Flutter 应用
- 涉及文件 / 模块：`desktop/**`
- 前置依赖：本机已安装 Flutter SDK
- 验证方式：`flutter create`、`flutter pub get`
- 完成标准：`desktop/` 目录生成成功且依赖解析通过

### 单元 2

- 所属阶段：阶段 1
- 目标：确认平台范围仅包含桌面端
- 涉及文件 / 模块：`desktop/macos`、`desktop/linux`、`desktop/windows`
- 前置依赖：单元 1 完成
- 验证方式：检查目录与配置文件
- 完成标准：不存在 `android/`、`ios/`、`web/` 平台目录

### 单元 3

- 所属阶段：阶段 2
- 目标：补充模块用途说明与基础检查
- 涉及文件 / 模块：`desktop/README.md`、`desktop/lib/main.dart`
- 前置依赖：单元 1 完成
- 验证方式：`flutter analyze`
- 完成标准：模块说明明确，静态检查通过

## 历史 `/goal` 记录

- 历史 `/goal` 曾绑定“desktop 模块初始化脚手架”这一组连续单元；该单元已完成。
- 当前 Pi App 功能开发的计划与执行入口以 `docs/plans/README.md` 为准。

## 验证方式

- 命令：`flutter pub get`、`flutter analyze`
- 手工检查：确认 `desktop/` 目录只包含桌面平台工程
- 预期证据：命令成功、分析无错误、模块说明可读

## 风险 / 待确认问题

- 后续如果需要嵌入 `pi` 二进制、Node 运行时或本地扩展，可能要补充桌面端进程管理方案
- 当前仓库尚未初始化 git，后续提交流程需要在仓库层面补齐

## 沉淀跟进

- 若后续确定 `pi agent` 在 Flutter 桌面端中的进程托管方式，可沉淀到 `docs/solutions/`
