import AppKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var preferences: HarborPreferences
    @Published private(set) var foldState: FoldState
    @Published private(set) var items: [MenuBarItemDescriptor] = []
    /// 位于始终隐藏区分隔标记左侧的项目（`items` 的子集），Shelf 用它画徽标。
    @Published private(set) var alwaysHiddenItemIDs: Set<UInt32> = []
    /// 收纳模式下可能被刘海遮挡的项目，Shelf 用它优先提示。
    @Published private(set) var atRiskItemIDs: Set<UInt32> = []
    @Published private(set) var snapshots: [UInt32: NSImage] = [:]
    @Published private(set) var capability: HarborCapability
    /// 折叠健康自检结果：nil 尚未检测，true 折叠真实生效，false 系统布局行为异常。
    @Published private(set) var foldIsReliable: Bool?
    @Published var query = "" {
        didSet {
            if query != oldValue { shelfSelectionIndex = 0 }
        }
    }
    @Published var notice: String?
    @Published var isShelfPresented = false {
        didSet {
            // 标记新会话：下一次真正执行的刷新全量重查名称、重截快照，
            // 会话内的 2.5 秒轮询才走复用路径。不在这里直接清空——
            // 若刷新恰好被 1 秒防抖跳过，清空会让图标短暂失去缩略图。
            guard isShelfPresented, !oldValue else { return }
            shelfSessionNeedsFreshCaches = true
        }
    }
    @Published var shelfSelectionIndex = 0
    /// 港湾每次显示时递增，ShelfView 借此把焦点移到搜索框。
    @Published var shelfFocusRequest = 0
    var onShortcutPreferenceChanged: ((Bool) -> Void)?
    var onShortcutCombinationChanged: ((Int, Int) -> Void)?
    var onPrimaryShortcut: (() -> Void)?
    var onHoverPreferenceChanged: ((Bool) -> Void)?
    var onScrollPreferenceChanged: ((Bool) -> Void)?

    private let store: PreferencesStore
    private let menuBar: MenuBarController
    private let scanner: MenuBarScanning
    private let interactor: MenuBarInteractor
    private let namer = StatusItemAXNamer()
    let permissions: PermissionManager
    private let launchAtLogin: LaunchAtLoginController
    private var autoHideTask: Task<Void, Never>?
    private var permissionPollingTask: Task<Void, Never>?
    private var noticeClearTask: Task<Void, Never>?
    private var foldHealthTask: Task<Void, Never>?
    private var screenChangeObserver: NSObjectProtocol?
    private var lastShelfRefreshAt = Date.distantPast
    /// 会话级缓存：AX 可读名称按窗口号复用，轮询期间只补查新出现的窗口。
    private var axNameCache: [UInt32: String] = [:]
    /// Shelf 重新打开后置位，下一次执行的刷新先清空会话缓存再全量采集。
    private var shelfSessionNeedsFreshCaches = false
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
        var shouldProbeFoldReliability = false
        let initialScreen = Self.screenForMenuBar(menuBar.mainButton)
        let collectOnlyAtLaunch = Self.screenHasNotch(initialScreen) || loadedPreferences.foldSupported == false
        menuBar.setCollectOnlyMode(collectOnlyAtLaunch)
        if loadedPreferences.hasCompletedOnboarding {
            if collectOnlyAtLaunch {
                // 刘海屏和已探测到不支持折叠的系统：直接进入收纳模式，不做无效尝试。
                menuBar.restore()
                self.foldState = .expanded
            } else {
                menuBar.fold()
                self.foldState = .folded
                shouldProbeFoldReliability = true
            }
        } else {
            // 首次启动进入整理模式，让用户看到两个分隔标记再布置。
            menuBar.restore()
            self.foldState = .expanded
        }
        self.capability = permissions.capability
        menuBar.updateIcon(style: loadedPreferences.iconStyle)

        permissions.$hasScreenCapturePermission
            .combineLatest(permissions.$hasAccessibilityPermission)
            .map { HarborCapability.resolve(screenCapture: $0, accessibility: $1) }
            .removeDuplicates()
            .sink { [weak self] capability in self?.capability = capability }
            .store(in: &cancellables)

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleScreenChange() }
        }

        if shouldProbeFoldReliability {
            scheduleFoldHealthCheck()
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    var filteredItems: [MenuBarItemDescriptor] {
        ShelfPresentation.filtered(items: items, query: query)
    }

    /// 方向键在图标带上移动选中项；越界时停在端点。
    func moveShelfSelection(by delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        shelfSelectionIndex = min(count - 1, max(0, shelfSelectionIndex + delta))
    }

    var permissionMessage: String? {
        ShelfPresentation.permissionMessage(for: capability)
    }

    var missingPermission: HarborPermission? {
        ShelfPresentation.missingPermission(for: capability)
    }

    /// 刘海屏和折叠已知不可靠的系统运行在收纳模式。
    /// 这样用户不需要先猜分隔线该拖到哪里，所有菜单栏图标都能从刘海下方找到。
    var isCollectOnlyMode: Bool { isNotchAwareScreen || preferences.usesCollectOnlyMode }

    /// auxiliaryTop*Area 在没有刘海的屏幕上为空，比 safeAreaInsets 更适合做判断。
    var isNotchAwareScreen: Bool {
        let screen = Self.screenForMenuBar(menuBar.mainButton)
        guard let screen else { return false }
        return Self.screenHasNotch(screen)
    }

    private static func screenForMenuBar(_ button: NSStatusBarButton?) -> NSScreen? {
        button?.window?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea?.isEmpty == false || $0.auxiliaryTopRightArea?.isEmpty == false })
    }

    private static func screenHasNotch(_ screen: NSScreen?) -> Bool {
        screen?.auxiliaryTopLeftArea?.isEmpty == false || screen?.auxiliaryTopRightArea?.isEmpty == false
    }

    /// 收纳模式下港湾锚定的屏幕（CG 坐标），用于只取本屏菜单栏图标、
    /// 去掉同一图标在其他显示器上的副本。
    private var anchorScreenCGFrame: CGRect? {
        guard
            let screen = Self.screenForMenuBar(menuBar.mainButton),
            let primaryHeight = primaryScreen?.frame.maxY
        else { return nil }
        return Self.cgFrame(of: screen, primaryHeight: primaryHeight)
    }

    /// 刘海在 CGWindowList 使用的左上原点坐标系中的遮挡区域。
    /// auxiliaryTop*Area 是屏幕坐标，左右安全区之间的缝隙就是摄像头区域。
    private var notchCGFrame: CGRect? {
        let screen = Self.screenForMenuBar(menuBar.mainButton)
        guard
            let screen,
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea,
            right.minX > left.maxX,
            let primaryHeight = primaryScreen?.frame.maxY
        else { return nil }

        return CGRect(
            x: left.maxX,
            y: primaryHeight - screen.frame.maxY,
            width: right.minX - left.maxX,
            height: max(24, screen.safeAreaInsets.top)
        )
    }

    func refreshShelf(force: Bool = false) {
        // 快速开关港湾时跳过 1 秒内的重复扫描和截图。
        if !force, Date.now.timeIntervalSince(lastShelfRefreshAt) < 1 {
            return
        }
        lastShelfRefreshAt = .now
        if shelfSessionNeedsFreshCaches {
            shelfSessionNeedsFreshCaches = false
            axNameCache.removeAll()
            snapshots = [:]
        }

        permissions.refresh()
        capability = permissions.capability

        let allItems = scanner.scan()
        let ownWindows = Set(
            [menuBar.mainWindowID, menuBar.dividerWindowID, menuBar.alwaysHiddenDividerWindowID]
                .compactMap { $0 }
        )

        let baseItems: [MenuBarItemDescriptor]
        if isCollectOnlyMode {
            guard let anchorScreenCGFrame else {
                items = []
                snapshots = [:]
                atRiskItemIDs = []
                alwaysHiddenItemIDs = []
                presentNotice("暂时找不到当前屏幕，请稍后重试")
                return
            }
            let collectedItems = ShelfPresentation.collectModeItems(
                in: allItems,
                excludedWindowIDs: ownWindows,
                screenFrame: anchorScreenCGFrame,
                rescueFrame: notchCGFrame
            ).filter { $0.ownerPID != ProcessInfo.processInfo.processIdentifier }
            let riskIDs = ShelfPresentation.atRiskWindowIDs(in: collectedItems, notchFrame: notchCGFrame)
            if atRiskItemIDs != riskIDs {
                atRiskItemIDs = riskIDs
            }
            if !alwaysHiddenItemIDs.isEmpty {
                alwaysHiddenItemIDs = []
            }
            baseItems = ShelfPresentation.collectModeOrder(collectedItems, atRisk: riskIDs)
        } else {
            guard let dividerWindowID = menuBar.dividerWindowID else {
                items = []
                snapshots = [:]
                atRiskItemIDs = []
                alwaysHiddenItemIDs = []
                presentNotice("暂时找不到分隔标记，请稍后重试")
                return
            }
            let partition = ItemPartitioner.partition(
                in: allItems,
                hiddenDividerWindowID: dividerWindowID,
                alwaysHiddenDividerWindowID: menuBar.alwaysHiddenDividerWindowID,
                screenFrames: cgScreenFrames
            )
            baseItems = partition.hidden.filter { $0.ownerPID != ProcessInfo.processInfo.processIdentifier }
            let alwaysIDs = Set(partition.alwaysHidden.map(\.windowID))
            if alwaysHiddenItemIDs != alwaysIDs {
                alwaysHiddenItemIDs = alwaysIDs
            }
            if !atRiskItemIDs.isEmpty {
                atRiskItemIDs = []
            }
        }
        let clampedSelection = min(shelfSelectionIndex, max(0, baseItems.count - 1))
        if shelfSelectionIndex != clampedSelection {
            shelfSelectionIndex = clampedSelection
        }

        // Tahoe 上窗口名多为 "Item-0"、owner 统一是 Control Center，
        // 有辅助功能权限时改用 AX 的可读名称（如 "WiFi"、"飞书"）。
        // AX 查询是跨进程往返，轮询期间只为新出现的窗口号补查。
        if permissions.hasAccessibilityPermission {
            let unresolved = baseItems.filter { axNameCache[$0.windowID] == nil }
            for (windowID, name) in namer.resolveNames(for: unresolved) {
                axNameCache[windowID] = name
            }
        }
        let currentIDs = Set(baseItems.map(\.windowID))
        axNameCache = axNameCache.filter { currentIDs.contains($0.key) }
        let resolved = baseItems.map { item in
            guard let name = axNameCache[item.windowID], !name.isEmpty else { return item }
            return item.withName(name)
        }
        // 内容未变化时不重新赋值：轮询每 2.5 秒跑一次，无条件发布会
        // 让 SwiftUI 每轮都重绘整个 Shelf。
        if resolved != items {
            items = resolved
        }

        guard permissions.hasScreenCapturePermission else {
            if !snapshots.isEmpty {
                snapshots = [:]
            }
            return
        }

        // 窗口号未变且帧尺寸未变的图标复用上一轮截图，只补拍新增/变形的。
        var nextSnapshots = Dictionary(
            uniqueKeysWithValues: resolved.compactMap { item -> (UInt32, NSImage)? in
                guard let existing = snapshots[item.windowID],
                      SnapshotReusePolicy.shouldReuse(existingSize: existing.size, frame: item.frame)
                else { return nil }
                return (item.windowID, existing)
            }
        )
        var capturedAny = false
        for item in resolved where nextSnapshots[item.windowID] == nil {
            let size = SnapshotReusePolicy.snapshotSize(for: item.frame)
            if let image = scanner.snapshot(windowID: item.windowID, size: size) {
                nextSnapshots[item.windowID] = image
                capturedAny = true
            }
        }
        // 复用值与旧字典同实例：没有新拍且数量一致，即内容完全没变。
        if capturedAny || nextSnapshots.count != snapshots.count {
            snapshots = nextSnapshots
        }
    }

    /// 快捷键和滚动手势的统一入口。刘海安全模式下它们打开 Shelf，
    /// 避免用户得到“系统不支持收起”的死胡同提示。
    func performPrimaryShortcut() {
        if isCollectOnlyMode {
            onPrimaryShortcut?()
        } else {
            toggleFold()
        }
    }

    /// CG 全局坐标系（原点在主屏左上）下的所有屏幕 frame，供跨屏分区使用。
    private var cgScreenFrames: [CGRect] {
        guard let primaryHeight = primaryScreen?.frame.maxY else { return [] }
        return NSScreen.screens.map { Self.cgFrame(of: $0, primaryHeight: primaryHeight) }
    }

    /// NSScreen 坐标（原点在主屏左下）→ CG 全局坐标（原点在主屏左上）。
    private static func cgFrame(of screen: NSScreen, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: screen.frame.minX,
            y: primaryHeight - screen.frame.maxY,
            width: screen.frame.width,
            height: screen.frame.height
        )
    }

    private var primaryScreen: NSScreen? {
        let displayNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let mainDisplay = CGMainDisplayID()
        return NSScreen.screens.first {
            ($0.deviceDescription[displayNumberKey] as? NSNumber)?.uint32Value == mainDisplay
        } ?? NSScreen.screens.first ?? NSScreen.main
    }

    func toggleFold() {
        if isCollectOnlyMode {
            onPrimaryShortcut?()
            return
        }
        if foldState == .folded {
            menuBar.expand()
            foldState = .expanded
            presentNotice("菜单栏已展开")
            resetFoldHealth()
            scheduleAutoHide()
        } else if foldIsReliable == false || preferences.foldSupported == false {
            // 已知本机不支持折叠：不再做注定失败的尝试，避免窗口被系统回收再恢复的闪烁。
            presentNotice("当前系统不支持收起图标，港湾保持可用")
        } else {
            menuBar.fold()
            foldState = .folded
            presentNotice("已收进港湾")
            cancelAutoHide()
            scheduleFoldHealthCheck()
        }
    }

    func expand() {
        menuBar.expand()
        foldState = .expanded
        presentNotice("菜单栏已展开")
        scheduleAutoHide()
    }

    func fold() {
        guard !isCollectOnlyMode, foldIsReliable != false, preferences.foldSupported != false else {
            presentNotice("当前系统不支持收起图标，已保持展开")
            return
        }
        menuBar.fold()
        foldState = .folded
        presentNotice("已收进港湾")
        cancelAutoHide()
        scheduleFoldHealthCheck()
    }

    func restore() {
        menuBar.restore()
        foldState = .expanded
        presentNotice("所有图标已恢复到菜单栏")
        cancelAutoHide()
        resetFoldHealth()
    }

    func activate(_ item: MenuBarItemDescriptor) async {
        switch await interactor.activate(item, inCollectOnlyMode: isCollectOnlyMode) {
        case .clicked:
            foldState = menuBar.state.isFolded ? .folded : .expanded
            scheduleAutoHide()
        case .expandedForManualClick:
            foldState = .expanded
            presentNotice(isCollectOnlyMode ? "请开启辅助功能，才能在港湾中直接点击该图标" : "已展开，请在原生菜单栏中点击该图标")
        case .missing:
            presentNotice("这个图标刚刚发生了变化，已为你刷新")
            refreshShelf(force: true)
        case .failed:
            if isCollectOnlyMode {
                // 收纳模式没有可展开的折叠区；图标本来就全部可见。
                presentNotice("无法代为点击该图标，请在原生菜单栏中手动点击")
            } else {
                expand()
                presentNotice("无法代为点击，已安全展开原生菜单栏")
            }
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

    func setShortcut(keyCode: Int, modifiers: Int, display: String) {
        updatePreferences {
            $0.shortcutKeyCode = keyCode
            $0.shortcutModifiers = modifiers
            $0.shortcutDisplay = display
        }
        onShortcutCombinationChanged?(keyCode, modifiers)
    }

    func setIconStyle(_ style: HarborPreferences.IconStyle) {
        updatePreferences { $0.iconStyle = style }
        menuBar.updateIcon(style: style)
    }

    func setHoverOpensShelf(_ enabled: Bool) {
        updatePreferences { $0.hoverOpensShelf = enabled }
        onHoverPreferenceChanged?(enabled)
    }

    /// 悬停控制器每次移动都直接读取偏好，这里只需持久化。
    func setHoverZoneWide(_ enabled: Bool) {
        updatePreferences { $0.hoverZoneWide = enabled }
    }

    func setScrollTogglesMenuBar(_ enabled: Bool) {
        updatePreferences { $0.scrollTogglesMenuBar = enabled }
        onScrollPreferenceChanged?(enabled)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            updatePreferences { $0.launchAtLogin = enabled }
        } catch {
            presentNotice("无法更新登录启动：\(error.localizedDescription)")
        }
    }

    /// 引导和设置窗口可见期间轮询权限状态，让用户从系统设置授权回来后界面立即更新。
    func startPermissionPolling() {
        guard permissionPollingTask == nil else { return }
        permissionPollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                self?.permissions.refresh()
            }
        }
    }

    func stopPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = nil
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

    func requestMissingPermission() {
        switch missingPermission {
        case .screenCapture:
            requestScreenCapture()
        case .accessibility:
            requestAccessibility()
        case nil:
            break
        }
    }

    /// 快捷键组合被其他应用占用时明确告知；静默失效只会让用户
    /// 以为功能坏了（故障排查文档里"快捷键没反应"的头号原因）。
    func reportShortcutConflict() {
        presentNotice("快捷键注册失败：可能被其他应用占用，请在设置中录制新的组合")
    }

    private func updatePreferences(_ change: (inout HarborPreferences) -> Void) {
        var next = preferences
        change(&next)
        preferences = next
        store.save(next)
    }

    private func scheduleAutoHide() {
        autoHideTask?.cancel()
        let delay = preferences.autoHideDelay
        guard delay > 0, !isCollectOnlyMode else { return }
        autoHideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            while !Task.isCancelled, let self,
                  AutoHidePolicy.shouldDefer(
                    isShelfPresented: self.isShelfPresented,
                    isCommandKeyDown: NSEvent.modifierFlags.contains(.command)
                  ) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            self?.fold()
        }
    }

    /// 折叠后验证隐藏项真的离开了屏幕。macOS 26 会把折叠项的窗口整个
    /// 回收（dividerWindowID 变 nil 即信号），此时自动恢复展开、转入
    /// "只收纳不推挤"模式：菜单栏保持原生布局，港湾仍然可用。
    private func scheduleFoldHealthCheck() {
        foldHealthTask?.cancel()
        foldHealthTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }

            for attempt in 0..<FoldReliabilityPolicy.healthProbeAttempts {
                guard !Task.isCancelled, self.foldState == .folded, self.menuBar.state.isFolded else { return }

                var effective = false
                if let dividerWindowID = self.menuBar.dividerWindowID,
                   let alwaysHiddenID = self.menuBar.alwaysHiddenDividerWindowID {
                    let allItems = self.scanner.scan()
                    let partition = ItemPartitioner.partition(
                        in: allItems,
                        hiddenDividerWindowID: dividerWindowID,
                        alwaysHiddenDividerWindowID: alwaysHiddenID,
                        screenFrames: self.cgScreenFrames
                    )
                    let hidden = partition.hidden.filter { $0.ownerPID != ProcessInfo.processInfo.processIdentifier }
                    effective = FoldReliabilityPolicy.isFoldEffective(
                        items: hidden,
                        screenFrames: self.cgScreenFrames
                    )
                }

                if effective {
                    self.foldIsReliable = true
                    if self.preferences.foldSupported != true {
                        self.updatePreferences { $0.foldSupported = true }
                    }
                    return
                }

                guard attempt + 1 < FoldReliabilityPolicy.healthProbeAttempts else {
                    self.handleUnreliableFold()
                    return
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    /// 折叠被系统破坏时自动回到展开态，转入"只收纳不推挤"模式，
    /// 并把结果持久化，之后启动和切换不再做无效尝试。
    private func handleUnreliableFold() {
        foldIsReliable = false
        updatePreferences { $0.foldSupported = false }
        menuBar.restore()
        foldState = .expanded
        presentNotice("当前系统不支持收起图标，已自动展开并转入收纳模式")
        cancelAutoHide()
    }

    private func resetFoldHealth() {
        foldHealthTask?.cancel()
        foldHealthTask = nil
        foldIsReliable = nil
    }

    private func presentNotice(_ message: String) {
        notice = message
        noticeClearTask?.cancel()
        noticeClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            if self?.notice == message {
                self?.notice = nil
            }
        }
    }

    private func cancelAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }

    private func handleScreenChange() {
        menuBar.setCollectOnlyMode(isCollectOnlyMode)
        if isCollectOnlyMode {
            menuBar.restore()
            foldState = .expanded
            resetFoldHealth()
            // 收纳模式下 fold() 必然被拦下；留着切屏前排下的自动收起任务，
            // 只会在几十秒后触发一次注定失败的折叠并弹出误导性的
            // "当前系统不支持收起图标"提示。
            cancelAutoHide()
        } else if foldState == .expanded {
            // 回到折叠模式：沿用既有的自动收起节奏（delay 为 0 时是空操作）。
            scheduleAutoHide()
        }
        if isShelfPresented {
            refreshShelf(force: true)
        }
    }
}
