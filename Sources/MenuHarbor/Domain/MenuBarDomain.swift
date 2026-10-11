import Foundation
import CoreGraphics

enum HarborCapability: Equatable {
    case foldOnly
    case browsable
    case interactive

    static func resolve(screenCapture: Bool, accessibility: Bool) -> Self {
        guard screenCapture else { return .foldOnly }
        return accessibility ? .interactive : .browsable
    }
}

enum HarborPermission: Equatable {
    case screenCapture
    case accessibility
}

struct HarborPreferences: Codable, Equatable {
    enum IconStyle: String, Codable, CaseIterable {
        case harbor
        case dot
    }

    var autoHideDelay: TimeInterval
    var shortcutEnabled: Bool
    /// Carbon 虚拟键码，默认 H（4）。
    var shortcutKeyCode: Int
    /// Carbon 修饰键掩码，默认 ⌃⌥（0x1000 | 0x0800 = 6144）。
    var shortcutModifiers: Int
    /// 录制时生成的展示文案，如 "⌃⌥H"。
    var shortcutDisplay: String
    var iconStyle: IconStyle
    var launchAtLogin: Bool
    var hoverOpensShelf: Bool
    /// 刘海屏上是否显示一个固定的港湾入口；默认开启，用户可在设置中关闭。
    var notchLauncherEnabled: Bool
    /// 悬停展开的热区从主按钮/刘海扩展到菜单栏右半侧（iBar 式聚合入口），
    /// 仅在 hoverOpensShelf 开启时生效。
    var hoverZoneWide: Bool
    var scrollTogglesMenuBar: Bool
    /// 折叠在本机是否可靠；nil 表示尚未探测。macOS 26 探测失败后持久化，
    /// 之后启动和切换直接进入收纳模式，不再反复闪烁尝试折叠。
    var foldSupported: Bool?
    var hasCompletedOnboarding: Bool

    /// 折叠不可用的机器（macOS 26+）运行在收纳模式：不推挤图标，
    /// 港湾改为展示全部菜单栏图标，提供搜索和代点击。
    var usesCollectOnlyMode: Bool { foldSupported == false }

    static let defaultShortcutKeyCode = 4 // kVK_ANSI_H
    static let defaultShortcutModifiers = 0x1000 | 0x0800 // control | option

    static let defaults = HarborPreferences(
        autoHideDelay: 10,
        shortcutEnabled: true,
        shortcutKeyCode: defaultShortcutKeyCode,
        shortcutModifiers: defaultShortcutModifiers,
        shortcutDisplay: "⌃⌥H",
        iconStyle: .harbor,
        launchAtLogin: false,
        hoverOpensShelf: true,
        notchLauncherEnabled: true,
        hoverZoneWide: false,
        scrollTogglesMenuBar: false,
        foldSupported: nil,
        hasCompletedOnboarding: false
    )
}

// 老版本持久化数据缺少新增字段时，只补默认值，不整体回退丢失其他偏好。
extension HarborPreferences {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            autoHideDelay: try container.decode(TimeInterval.self, forKey: .autoHideDelay),
            shortcutEnabled: try container.decode(Bool.self, forKey: .shortcutEnabled),
            shortcutKeyCode: try container.decodeIfPresent(Int.self, forKey: .shortcutKeyCode) ?? HarborPreferences.defaultShortcutKeyCode,
            shortcutModifiers: try container.decodeIfPresent(Int.self, forKey: .shortcutModifiers) ?? HarborPreferences.defaultShortcutModifiers,
            shortcutDisplay: try container.decodeIfPresent(String.self, forKey: .shortcutDisplay) ?? "⌃⌥H",
            iconStyle: try container.decode(IconStyle.self, forKey: .iconStyle),
            launchAtLogin: try container.decode(Bool.self, forKey: .launchAtLogin),
            hoverOpensShelf: try container.decodeIfPresent(Bool.self, forKey: .hoverOpensShelf) ?? false,
            notchLauncherEnabled: try container.decodeIfPresent(Bool.self, forKey: .notchLauncherEnabled) ?? true,
            hoverZoneWide: try container.decodeIfPresent(Bool.self, forKey: .hoverZoneWide) ?? false,
            scrollTogglesMenuBar: try container.decodeIfPresent(Bool.self, forKey: .scrollTogglesMenuBar) ?? false,
            foldSupported: try container.decodeIfPresent(Bool.self, forKey: .foldSupported),
            hasCompletedOnboarding: try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        )
    }
}

