import AppKit

/// 菜单栏布局三态：
/// - `allFolded`：隐藏区和始终隐藏区都被推出屏幕；
/// - `hiddenShown`：隐藏区可见，始终隐藏区保持收起（Ice 的三区语义）；
/// - `allShown`：整理模式，全部图标可见，方便 ⌘ 拖拽布置两个分隔标记。
enum MenuBarLayout: Equatable {
    case allFolded
    case hiddenShown
    case allShown

    var isFolded: Bool { self == .allFolded }
}

@MainActor
final class MenuBarController: NSObject {
    static let dividerLength: CGFloat = 18
    static let foldedLength: CGFloat = 10_000

    var onPrimaryAction: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRestoreAll: (() -> Void)?
    var onQuit: (() -> Void)?

    private(set) var state: MenuBarLayout = .hiddenShown
    private(set) var isCollectOnlyMode = false

    private let mainItem: NSStatusItem
    private let dividerItem: NSStatusItem
    private let alwaysHiddenItem: NSStatusItem
    private var applyRetryTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?

    override init() {
        dividerItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        alwaysHiddenItem = NSStatusBar.system.statusItem(withLength: Self.dividerLength)
        // 最后创建主入口，使它默认靠近系统控制中心，尽量不被刘海和应用菜单挤掉。
        mainItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureMainItem()
        configureDividerItem()
        configureAlwaysHiddenItem()
        applyState()
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleApplyRetry() }
        }
    }

    deinit {
        applyRetryTask?.cancel()
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
        NSStatusBar.system.removeStatusItem(mainItem)
        NSStatusBar.system.removeStatusItem(dividerItem)
        NSStatusBar.system.removeStatusItem(alwaysHiddenItem)
    }

    /// 状态项窗口号。macOS 26 折叠回收状态项窗口后，NSWindow 会变成
    /// 僵尸对象，windowNumber 读出负数甚至超过 UInt32 的垃圾值，
    /// 任何直接转换都会触发运行时 trap，必须用 exactly 安全转换。
    private func statusWindowNumber(of item: NSStatusItem) -> UInt32? {
        guard let window = item.button?.window else { return nil }
        return UInt32(exactly: window.windowNumber)
    }

    var mainWindowID: UInt32? {
        statusWindowNumber(of: mainItem)
    }

    var dividerWindowID: UInt32? {
        statusWindowNumber(of: dividerItem)
    }

    var alwaysHiddenDividerWindowID: UInt32? {
        statusWindowNumber(of: alwaysHiddenItem)
    }

    var mainButton: NSStatusBarButton? {
        mainItem.button
    }

    func toggle() {
        guard !isCollectOnlyMode else { return }
        state = state == .allFolded ? .hiddenShown : .allFolded
        applyStateOrRetry()
    }

    func fold() {
        guard !isCollectOnlyMode else { return }
        state = .allFolded
        applyStateOrRetry()
    }

    func expand() {
        state = isCollectOnlyMode ? .allShown : .hiddenShown
        applyStateOrRetry()
    }

    func restore() {
        state = .allShown
        applyStateOrRetry()
    }

    func setCollectOnlyMode(_ enabled: Bool) {
        isCollectOnlyMode = enabled
        if enabled {
            state = .allShown
        }
        applyStateOrRetry()
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

    private func configureAlwaysHiddenItem() {
        alwaysHiddenItem.autosaveName = "MenuHarbor.AlwaysHiddenDivider"
        guard let button = alwaysHiddenItem.button else { return }
        button.image = Self.symbol(named: "arrow.left.to.line", fallback: "chevron.left")
        button.imagePosition = .imageOnly
        button.toolTip = "始终隐藏区标记 · 按住 ⌘ 把不再需要的图标拖到它的左侧；点它收起该区"
        button.target = self
        button.action = #selector(handleAlwaysHiddenDividerClick)
    }

    private func applyStateOrRetry() {
        guard !applyState() else { return }
        scheduleApplyRetry()
    }

    @discardableResult
    private func applyState() -> Bool {
        // macOS 26 会把折叠推出的状态项窗口整个回收；窗口不在时
        // 任何布局修改都是未定义行为，直接跳过，交给有限重试恢复。
        guard dividerItem.button?.window != nil, alwaysHiddenItem.button?.window != nil else {
            return false
        }
        dividerItem.length = isCollectOnlyMode ? 0 : (state == .allFolded ? Self.foldedLength : Self.dividerLength)
        alwaysHiddenItem.length = isCollectOnlyMode ? 0 : (state == .allShown ? Self.dividerLength : Self.foldedLength)
        if let button = mainItem.button {
            button.contentTintColor = state.isFolded ? nil : .systemTeal
            button.toolTip = state.isFolded ? "MenuHarbor · 打开港湾" : "MenuHarbor · 菜单栏已展开"
        }
        return true
    }

    private func scheduleApplyRetry() {
        applyRetryTask?.cancel()
        applyRetryTask = Task { @MainActor [weak self] in
            for _ in 0..<12 {
                guard let self, !Task.isCancelled else { return }
                if self.applyState() { return }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
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
        guard !isCollectOnlyMode else { return }
        toggle()
    }

    @objc
    private func handleAlwaysHiddenDividerClick() {
        // 整理模式下点击竖线标记：收起始终隐藏区，其余保持展开。
        guard !isCollectOnlyMode else { return }
        expand()
    }

    private func showContextMenu() {
        let menu = NSMenu()
        if isCollectOnlyMode {
            menu.addItem(withTitle: "打开港湾", action: #selector(openShelfFromMenu), keyEquivalent: "")
        } else {
            menu.addItem(withTitle: state.isFolded ? "展开菜单栏" : "收起菜单栏", action: #selector(toggleFromMenu), keyEquivalent: "")
            if state != .allShown {
                menu.addItem(withTitle: "整理模式（显示全部）", action: #selector(restoreAllFromMenu), keyEquivalent: "")
            }
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        menu.addItem(withTitle: "退出 MenuHarbor", action: #selector(quitFromMenu), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        mainItem.menu = menu
        mainItem.button?.performClick(nil)
        mainItem.menu = nil
    }

    @objc private func toggleFromMenu() { toggle() }
    @objc private func openShelfFromMenu() { onPrimaryAction?() }
    @objc private func restoreAllFromMenu() { onRestoreAll?() }
    @objc private func openSettingsFromMenu() { onOpenSettings?() }
    @objc private func quitFromMenu() { onQuit?() }

    private static func symbol(named name: String, fallback: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "MenuHarbor")
            ?? NSImage(systemSymbolName: fallback, accessibilityDescription: "MenuHarbor")
        image?.isTemplate = true
        return image
    }
}
