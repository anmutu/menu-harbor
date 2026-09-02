# MenuHarbor

MenuHarbor 是一个原生 macOS 菜单栏溢出层，专门解决刘海 MacBook 上菜单栏图标被挤住、挡住或找不到的问题。

## 现在能做什么

- 用一个可伸缩分隔标记，把左侧菜单栏图标收进隐藏区。
- 点击 MenuHarbor 主按钮，在刘海下方打开安全的 Harbor Shelf。
- 有屏幕录制权限时显示真实图标快照；没有权限时仍可看到应用名称并展开原生菜单栏。
- 有辅助功能权限时，可从 Shelf 触发原生菜单栏项目点击；权限不足时自动退回手动展开。
- 搜索、`⌃⌥H` 快捷键、5/10/30 秒自动收起、登录启动、浅色/深色材质。
- 所有数据留在本机，不联网、不需要账号、不上传截图。

## 构建与运行

需要 macOS 14+、Xcode Command Line Tools 和 Swift 6.2+：

```bash
make test
make app
open .build/release/MenuHarbor.app
```

首次运行会显示三步引导。基础折叠无需授权；Shelf 的图标外观和代点击能力会分别请求屏幕录制、辅助功能权限。

## 第一次整理菜单栏

1. 点 MenuHarbor 图标或按 `⌃⌥H` 展开菜单栏。
2. 按住 `⌘`，把不常用的状态图标拖到双箭头分隔标记左侧。
3. 再次收起。之后点 MenuHarbor 图标即可在刘海下方访问它们。

如果系统版本改变了菜单栏布局行为，可以随时在设置中点“立即恢复”，或退出 MenuHarbor；退出前应用也会自动展开分隔区。

## 已知边界

macOS 没有公开 API 用来枚举、复制和点击所有第三方 `NSStatusItem`。因此 MenuHarbor 使用系统状态窗口信息和可选的辅助功能/截图权限来增强体验，不能承诺每一个第三方项目在每个系统版本都可直接点击。增强能力失效时，应用始终提供原生展开退路。

这个项目是官网/Developer ID 分发取向的 MVP，不承诺 Mac App Store 审核通过。菜单栏相关系统行为可能随 macOS 升级变化，基础折叠和恢复逻辑会优先保持可用。

## 研究与设计

- [竞品研究](docs/research/2026-09-02-macos-menu-bar-managers.md)
- [产品与技术设计](docs/superpowers/specs/2026-09-02-menu-harbor-design.md)
- [实现计划](docs/superpowers/plans/2026-09-02-menu-harbor.md)
- [隐私说明](docs/privacy.md)