/// 固定入口的几何规则与 AppKit 窗口无关，单测可以覆盖刘海居中和安全区约束。
enum NotchLauncherLayout {
    static let defaultSize = CGSize(width: 112, height: 26)
    static let defaultGap: CGFloat = 6

    static func hasNotch(leftArea: CGRect?, rightArea: CGRect?) -> Bool {
        guard let leftArea, let rightArea else { return false }
        return rightArea.minX > leftArea.maxX && leftArea.height > 0 && rightArea.height > 0
    }

    static func frame(
        screenFrame: CGRect,
        visibleFrame: CGRect,
        notchFrame: CGRect?,
        size: CGSize = defaultSize,
        gap: CGFloat = defaultGap
    ) -> CGRect {
        let width = min(size.width, max(0, visibleFrame.width - 16))
        let height = size.height
        let centerX = notchFrame?.midX ?? screenFrame.maxX - width / 2 - 24
        let minX = visibleFrame.minX + 8
        let maxX = max(minX, visibleFrame.maxX - width - 8)
        let x = min(max(centerX - width / 2, minX), maxX)
        let y = visibleFrame.maxY - height - gap
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

enum FoldState: Equatable {
    case folded
    case expanded

    mutating func toggle() {
        self = self == .folded ? .expanded : .folded
    }

    mutating func restore() {
        self = .expanded
    }
}

struct MenuBarItemDescriptor: Equatable, Identifiable {
    let windowID: UInt32
    let ownerPID: Int32
    let ownerName: String
    let name: String
    let frame: CGRect
    let isOnScreen: Bool

    var id: UInt32 { windowID }

    /// 用辅助功能读到的可读名称替换窗口名（Tahoe 上窗口名多为 "Item-0"）。
    func withName(_ name: String) -> MenuBarItemDescriptor {
        MenuBarItemDescriptor(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            name: name,
            frame: frame,
            isOnScreen: isOnScreen
        )
    }
}

/// 一次分区的结果。`hidden` 是隐藏分隔标记左侧的全部项，
/// `alwaysHidden` 是其中位于始终隐藏分隔标记左侧的子集。
struct ItemPartition: Equatable {
    var hidden: [MenuBarItemDescriptor]
    var alwaysHidden: [MenuBarItemDescriptor]
}

enum ItemPartitioner {
    /// 返回隐藏分隔标记左侧的隐藏项，并按始终隐藏区分组。
    ///
    /// `screenFrames` 必须与窗口 frame 处于同一坐标系（CG 全局坐标，原点在主屏左上）。
    /// 隐藏项包含两类：
    /// - 与分隔标记同一屏幕、且位于其左侧的可见项；
    /// - 折叠时被完全推出所有屏幕的项——它们只可能来自折叠，因此全部归属隐藏区。
    /// 位于其他屏幕（例如排列在主屏左侧的外接显示器）上的状态项不属于任何一屏之外的
    /// 折叠产物，必须按所在屏幕排除，否则会被误判成分隔标记左侧的隐藏项。
    static func partition(
        in items: [MenuBarItemDescriptor],
        hiddenDividerWindowID: UInt32,
        alwaysHiddenDividerWindowID: UInt32?,
        screenFrames: [CGRect]
    ) -> ItemPartition {
        guard
            let divider = items.first(where: { $0.windowID == hiddenDividerWindowID })
        else {
            return ItemPartition(hidden: [], alwaysHidden: [])
        }
        let dividerScreen = screenFrames.first { $0.intersects(divider.frame) }
        let excludedWindowIDs = Set([hiddenDividerWindowID, alwaysHiddenDividerWindowID].compactMap { $0 })

        let candidates = items
            .filter { item in
                guard !excludedWindowIDs.contains(item.windowID) else { return false }
                guard screenFrames.contains(where: { $0.intersects(item.frame) }) else {
                    return true
                }
                guard let dividerScreen,
                      let itemScreen = screenFrames.first(where: { $0.intersects(item.frame) })
                else {
                    return false
                }
                return itemScreen == dividerScreen && item.frame.maxX <= divider.frame.minX
            }
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.windowID < rhs.windowID
                }
                return lhs.frame.minX > rhs.frame.minX
            }

        guard
            let alwaysHiddenDividerWindowID,
            let alwaysHiddenDivider = items.first(where: { $0.windowID == alwaysHiddenDividerWindowID })
        else {
            return ItemPartition(hidden: candidates, alwaysHidden: [])
        }

        return ItemPartition(
            hidden: candidates,
            alwaysHidden: candidates.filter { $0.frame.maxX <= alwaysHiddenDivider.frame.minX }
        )
    }
}

