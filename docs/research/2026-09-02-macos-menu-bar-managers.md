# macOS 菜单栏 / 刘海管理竞品研究

调研日期：2026-09-02。以下优先采用官网、官方 GitHub、App Store 和 Apple Developer 文档。

## 结论先行

建议产品定位为：

> 自动适应刘海和当前应用菜单宽度的“菜单栏溢出层”，让图标永远可达，同时默认安静、离线、低权限。

MVP 应采用双层能力：

1. **低权限基础模式**：折叠、展开、自动收起、快捷键、可见 / 隐藏 / 始终隐藏三区。
2. **可选增强模式**：授予辅助功能和屏幕录制后，提供图标识别、拖拽编排、刘海下方 Shelf、搜索和临时唤出。

这是最稳妥的产品与技术边界。仅靠公开、沙盒 API 可以做 Hidden Bar 式折叠；Bartender / Ice 式完整管理会涉及辅助功能、截图，甚至私有 WindowServer API，Mac App Store 审核与系统升级兼容性风险明显更高。

## 竞品总览

| 产品 | 核心交互 | 刘海处理 | 价格 / 开源 | 权限与技术特征 | 主要缺口 |
|---|---|---|---|---|---|
| **Bartender 6** | 隐藏分区、hover/click/scroll 展开、搜索、快捷键、分组、Profiles、Triggers | 专门的 Bartender Bar 放在菜单栏下方；空间不足时处理被刘海挡住的项目 | 官网显示从 `$12` 起；本代一次性、Pro 年订阅、Mega Supporter 终身档；闭源 | 要求 Accessibility 与 Screen Recording；称截图仅用于菜单栏且不保存、不上传 | 功能与定价体系渐重；高级自动化学习成本高；强权限信任门槛 |
| **Ice** | 三区管理、hover/click/swipe、拖拽布局、Ice Bar、搜索、间距、外观定制 | Ice Bar 在菜单栏下方显示隐藏项 | 免费，GPL-3.0 | Accessibility 必需；Screen Recording 可选。源码直接使用私有 CGS WindowServer API，关闭 App Sandbox | Profiles、Groups、Triggers 尚在路线图；GPL 代码不能直接用于闭源产品；不适合直接照搬到 App Store |
| **Hidden Bar** | 用分隔线把项目推到屏幕外；点击、快捷键、定时收起；始终隐藏区 | “Full menu bar”展开，但没有真正的刘海下方图标面板 | 免费，MIT；Mac App Store + GitHub | App Sandbox 开启；通过放大 `NSStatusItem.length` 将图标挤出视口，不需读各图标 | 图标被藏后不可搜索或单独操作；无可视化编排；依赖未公开的布局行为，代码已记录 macOS 27 可能失效 |
| **Vanilla** | 免费版基本隐藏；Pro 增加快捷键、彻底隐藏、5 秒自动隐藏、登录启动 | 主要通过隐藏释放空间，无独立 overflow shelf | 免费基础版；Pro `$10` 一次性，可激活最多 10 台 Mac；闭源 | 官方明确要求 Accessibility 与 Screen Recording；截取屏幕顶部约 50px 来做无缝遮盖，不保存、不传输 | 产品较久、交互简单；截图式“遮盖”不是结构化图标管理；刘海场景不如独立 shelf |
| **Barbee** | 隐藏/显示、自动管理、快捷键、减小间距、隐藏应用菜单、样式、云同步 Profiles、脚本/Shortcuts | App Store 明确称兼容刘海 | 免费下载；3 天 VIP 试用；年订阅 `$2.99`，另有终身 IAP；闭源 | App Store 分发；隐私政策承认错误日志可能经第三方收集 IP、设备、系统版本等，表述仍有“phone”等模板痕迹 | 信任表达较弱；云同步与菜单栏工具的本地隐私诉求冲突；功能很多但信息架构不够聚焦 |
| **DynamicLake** | hover 刘海展开“动态岛”；音乐、日历天气、通知、拖放、文件、计时器、蓝牙状态 | 直接把刘海变成信息入口；支持 miniLake 和外接屏 | 官网购买、Gumroad 交易；闭源，精确现价未静态展示 | 声称消息等在本地处理、不经其服务器；Quick Reply 直接连接宿主服务 | 它不是菜单栏图标管理器；功能横向扩张严重。值得借鉴其“刘海即入口”的动效，但不宜复制功能集合 |

## 各产品值得借鉴的部分

### 1. Bartender 6：能力上限

官方列出的核心能力包括：

- hover、滚动、点击或滑动快速展开；
- 刘海遮挡处理；
- 菜单栏下方的 Bartender Bar；
- Quick Search；
- Groups；
- 工作、专注、演示等 Profiles；
- 根据电量、Wi-Fi、位置、时间和日期触发规则；
- 自定义快捷键与样式。

值得借鉴的是它覆盖了完整工作流，而不是只做“藏起来”。但我们的首版不应照抄所有设置；更好的方向是默认自动工作，把复杂规则收在高级设置中。

来源：

