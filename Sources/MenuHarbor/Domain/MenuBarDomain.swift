import Foundation

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

