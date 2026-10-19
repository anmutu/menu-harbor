# MenuHarbor 发布文案（Launch Kit)

> 各平台复制即发。发帖前把「反馈渠道」按平台补全。GitHub 仓库：https://github.com/anmutu/menu-harbor · 官网：https://anmutu.github.io/menu-harbor/

---

## V2EX · 分享创造节点

**标题**：分享创造：MenuHarbor——把被刘海挡住的菜单栏图标，收进刘海下方的港湾（开源）

**正文**：

各位好，我做了个菜单栏工具 MenuHarbor，解决一个可能大家都遇到过的烦：

装了个新 App，它的图标在菜单栏右侧出现；再装一个，往左挪了挪；某天想去找它，发现已经滑进刘海后面，再也点不到了。

MenuHarbor 的思路是不跟系统较劲，在刘海下方修一座"港湾"：

- **刘海安全模式**：带刘海的屏自动启用，被挡住的图标收进刘海下方的 Shelf，优先排列、带警示标记，支持容错搜索（"wfi" 也能找到 WiFi，全角/声调自动折叠）
- **收纳模式**：macOS 26 起系统会回收被折叠的图标，Bartender / Ice / Hidden Bar 的折叠玩法都失效了。MenuHarbor 检测到后自动切换：菜单栏保持原生，港湾照常能看、能搜、能代点（AXPress 语义按压，不是合成坐标点击）
- **无刘海屏**可用经典三区管理（可见 / 隐藏 / 始终隐藏，⌘ 拖拽布置）
- 固定港湾入口、快捷键（默认 ⌃⌥H 可改）、悬停展开、滚轮切换、键盘操作
- 折叠健康自检：收起后验证图标真的离屏，失效会警告而不是无声丢图标
- 不联网、无账号、无统计，MIT 开源

下载（Universal，macOS 14+）：https://github.com/anmutu/menu-harbor/releases
源码：https://github.com/anmutu/menu-harbor

技术栈是 Swift + AppKit，单文件官网也开源在同仓库。欢迎拍砖，尤其欢迎 macOS 26 的朋友反馈收纳模式的实际体验。

---

## 少数派（sspai）· 投稿提纲

**标题**：MenuHarbor：为刘海屏而生的开源菜单栏港湾

**提纲**：
1. 痛点引入：刘海与菜单栏图标的领地之争（配官网示意图/自截截图）
2. 与 Bartender / Ice 的差异定位：不是又一个折叠工具；macOS 26 系统行为变化背景
3. 核心功能走查：刘海安全模式、容错搜索、代点击、三区管理（配 GIF）
4. 权限与隐私设计：两项可选权限各自的用途，本地优先
5. 下载与上手：三步 + Gatekeeper 右键打开说明

投稿入口：https://sspai.com/write · 也可先在「派早报」自荐栏目/矩阵投稿邮箱。

---

## Reddit · r/macapps

**Title**: MenuHarbor — an open-source menu bar manager for notch Macs (icons hidden by the notch land in a searchable harbor below it)

**Body**:

Hey everyone, I built MenuHarbor after losing one too many menu bar icons to the notch.

The idea: instead of fighting the system, it builds a "harbor" right below the notch. Icons at risk of being clipped are gathered into a searchable shelf — with fuzzy search that folds case/diacritics/full-width ("wfi" finds WiFi), and one-click activation via AXPress (accessibility semantic press, way more reliable than synthesized coordinate clicks).

Notable bits:

- **Notch-safe mode** activates automatically on notched screens
- **Collect-only mode for macOS 26** — the system now reclaims folded icons, which breaks Bartender/Ice/Hidden Bar's folding trick. MenuHarbor detects this and switches to keeping the native bar intact while the harbor still browses/searches/clicks everything
- Classic three-zone management on notch-less screens
- Fold health check: verifies icons actually left the screen after folding, warns instead of silently losing them
- Fully local: no network, no accounts, no telemetry. MIT licensed.

Requires macOS 14+, universal binary (Apple Silicon + Intel).

Download: https://github.com/anmutu/menu-harbor/releases
Site: https://anmutu.github.io/menu-harbor/

Feedback welcome — especially from macOS 26 users.

---

## Product Hunt

**Tagline**: The menu bar harbor for notch Macs

**Description**: MenuHarbor gathers icons hidden by your MacBook's notch into a searchable harbor right below it — see them, search them (fuzzy, CJK-friendly), and click them via accessibility. Collect-only mode keeps working on macOS 26 where folding tools broke. Open source, fully local, no telemetry.

**第一评论（-maker 自述）**：讲做这个工具的 origin story（图标滑进刘海点不到 → 老 ⌘ 拖拽法在 macOS 26 失效 → 干脆修座港），附官网故事区链接。

---

## 发帖节奏建议

1. 第 1 天：V2EX + r/macapps（真实反馈优先）
2. 第 2–3 天：少数派投稿（中文流量主阵地）
3. 稳定后：Product Hunt（建议周二–周四上午发布，避免周五周末）
4. awesome-mac PR 已提交（#3649），等待维护者合并
