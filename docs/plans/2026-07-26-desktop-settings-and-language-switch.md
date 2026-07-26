# desktop 设置页与语言切换计划

- 任务：按参考图补齐 `desktop` 设置页，并接入应用级语言切换
- 状态：已完成
- 负责人：Pi
- 日期：2026-07-26

## 目标

在现有桌面壳层基础上完成两项能力：

- 新增独立的设置视图，布局参考用户提供的设计图
- 在设置页中接入真实可用的语言切换，切换后主界面与设置页文案同步变化

## 范围

这次会改动：

- 新增 `docs/plans/2026-07-26-desktop-settings-and-language-switch.md`
- 重构 `desktop/lib/main.dart` 的顶层状态与页面切换
- 新增设置页导航、通用设置内容区、语言下拉选择
- 更新 `desktop/test/widget_test.dart`

## 非目标

- 不接入持久化存储
- 不在本轮补齐所有设置项的真实后端行为
- 不在本轮引入完整 Flutter intl 本地化工程

## 执行单元

### 单元 1

- 目标：建立应用页 / 设置页双视图结构
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 完成标准：可从主界面进入设置页，并能返回应用页

### 单元 2

- 目标：按参考图绘制设置页 `General` 视图
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 完成标准：左侧设置导航、右侧通用设置卡片与控件成型

### 单元 3

- 目标：接入应用级语言切换
- 涉及文件 / 模块：`desktop/lib/main.dart`
- 完成标准：语言切换后，设置页与主界面关键文案同步变化

### 单元 4

- 目标：回归验证
- 涉及文件 / 模块：`desktop/test/widget_test.dart`
- 完成标准：`flutter analyze`、`flutter test` 通过

## 验证方式

- 命令：`flutter analyze`、`flutter test`、`flutter build macos --debug`
- 手工检查：设置页结构、层级、控件密度与参考图接近；语言切换对主界面和设置页都生效
- 预期证据：可以进入设置页、切换语言、返回主界面并看到文案更新
