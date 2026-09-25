# 竞品研究补充：Tahoe 兼容性危机与 2026 新格局

调研日期：2026-09-25（更新）。接续 [2026-09-02 首轮竞品研究](2026-09-02-macos-menu-bar-managers.md)，本次补充新产品、市场变化与 macOS 26/27 兼容性情报。

## 结论先行

1. **macOS 26 Tahoe 已确认动摇所有基于 `NSStatusItem.length` 放大的折叠方案**。这不是预告，而是正在发生的兼容性危机。MenuHarbor 必须把"折叠能力自检 + 明确降级"当作一等公民。
2. **Bartender 7 已把 “Beat the notch” 做成直接卖点**，Bartender 7 当前是本代一次性购买；加上 **Ice 维护停滞（用户流向 Thaw 等分叉）**，市场仍在寻找可信的新选择。"安静、本地、可证明的隐私 + 兼容性透明"正是 MenuHarbor 的窗口。
3. 国产头部产品 iBar 验证了"悬停/点击菜单栏聚合展示"是刚需交互；boring.notch 验证了"刘海悬停展开"的空间隐喻。MenuHarbor 已覆盖其一（hover 展开），滚动切换本轮补上。

## macOS 26 Tahoe：折叠技巧的生死线

- Ice 在 Tahoe 正式版上大面积损坏（菜单项乱序、无法显示），0.11.13 beta 才修复"大部分已知问题"；仍有 [issue #679](https://github.com/jordanbaird/Ice/issues/679) 报告无法恢复。
- Hidden Bar / Ice 同款的 `NSStatusItem.length` 放大技巧不再可靠；[AeroSpace #1968](https://github.com/nikitabobko/AeroSpace/discussions/1968) 记录了 HiddenBar 与 Ice 在 Tahoe 上状态项不出现的同类症状。
- Stats 等"被管理对象"的状态项也出现[不渲染的问题](https://github.com/exelban/stats/issues/3120)，说明系统层布局机制变了，不只是管理器自身 bug。
- Tahoe 同时在系统设置里内置了菜单栏项管理（MPU 社区讨论 "Using macOS 26 without a menu bar manager"），长期看系统会吃掉一部分简单需求。
- **新路线已经出现**：[Thaw](https://github.com/thaw-app/Thaw/releases)（Ice 的 Tahoe 原生后继）与 [menubar-hide](https://github.com/junior-rj/menubar-hide) 都改为「CGWindowList 找窗口 + ScreenCaptureKit 截图 + 自有面板渲染」，不再推挤图标。
- 对 MenuHarbor 的直接启示：我们的 Shelf 恰好已经是"扫描 + 截图 + 自有面板"形态，**折叠失效时 Shelf 仍然可用**。本轮已落地：
  - `FoldReliabilityPolicy`：折叠后 1.5 秒重扫，验证隐藏项真的全部离屏；
  - 失效时设置页显示橙色警告与"立即恢复"出口；
  - 刘海屏现在直接进入“只收纳不推挤”主路径：自动扫描当前屏幕全部状态项，快捷键/滚动直接打开 Shelf，不要求先拖分隔线。
  - 后续仍需按 macOS 27 的系统原生 overflow 进一步分层，避免把逐窗口扫描当成长期契约。

## 新竞品速览

| 产品 | 定位 | 对 MenuHarbor 的启示 |
|---|---|---|
| **Dozer / Open Dozer** | 曾经最流行的开源方案（GitHub 万星），原作已停更，社区分叉续命 | "极简双圆点"设计被大量用户喜爱；停更即死亡——**维护响应速度本身就是竞争力** |
| **Thaw 2.0.1** | Tahoe/27 原生 Thaw Bar；无录屏也能隐藏、显示、排列，并用应用图标兜底 | 验证了放弃推挤、纯面板渲染和低权限兜底的可行性；我们的 Shelf 架构方向正确 |
| **iBar 2.1.1**（Better365，国产头部） | “刘海遮挡图标？一键搞定”；菜单栏下方聚合浮窗，点击临时加回菜单栏，延迟后再藏 | 聚合浮窗是完整闭环（我们需要把它变成主路径）；App Store 分发在该品类可行 |
| **ExtraBar / Badgeify / FavTray** | 2026 年因 Ice/Bartender 动荡出现的新入口 | 市场窗口确实存在，但均未建立信任壁垒 |
| **boring.notch** | 刘海 hover 入口（音乐等小工具），不是菜单栏管理器 | 刘海悬停隐喻已被验证；MenuHarbor 保持“只做溢出层”不扩张功能。NotchNook 官网当前为 Coming Soon，不作为活跃功能证据 |
| **menubar-hide 1.6.1** | 菜单栏下方 panel mode；macOS 27 改用系统原生 overflow，panel/arrangement 在该系统禁用 | 需要做 OS 能力分层，不能只依赖逐窗 CGWindowList |
| **Hidden Bar 1.11.1** | 极简 separator；README 宣称已支持 macOS 27 | 适合作为低权限引擎参照，不能承担完整 Shelf 体验 |
| **Barbee** | 在 Ice 损坏期承接了不少用户 | 功能多但隐私表达弱的问题依旧，是我们的反面参照 |

## 本轮落地（2026-09-05）

1. **折叠健康自检**：`FoldReliabilityPolicy`（Domain 可测）+ AppModel 折叠后 1.5s 验证 + 设置页警告。启动折叠、手动折叠、快捷键折叠三条路径都会自检。
2. **滚动切换**（可选，默认关）：菜单栏上滚动滚轮切换收起/展开，参考 iBar/Bartender 的菜单栏手势交互；轨迹板惯性滚动用累计阈值 + 1s 冷却去抖。
3. **快照刷新防抖**：1 秒内重复打开港湾不重复扫描和截图；激活失败的强制刷新不受防抖限制。
4. **溢出可发现性**：Shelf 打开期间每 2.5 秒同步一次状态项；疑似落入刘海遮挡区域的项目优先排列并显示风险标记，减少“图标在但找不到”的认知成本。

## 市场定位更新

首轮研究定义的差异化五点中，"兼容性与自愈优先"从预防性设计变成了**当下最锐利的卖点**：Tahoe 用户正经历"图标消失/管理器损坏"的混乱期，一个能明确说出"折叠已失效，这是原因，这是退路"的产品，比一个静默失效的产品可信得多。官网文案应直接回应"Tahoe 能用吗"。

## 来源

- [Ice Tahoe beta 讨论 #672](https://github.com/jordanbaird/Ice/discussions/672)、[issue #679](https://github.com/jordanbaird/Ice/issues/679)
- [Reddit: Ice no longer works in Tahoe](https://www.reddit.com/r/macapps/comments/1nid66c/ice_app_for_macos_no_longer_works_in_tahoe/)
- [Thaw Releases](https://github.com/thaw-app/Thaw/releases)、[menubar-hide](https://github.com/junior-rj/menubar-hide)
- [Dozer](https://github.com/Mortennn/Dozer)、[Open Dozer](https://github.com/micahstubbs/open-dozer)
- [iBar 官网](https://www.better365.cn/ibar.html)、[iBar App Store](https://apps.apple.com/cn/app/id6443843900?mt=12)
- [Stats issue #3120](https://github.com/exelban/stats/issues/3120)、[AeroSpace #1968](https://github.com/nikitabobko/AeroSpace/discussions/1968)
- [MPU: Menubar Manager for Tahoe?](https://talk.macpowerusers.com/t/menubar-manager-for-tahoe/41423)
- [Daring Fireball: Menu Item Icons in macOS 26 Tahoe](https://daringfireball.net/2026/03/what_to_do_about_those_menu_item_icons_in_macos_26_tahoe)
- [boring.notch](https://theboring.name/)、[MacStories Bartender 替代品综述](https://www.macstories.net/roundups/managing-your-mac-menu-bar-a-roundup-of-my-favorite-bartender-alternatives/)
- [Bartender 7](https://www.macbartender.com/)、[iBar](https://www.better365.cn/ibar.html)、[Hidden Bar releases](https://github.com/dwarvesf/hidden/releases)
