# Pi Branding Assets

这一组资源是当前项目的第一版品牌素材，围绕 `π` 语义构建，保持黑白、极简、工具型气质。

## 目录结构

- `source/light/`：浅色主题源文件
- `source/dark/`：深色主题源文件
- `export/macos/AppIcon.appiconset/`：macOS 应用图标导出集
- `export/windows/png/`：Windows 图标 PNG 导出集
- `export/windows/ico/`：Windows `.ico` 导出集
- `export/linux/hicolor/`：Linux hicolor 图标导出集
- `scripts/`：品牌资源生成与同步脚本
- `GUIDELINES.md`：命名规范与使用规则

## 典型文件

- `source/light/pi-mark.svg`
- `source/light/pi-logo.svg`
- `source/dark/pi-mark.svg`
- `source/dark/pi-logo.svg`
- `export/macos/AppIcon.appiconset/Contents.json`
- `export/windows/ico/app_icon.ico`

## 生成方式

在仓库根目录执行：

```bash
swift assets/branding/scripts/generate_platform_icons.swift
```

脚本会重新生成 macOS、Windows、Linux 的平台导出资源，并同步到各自的 `desktop` 平台 runner 目录。
