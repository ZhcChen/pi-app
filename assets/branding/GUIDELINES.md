# 品牌资源规范

## 目标

这份规范用于约束 `assets/branding/` 下的品牌资源命名、主题拆分、平台导出和使用方式，避免资源继续平铺混放。

## 目录约定

- `source/light/`：浅色主题源文件
- `source/dark/`：深色主题源文件
- `export/macos/`：macOS 平台导出
- `export/windows/`：Windows 平台导出
- `export/linux/`：Linux 平台导出
- `scripts/`：品牌资源生成与同步脚本

## 命名规则

### 源文件

- `pi-mark.svg`：方形标记，用于 app 内品牌位、空态标记、头像位等
- `pi-logo.svg`：横向 logo，用于标题、页眉、说明文档等
- 相同语义资源在不同主题下保持同名，通过目录区分主题，不再用根层平铺文件名区分

### 导出文件

- macOS 正式版：`export/macos/AppIcon.appiconset/app_icon_<size>.png`
- macOS 开发版：`export/macos/AppIconDev.appiconset/app_icon_<size>.png`
- Windows PNG：`export/windows/png/app_icon_<size>.png`
- Windows ICO：`export/windows/ico/app_icon.ico`
- Linux：`export/linux/hicolor/<size>x<size>/apps/pi-app.png`

## 使用规则

- 应用内普通界面优先引用 `source/` 下的 SVG，而不是直接引用 `export/` 里的平台导出文件
- app bundle、安装包图标、桌面快捷方式图标优先使用 `export/` 下的平台导出文件
- 亮色界面使用 `source/light/`，暗色界面使用 `source/dark/`
- 不要把平台图标导出再次手工改名后散落到其他模块目录

## 生成流程

在仓库根目录执行：

```bash
swift assets/branding/scripts/generate_platform_icons.swift
```

这个脚本会：

- 重新生成 macOS 图标导出集
- 重新生成 Windows PNG 与 `.ico` 导出集
- 重新生成 Linux hicolor PNG 导出集
- 把 macOS 正式图标同步到 `desktop/macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- 把 macOS 开发图标同步到 `desktop/macos/Runner/Assets.xcassets/AppIconDev.appiconset/`
- 把 Windows `.ico` 同步到 `desktop/windows/runner/resources/app_icon.ico`
- 把 Linux hicolor 图标和 `.desktop` 文件同步到 `desktop/linux/runner/resources/`

## 变更原则

- 修改品牌造型时，优先更新 `source/` 与脚本中的平台导出模板，再统一重新导出
- `AppIcon` 是正式 Release 图标；`AppIconDev` 仅供 macOS Debug/Profile 使用，右下角圆点是开发身份标记
- 不直接手工改单个导出 PNG 或 `.ico` 作为长期维护方式
- 平台导出规则新增时，继续放到 `export/<platform>/`，不要回到根层平铺
