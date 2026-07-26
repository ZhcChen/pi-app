# 公共资源目录

`assets/` 用于存放仓库级公共资源，供 `desktop/` 以及未来其他模块共享使用。

## 当前结构

- `assets/branding/source/`：品牌源文件，按主题拆分
- `assets/branding/export/`：品牌导出文件，按平台和尺寸拆分
- `assets/branding/scripts/`：品牌资源生成脚本
- `assets/branding/GUIDELINES.md`：命名规范与使用规则

## 约定

- 共享素材优先放在 `assets/`，避免散落到各模块内部
- 源文件与导出文件分开存放，不混放
- 同一资源如果存在亮/暗主题版本，放到对应主题目录，而不是继续平铺命名
- 平台图标导出按平台目录和尺寸集合组织，例如 macOS 的 `AppIcon.appiconset`、Windows 的 `.ico`、Linux 的 hicolor 图标层级