enum ItemSearch {
    /// 大小写、变音符号与全角字符统一折叠后比较："cafe" 命中 "Café"，
    /// 中文输入法误切全角时输入的 "ｗｉｆｉ" 也能命中 "WiFi"。
    private static let foldOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    static func filter(
        _ items: [MenuBarItemDescriptor],
        query: String
    ) -> [MenuBarItemDescriptor] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }

        let foldedNeedle = needle.folding(options: foldOptions, locale: .current)

        // 子串命中优先（精确感最强）；全部落空时退回子序列模糊匹配，
        // 让 "wfi" 也能找到 "WiFi"——对标 Bartender Quick Search 的容错。
        let direct = items.filter {
            $0.name.folding(options: foldOptions, locale: .current).contains(foldedNeedle)
                || $0.ownerName.folding(options: foldOptions, locale: .current).contains(foldedNeedle)
        }
        if !direct.isEmpty {
            return direct
        }

        return items.filter {
            isSubsequence(foldedNeedle, in: $0.name.folding(options: foldOptions, locale: .current))
                || isSubsequence(foldedNeedle, in: $0.ownerName.folding(options: foldOptions, locale: .current))
        }
    }

    /// needle 的字符是否按顺序全部出现在 haystack 中（不必连续）。
    static func isSubsequence(
        _ needle: some StringProtocol,
        in haystack: some StringProtocol
    ) -> Bool {
        var remaining = haystack[...]
        for character in needle {
            guard let index = remaining.firstIndex(of: character) else {
                return false
            }
            remaining = remaining[remaining.index(after: index)...]
        }
        return true
    }
}

enum ItemActivationPlan: Equatable {
    case click
    case expandForManualClick
    case refresh

    static func make(itemExists: Bool, accessibility: Bool) -> Self {
        guard itemExists else { return .refresh }
        return accessibility ? .click : .expandForManualClick
    }
}

enum ItemActivationPolicy {
    /// 合成坐标点击只有在 WindowServer 明确认为目标可见时才安全。
    /// 刘海遮挡或已离屏的窗口不能把点击投到一个用户看不见的坐标上，
    /// 否则会把“没有发生任何操作”误报成成功。
    static func canUseCoordinateClick(isOnScreen: Bool) -> Bool {
        isOnScreen
    }
}

enum ShelfPresentation {
    static func filtered(
        items: [MenuBarItemDescriptor],
        query: String
    ) -> [MenuBarItemDescriptor] {
        ItemSearch.filter(items, query: query)
    }

