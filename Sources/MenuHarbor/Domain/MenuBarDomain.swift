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

struct HarborPreferences: Codable, Equatable {
    enum IconStyle: String, Codable, CaseIterable {
        case harbor
        case dot
    }

    var autoHideDelay: TimeInterval
    var shortcutEnabled: Bool
    var iconStyle: IconStyle
    var launchAtLogin: Bool
    var hasCompletedOnboarding: Bool

    static let defaults = HarborPreferences(
        autoHideDelay: 10,
        shortcutEnabled: true,
        iconStyle: .harbor,
        launchAtLogin: false,
        hasCompletedOnboarding: false
    )
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
}

enum ItemPartitioner {
    static func hiddenItems(
        in items: [MenuBarItemDescriptor],
        dividerWindowID: UInt32
    ) -> [MenuBarItemDescriptor] {
        guard let divider = items.first(where: { $0.windowID == dividerWindowID }) else {
            return []
        }

        return items
            .filter { $0.windowID != dividerWindowID && $0.frame.maxX <= divider.frame.minX }
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.windowID < rhs.windowID
                }
                return lhs.frame.minX > rhs.frame.minX
            }
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
