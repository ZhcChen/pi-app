# 品牌导出与规范补全计划

- 任务：补齐品牌资源命名规范、平台导出目录和生成脚本
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在现有 `assets/branding/` 标准化结构基础上，继续补齐缺失部分：

- 增加 Windows / Linux 导出目录
- 增加品牌资源命名与使用规范文档
- 增加仓库内可复用的图标生成脚本

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-brand-export-workflow.md`
- 新增 `assets/branding/scripts/**`
- 新增 `assets/branding/GUIDELINES.md`
- 补充 `assets/branding/export/windows/**`、`assets/branding/export/linux/**`
- 更新相关 README 说明

## 非目标

- 不重新设计 logo 造型
- 不引入额外第三方设计工具链
- 不修改桌面端业务交互

## 执行单元

### 单元 1

- 目标：补齐品牌规范文档
- 涉及文件 / 模块：`assets/branding/GUIDELINES.md`、`assets/branding/README.md`
- 完成标准：命名、主题、用途和平台导出规则清晰

### 单元 2

- 目标：增加平台导出目录与产物
- 涉及文件 / 模块：`assets/branding/export/windows/**`、`assets/branding/export/linux/**`
- 完成标准：目录不再只覆盖 macOS

### 单元 3

- 目标：沉淀图标生成脚本
- 涉及文件 / 模块：`assets/branding/scripts/**`
- 完成标准：仓库内可以重复生成并同步图标资源

## 验证方式

- 命令：`find assets/branding -maxdepth 5 -type f | sort`、`swift assets/branding/scripts/generate_platform_icons.swift`、`flutter analyze`、`flutter test`
- 手工检查：确认目录、脚本和说明文档互相对应
- 预期证据：平台导出目录完整，脚本可运行，应用引用正常
