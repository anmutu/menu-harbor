import AppKit

@MainActor
final class MenuBarController: NSObject {
    static let dividerLength: CGFloat = 18
    static let foldedLength: CGFloat = 10_000

    var onPrimaryAction: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private(set) var state: FoldState = .folded

    private let mainItem: NSStatusItem
    private let dividerItem: NSStatusItem

    override init() {
        mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        dividerItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        super.init()
        configureMainItem()
        configureDividerItem()
        applyState()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(mainItem)
        NSStatusBar.system.removeStatusItem(dividerItem)
    }

    var mainWindowID: UInt32? {
        mainItem.button?.window.map { UInt32($0.windowNumber) }
    }

    var dividerWindowID: UInt32? {
        dividerItem.button?.window.map { UInt32($0.windowNumber) }
    }

    var mainButton: NSStatusBarButton? {
        mainItem.button
    }

    func toggle() {
        state.toggle()
        applyState()
    }

    func fold() {
        state = .folded
        applyState()
    }

    func expand() {
        state = .expanded
        applyState()
    }

    func restore() {
        state.restore()
        applyState()
    }

    func updateIcon(style: HarborPreferences.IconStyle) {
        guard let button = mainItem.button else { return }
        switch style {
        case .harbor:
            button.image = Self.symbol(named: "rectangle.bottomhalf.inset.filled", fallback: "tray.full")
        case .dot:
            button.image = Self.symbol(named: "circle.fill", fallback: "circle")
        }
    }

    private func configureMainItem() {
        mainItem.autosaveName = "MenuHarbor.Main"
        guard let button = mainItem.button else { return }
        button.target = self
        button.action = #selector(handleMainItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "MenuHarbor · 打开港湾"
        updateIcon(style: .harbor)
    }

    private func configureDividerItem() {
        dividerItem.autosaveName = "MenuHarbor.Divider"
        guard let button = dividerItem.button else { return }
        button.image = Self.symbol(named: "chevron.left.2", fallback: "chevron.left")
        button.imagePosition = .imageOnly
        button.toolTip = "按住 ⌘ 拖动菜单栏图标到此标记左侧"
        button.target = self
        button.action = #selector(handleDividerClick)
    }

    private func applyState() {
        dividerItem.length = state == .folded ? Self.foldedLength : Self.dividerLength
        if let button = mainItem.button {
            button.contentTintColor = state == .folded ? nil : .systemTeal
            button.toolTip = state == .folded ? "MenuHarbor · 打开港湾" : "MenuHarbor · 菜单栏已展开"
        }
    }

    @objc
    private func handleMainItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            onPrimaryAction?()
        }
    }

    @objc
    private func handleDividerClick() {
        toggle()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: state == .folded ? "展开菜单栏" : "收起菜单栏", action: #selector(toggleFromMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 MenuHarbor", action: #selector(quitFromMenu), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        mainItem.menu = menu
        mainItem.button?.performClick(nil)
        mainItem.menu = nil
    }

    @objc private func toggleFromMenu() { toggle() }
    @objc private func openSettingsFromMenu() { onOpenSettings?() }
    @objc private func quitFromMenu() { onQuit?() }

    private static func symbol(named name: String, fallback: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "MenuHarbor")
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: "MenuHarbor")
        image?.isTemplate = true
        return image
    }
}

