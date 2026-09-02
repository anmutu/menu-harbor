import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var preferences: HarborPreferences
    @Published private(set) var foldState: FoldState
    @Published private(set) var items: [MenuBarItemDescriptor] = []
    @Published private(set) var snapshots: [UInt32: NSImage] = [:]
    @Published private(set) var capability: HarborCapability
    @Published var query = ""
    @Published var notice: String?
    @Published var isShelfPresented = false
    var onShortcutPreferenceChanged: ((Bool) -> Void)?

    private let store: PreferencesStore
    private let menuBar: MenuBarController
    private let scanner: MenuBarScanning
    private let interactor: MenuBarInteractor
    let permissions: PermissionManager
    private let launchAtLogin: LaunchAtLoginController
    private var autoHideTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        store: PreferencesStore,
        menuBar: MenuBarController,
        scanner: MenuBarScanning,
        interactor: MenuBarInteractor,
        permissions: PermissionManager,
        launchAtLogin: LaunchAtLoginController
    ) {
        self.store = store
        self.menuBar = menuBar
        self.scanner = scanner
        self.interactor = interactor
        self.permissions = permissions
        self.launchAtLogin = launchAtLogin
        let loadedPreferences = store.load()
        self.preferences = loadedPreferences
        if loadedPreferences.hasCompletedOnboarding {
            menuBar.fold()
        } else {
            menuBar.expand()
        }
        self.foldState = menuBar.state
        self.capability = permissions.capability
        menuBar.updateIcon(style: loadedPreferences.iconStyle)

        permissions.$hasScreenCapturePermission
            .combineLatest(permissions.$hasAccessibilityPermission)
            .map { HarborCapability.resolve(screenCapture: $0, accessibility: $1) }
            .removeDuplicates()
            .sink { [weak self] capability in self?.capability = capability }
            .store(in: &cancellables)
    }

    var filteredItems: [MenuBarItemDescriptor] {
        ShelfPresentation.filtered(items: items, query: query)
    }

    var permissionMessage: String? {
        ShelfPresentation.permissionMessage(for: capability)
    }

    func refreshShelf() {
        permissions.refresh()
        capability = permissions.capability

        guard let dividerWindowID = menuBar.dividerWindowID else {
            items = []
            snapshots = [:]
            notice = "暂时找不到分隔标记，请稍后重试"
            return
        }

        let allItems = scanner.scan()
        items = ItemPartitioner.hiddenItems(in: allItems, dividerWindowID: dividerWindowID)
            .filter { $0.ownerPID != ProcessInfo.processInfo.processIdentifier }

        guard permissions.hasScreenCapturePermission else {
            snapshots = [:]
            return
        }

        snapshots = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            let size = CGSize(width: max(18, item.frame.width), height: max(18, item.frame.height))
            return scanner.snapshot(windowID: item.windowID, size: size).map { (item.windowID, $0) }
        })
    }

    func toggleFold() {
        menuBar.toggle()
        foldState = menuBar.state
        notice = foldState == .folded ? "已收进港湾" : "菜单栏已展开"
        foldState == .folded ? cancelAutoHide() : scheduleAutoHide()
    }

    func expand() {
        menuBar.expand()
        foldState = .expanded
        notice = "菜单栏已展开"
        scheduleAutoHide()
    }

    func fold() {
        menuBar.fold()
        foldState = .folded
        notice = "已收进港湾"
        cancelAutoHide()
    }

    func restore() {
        menuBar.restore()
        foldState = .expanded
        notice = "所有图标已恢复到菜单栏"
        cancelAutoHide()
    }

    func activate(_ item: MenuBarItemDescriptor) async {
        switch await interactor.activate(item) {
        case .clicked:
            foldState = menuBar.state
            scheduleAutoHide()
        case .expandedForManualClick:
            foldState = .expanded
            notice = "已展开，请在原生菜单栏中点击该图标"
        case .missing:
            notice = "这个图标刚刚发生了变化，已为你刷新"
            refreshShelf()
        case .failed:
            expand()
            notice = "无法代为点击，已安全展开原生菜单栏"
        }
    }

    func setAutoHideDelay(_ delay: TimeInterval) {
        updatePreferences { $0.autoHideDelay = delay }
        if foldState == .expanded { scheduleAutoHide() }
    }

    func setShortcutEnabled(_ enabled: Bool) {
        updatePreferences { $0.shortcutEnabled = enabled }
        onShortcutPreferenceChanged?(enabled)
    }

    func setIconStyle(_ style: HarborPreferences.IconStyle) {
        updatePreferences { $0.iconStyle = style }
        menuBar.updateIcon(style: style)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            updatePreferences { $0.launchAtLogin = enabled }
        } catch {
            notice = "无法更新登录启动：\(error.localizedDescription)"
        }
    }

    func completeOnboarding() {
        updatePreferences { $0.hasCompletedOnboarding = true }
    }

    func requestScreenCapture() {
        permissions.requestScreenCapture()
    }

    func requestAccessibility() {
        permissions.requestAccessibility()
    }

    private func updatePreferences(_ change: (inout HarborPreferences) -> Void) {
        var next = preferences
        change(&next)
        preferences = next
        store.save(next)
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        guard let deadline = AutoHidePolicy.deadline(now: .now, delay: preferences.autoHideDelay) else { return }
        let nanoseconds = UInt64(max(0, deadline.timeIntervalSinceNow) * 1_000_000_000)
        autoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            self?.fold()
        }
    }

    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }
}