- [Bartender 官网](https://www.macbartender.com/)
- [Bartender 购买与方案比较](https://www.macbartender.com/purchase/)
- [Bartender 隐私政策](https://www.macbartender.com/privacy/)
- [Bartender 权限排障](https://www.macbartender.com/Bartender5/PermissionIssues/)

### 2. Ice：最佳技术参照，但有分发风险

Ice 当前已实现：

- 可见 / 隐藏 / 始终隐藏三区；
- hover、空白处点击、滚动或滑动展开；
- 自动收起；
- 应用菜单与菜单栏项目重叠时隐藏应用菜单；
- 拖拽排列；
- 刘海下方 Ice Bar；
- 搜索；
- 间距调整；
- 菜单栏外观编辑。

其源码对权限划分非常有参考价值：

- **Accessibility 必需**：读取菜单栏实时信息、排列项目；
- **Screen Recording 可选**：修改菜单栏外观、显示各菜单栏项目图像。

技术上，“第二层面板中的图标”并不是真正克隆出的原生控件。Ice 会取得项目窗口信息和截图；操作某个隐藏项目时，可能先将原项目临时移动回可见位置，再构造 `CGEvent` 点击，之后重新隐藏。

更重要的是，Ice：

- 关闭了 App Sandbox；
- 通过 `_silgen_name` 调用 `CGSGetProcessMenuBarWindowList`、`CGSGetScreenRectForWindow` 等私有 WindowServer API。

因此，完整复刻 Ice 能力意味着：

- 更适合官网签名、公证、Sparkle 更新的分发方式；
- 系统升级可能破坏实现；
- Mac App Store 上架风险较高；
- GPL-3.0 源码只能作为技术研究，闭源商业产品不可直接复制代码。

来源：

- [Ice README / 功能路线图](https://github.com/jordanbaird/Ice)
- [Ice 权限实现](https://github.com/jordanbaird/Ice/blob/main/Ice/Permissions/Permission.swift)
- [Ice 屏幕捕获实现](https://github.com/jordanbaird/Ice/blob/main/Ice/Utilities/ScreenCapture.swift)
- [Ice 项目移动与点击实现](https://github.com/jordanbaird/Ice/blob/main/Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift)
- [Ice 私有 CGS API 声明](https://github.com/jordanbaird/Ice/blob/main/Ice/Bridging/Shims/Private.swift)
- [Ice Entitlements](https://github.com/jordanbaird/Ice/blob/main/Ice/Ice.entitlements)
- [Ice GPL-3.0 License](https://github.com/jordanbaird/Ice/blob/main/LICENSE)

### 3. Hidden Bar：低权限基础模式的最佳基线

Hidden Bar 不读取和复制每个图标。它创建控制项和分隔项，折叠时把分隔项长度扩张到接近屏幕宽度，把左侧图标挤出可见区域。

优势：

- 实现简单；
- App Sandbox 可开启；
- 可上 Mac App Store；
- 不需要解释“屏幕录制”权限；
- MIT 许可证适合作为实现参考。

限制：

- 隐藏项目无法独立搜索或从 shelf 直接操作；
- 无法可靠识别项目身份；
- 依赖菜单栏布局行为，而非 Apple 正式提供的管理 API。

项目源码甚至已经加入诊断逻辑，说明 macOS 27 可能不再允许扩大 `NSStatusItem.length` 来隐藏图标。这提示我们必须做版本探测、能力降级和系统升级回归测试。

来源：

- [Hidden Bar GitHub](https://github.com/dwarvesf/hidden)
- [Hidden Bar App Store](https://apps.apple.com/us/app/hidden-bar/id1452453066)
- [核心折叠实现](https://github.com/dwarvesf/hidden/blob/develop/hidden/Features/StatusBar/StatusBarController.swift)
- [Sandbox Entitlements](https://github.com/dwarvesf/hidden/blob/develop/hidden/Hidden.entitlements)
- [隐私政策](https://github.com/dwarvesf/hidden/blob/develop/PRIVACY_POLICY.md)
- [MIT License](https://github.com/dwarvesf/hidden/blob/develop/LICENSE)

### 4. Vanilla：简洁定价与权限说明

Vanilla 的基础版免费，Pro `$10` 一次性，解锁：

- 全局快捷键；
- 完全移除区；
- 自动隐藏；
- 登录启动；
- 最多 10 台个人 Mac。

它的权限说明比许多竞品清楚：只截取屏幕顶部约 50px，不存储、不发送，只用于把菜单栏背景与隐藏区域融合。

可借鉴：

- 一次性付费而非强制订阅；
- 把“为什么要屏幕录制”用具体范围和用途解释清楚；
- 权限故障提供自助恢复流程。

来源：

- [Vanilla 官网与价格](https://matthewpalmer.net/vanilla/)
- [Vanilla 权限与隐私说明](https://matthewpalmer.net/vanilla/screen-recording-permission.html)
- [Vanilla FAQ](https://matthewpalmer.net/vanilla/help.html)

### 5. Barbee：功能广，但隐私表达是反面教材

Barbee App Store 页面列出：

- 自动显示 / 隐藏；
- 快捷键；
- emoji、SF Symbols、文字或图片定制入口；
- 刘海支持；
- 减小间距；
- 隐藏应用菜单；
- 云备份和 Profiles；
- 脚本及 Shortcuts 集成；
- 3 天试用、年订阅和终身 IAP。

其隐私政策较通用，提到第三方错误日志可能包含 IP、设备名、系统版本等，还残留移动端“phone”措辞。这对一个需要敏感系统权限的工具非常伤信任。

我们的机会是把隐私说明做成产品界面的一部分：每项权限旁展示“读取什么、不读取什么、处理位置、关闭后失去哪些能力”。

来源：

- [Barbee App Store](https://apps.apple.com/us/app/barbee-hide-menu-bar-items/id1548711022)
- [Barbee 隐私政策](https://github.com/HsiangHo/Barbee-Feedback/wiki/Privacy-Policy)

### 6. DynamicLake：借交互，不借功能范围

DynamicLake 把刘海视为一个 hover 展开的动态岛，包含：

- 音乐控制；
- 日程与天气；
- 通知、来电；
- 拖放、AirDrop、格式转换；
- 文件管理；
- 计时器、蓝牙连接提醒；
- miniLake；
- 外接屏支持。

真正值得借鉴的是：

- 刘海本身是自然触发区；
- 收起状态几乎不占空间；
- 展开时从物理刘海自然生长；
- 快速 glance，而不是打开传统设置窗口。

但其众多工具与本需求无关。我们的主界面只应是“图标溢出层”，不要变成另一个剪贴板、音乐和文件工具合集。

来源：

- [DynamicLake 官网](https://www.dynamiclake.com/)
- [DynamicLake 隐私政策](https://www.dynamiclake.com/privacy-policy)

## Apple 平台边界

Apple 的 ScreenCaptureKit 官方文档明确要求：

- 捕获前向用户申请屏幕录制权限；
- 在应用中提供 `NSScreenCaptureUsageDescription`；
- ScreenCaptureKit 提供的是屏幕、应用和窗口捕获，不是“菜单栏项目管理 API”。

Apple 并没有公开一套 API，让第三方枚举、移动和点击所有其他应用的 `NSStatusItem`。因此高阶竞品普遍依靠：

- WindowServer 窗口枚举；
- Accessibility；
- 菜单栏区域截图；
- 合成鼠标事件；
- 私有 CGS API 或菜单栏布局技巧。

来源：

- [Apple ScreenCaptureKit 文档](https://developer.apple.com/documentation/screencapturekit)
- [Apple AXIsProcessTrusted 文档](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted)

## 推荐 MVP

### 必做

- 可见、隐藏、始终隐藏三区；
- 点击、快捷键、hover 展开；
- 可配置自动收起时间；
- 登录启动；
- 根据当前屏幕宽度和刘海安全区自动选择：
  - 原菜单栏内展开；
  - 刘海下方 overflow shelf；
- 首次使用引导用户 `⌘ + 拖动` 安排项目；
- 当前应用菜单变宽、图标即将撞到刘海时自动收起；
- 权限诊断页与一键跳转系统设置；
- 多显示器、分辨率切换、全屏 Space 的恢复能力；
- 所有数据默认只保存在本地。

### 增强权限后提供

- 图标可视化布局编辑；
- fuzzy search；
- 从 shelf 选择项目后临时移入菜单栏并点击；
- 单项快捷键；
- 项目消失、更新或改名后的自愈匹配；
- 演示 / 屏幕共享快速清洁模式。

### 暂缓

- 云同步；
- 电池、Wi-Fi、位置等复杂 Triggers；
- 菜单栏皮肤；
- Dynamic Island 小组件；
- 音乐、剪贴板、文件托盘；
- 插件或脚本生态。

这些功能会迅速扩大权限面、测试矩阵和 UI 复杂度，却不直接解决“刘海挡住菜单栏项目”。

## 可形成差异化的五点

1. **真正自动适应溢出**  
   不要求用户反复手动开关；根据屏幕、刘海和前台应用菜单宽度实时决定布局。

2. **权限分级**  
   无权限即可完成基础折叠，用户主动启用 Power Mode 后再获得截图、搜索和可视化管理。

3. **刘海原生交互**  
   鼠标移近刘海，overflow shelf 从刘海下方展开；离开后柔和收起。借 DynamicLake 的空间隐喻，但只服务菜单栏管理。

4. **本地、可证明的隐私**  
   不登录、不分析、不上传截图；权限页实时显示最近一次菜单栏截图是否存在，并保证只在内存中短暂处理。

5. **兼容性与自愈优先**  
   为每个 macOS 版本配置能力探测；私有能力失效时自动退回低权限折叠模式，而不是让菜单栏不可用。

## 最重要的产品决策

如果目标是完整做到 Bartender / Ice 水平，应优先采用**官网分发、Developer ID 签名与公证**，把 Mac App Store 版本视为受限版或暂不提供。

如果必须优先上 Mac App Store，首版应停在 Hidden Bar 式低权限折叠，并把“独立 shelf 中展示和操作所有真实菜单栏图标”列为实验能力，避免一开始依赖私有 CGS API。