    /// 收纳模式：港湾展示锚定屏幕上的全部菜单栏图标（排除 MenuHarbor 自己的三个状态项）。
    /// 只取锚定屏幕，天然去掉了同一图标在其他显示器菜单栏上的副本。
    static func collectModeItems(
        in items: [MenuBarItemDescriptor],
        excludedWindowIDs: Set<UInt32>,
        screenFrame: CGRect?,
        rescueFrame: CGRect? = nil
    ) -> [MenuBarItemDescriptor] {
        items
            .filter { !excludedWindowIDs.contains($0.windowID) }
            // `scan()` intentionally uses `.optionAll` so folded items remain
            // discoverable in the classic divider mode.  Collect-only mode has
            // no divider provenance, so exclude windows that WindowServer marks
            // off-screen (other Spaces, minimized apps, and stale status-item
            // records) before applying the display geometry filter.  A status
            // item clipped by the notch can also be reported as off-screen on
            // some macOS releases; `rescueFrame` keeps only those windows that
            // overlap the known notch instead of re-introducing other Spaces.
            .filter { item in
                guard let screenFrame else { return true }
                guard Self.isMenuBarWindow(item, on: screenFrame) else { return false }
                guard screenFrame.intersects(item.frame) else { return false }
                return item.isOnScreen || rescueFrame?.intersects(item.frame) == true
            }
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.windowID < rhs.windowID
                }
                return lhs.frame.minX > rhs.frame.minX
            }
    }

    /// CGWindowList 的 statusWindow 层还会包含控制面板或其他辅助窗口。
    /// 菜单栏状态项位于屏幕顶部且高度接近菜单栏；先做几何限制，避免把
    /// 254×254 的辅助窗口显示成一个“菜单栏图标”。
    private static func isMenuBarWindow(_ item: MenuBarItemDescriptor, on screen: CGRect) -> Bool {
        let bandHeight = min(64, max(32, screen.height * 0.08))
        let menuBarBand = CGRect(
            x: screen.minX,
            y: screen.minY,
            width: screen.width,
            height: bandHeight
        )
        return menuBarBand.intersects(item.frame) && item.frame.height <= bandHeight
    }

    /// 收纳模式的展示排序：可能被刘海挡住的项目排最前（它们是港湾的
    /// 核心价值），其余仍按菜单栏从右到左；x 并列时用窗口号稳定排序。
    static func collectModeOrder(
        _ items: [MenuBarItemDescriptor],
        atRisk: Set<UInt32>
    ) -> [MenuBarItemDescriptor] {
        items.sorted { lhs, rhs in
            let lhsAtRisk = atRisk.contains(lhs.windowID)
            let rhsAtRisk = atRisk.contains(rhs.windowID)
            guard lhsAtRisk == rhsAtRisk else { return lhsAtRisk }
            if lhs.frame.minX == rhs.frame.minX { return lhs.windowID < rhs.windowID }
            return lhs.frame.minX > rhs.frame.minX
        }
    }

    /// 收纳模式下的“不可达”标记。
    ///
    /// WindowServer 仍可能把被刘海遮住的状态项标记为 on-screen，所以不能只
    /// 依赖 `isOnScreen`；同时保留对真正离屏窗口的判断，用来提示用户哪些项目
    /// 已经从菜单栏移到港湾。`notchFrame` 为空时只使用 WindowServer 状态。
    static func atRiskWindowIDs(
        in items: [MenuBarItemDescriptor],
        notchFrame: CGRect?
    ) -> Set<UInt32> {
        Set(
            items
                .filter { !$0.isOnScreen || notchFrame?.intersects($0.frame) == true }
                .map(\.windowID)
        )
    }

    static func missingPermission(for capability: HarborCapability) -> HarborPermission? {
        switch capability {
        case .foldOnly:
            return .screenCapture
        case .browsable:
            return .accessibility
        case .interactive:
            return nil
        }
    }

    static func permissionMessage(for capability: HarborCapability) -> String? {
        switch missingPermission(for: capability) {
        case .screenCapture:
            return "开启屏幕录制，显示真实图标；再开启辅助功能即可直接点击"
        case .accessibility:
            return "开启辅助功能，即可直接在港湾里点击图标"
        case nil:
            return nil
        }
    }
}

/// 图标快照的会话内复用规则：Shelf 一次打开期间，窗口号未变且帧尺寸
/// 未变的图标复用上一轮截图，2.5 秒轮询只补拍新增或变形的窗口，
/// 避免每轮都对几十个窗口做全量截屏。每次重新打开 Shelf 时缓存清空，
/// 图标外观不会跨会话过期。
enum SnapshotReusePolicy {
    /// 缩略图显示尺寸：真实帧太小（含 0）时抬到 18pt 下限。
    static func snapshotSize(for frame: CGRect) -> CGSize {
        CGSize(width: max(18, frame.width), height: max(18, frame.height))
    }

    static func shouldReuse(existingSize: CGSize, frame: CGRect) -> Bool {
        existingSize == snapshotSize(for: frame)
    }
}

enum AutoHidePolicy {
    /// 自动收起需要为用户操作让路：港湾浮层打开时不收起原生菜单栏，
    /// 用户按住 ⌘ 拖拽整理图标时也不能把图标抽走。
    static func shouldDefer(isShelfPresented: Bool, isCommandKeyDown: Bool) -> Bool {
        isShelfPresented || isCommandKeyDown
    }
}

/// 折叠能力自检：macOS 26 起，"放大分隔标记把图标挤出视口"的布局行为
/// 已被确认不可靠（Ice 等竞品同样受影响）。折叠后必须验证隐藏项真的
/// 离开了屏幕，否则在界面中明确告知用户，而不是让图标无声地占着位置。
enum FoldReliabilityPolicy {
    /// WindowServer 可能在折叠后的短窗口里重建状态项窗口；一次缺失不能
    /// 直接把本机永久标成“不支持折叠”。
    static let healthProbeAttempts = 3

    /// 折叠是否真正生效：隐藏区每一项都不得与任何屏幕相交。
    static func isFoldEffective(
        items: [MenuBarItemDescriptor],
        screenFrames: [CGRect]
    ) -> Bool {
        guard !items.isEmpty else { return true }
        return items.allSatisfy { item in
            !screenFrames.contains { $0.intersects(item.frame) }
        }
    }
}
