# 品牌资源标准化计划

- 任务：标准化根目录品牌资源结构
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

把当前平铺在 `assets/branding/` 下的品牌资源整理成更标准的结构：

- 源文件按亮/暗主题拆分
- 导出文件按平台与尺寸拆分
- 应用内引用更新到新的目录结构

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-brand-assets-standardization.md`
- 重构 `assets/branding/` 目录结构
- 更新 `assets/README.md`、`assets/branding/README.md`
- 更新 `desktop` 中的资源引用路径

## 非目标

- 不重新设计 logo 造型
- 不新增 Windows / Linux 平台图标导出规范
- 不修改业务界面布局

## 执行单元

### 单元 1

- 目标：拆分品牌源文件结构
- 涉及文件 / 模块：`assets/branding/source/**`
- 完成标准：亮/暗主题源文件独立存放

### 单元 2

- 目标：整理导出资源结构
- 涉及文件 / 模块：`assets/branding/export/**`
- 完成标准：macOS app icon 多尺寸导出集中存放

### 单元 3

- 目标：更新说明与应用引用
- 涉及文件 / 模块：`assets/README.md`、`assets/branding/README.md`、`desktop/**`
- 完成标准：文档和代码引用都指向新结构

## 验证方式

- 命令：`find assets/branding -maxdepth 4 -type f | sort`、`flutter analyze`、`flutter test`
- 手工检查：确认目录结构、主题拆分和尺寸导出清晰可读
- 预期证据：根目录资源不再平铺，应用引用正常
