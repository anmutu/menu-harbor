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
            scrollTogglesMenuBar: try container.decodeIfPresent(Bool.self, forKey: .scrollTogglesMenuBar) ?? false,
            foldSupported: try container.decodeIfPresent(Bool.self, forKey: .foldSupported),
            hasCompletedOnboarding: try container.decode(Bool.self, forKey: .hasCompletedOnboarding)
        )
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
    static func filter(
        _ items: [MenuBarItemDescriptor],
        query: String
    ) -> [MenuBarItemDescriptor] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }

        return items.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.ownerName.localizedCaseInsensitiveContains(needle)
        }
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
                guard screenFrame?.intersects(item.frame) ?? true else { return false }
                return item.isOnScreen || rescueFrame?.intersects(item.frame) == true
            }
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.windowID < rhs.windowID
                }
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
