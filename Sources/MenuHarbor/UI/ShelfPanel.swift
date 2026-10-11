import AppKit
import SwiftUI

@MainActor
final class ShelfPanel: NSPanel {
    /// 关闭后的短暂窗口期内拒绝再次显示，避免"点击主按钮关闭 →
    /// 失焦关闭先触发 → mouseUp 又把它当新请求打开"的抖动。
    private static let reopenDebounce: TimeInterval = 0.25

    private let model: AppModel
    private var resignKeyObserver: NSObjectProtocol?
    private var spaceChangeObserver: NSObjectProtocol?
    private var displayChangeObserver: NSObjectProtocol?
    private var keyDownMonitor: Any?
    private var refreshTask: Task<Void, Never>?
    private var lastClosedAt = Date.distantPast

    init(model: AppModel) {
        self.model = model
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 248),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "MenuHarbor"
        isFloatingPanel = true
        level = .mainMenu + 1
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = NSHostingView(rootView: ShelfView(model: model, dismiss: { [weak self] in self?.close() }))

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }

        spaceChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }

        displayChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.close() }
        }

        // 搜索框聚焦时 SwiftUI 的 onMoveCommand 收不到方向键；
        // 搜索词为空时在这里拦截方向键驱动选中，非空时放行给文本光标。
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                let self,
                self.isVisible,
                self.isKeyWindow,
                [Self.keyCodeLeft, Self.keyCodeRight].contains(event.keyCode),
                self.model.query.isEmpty
            else {
                return event
            }
            Task { @MainActor [weak self] in
                self?.model.moveShelfSelection(by: event.keyCode == Self.keyCodeLeft ? -1 : 1)
            }
            return nil
        }
    }

    private static let keyCodeLeft: UInt16 = 123
    private static let keyCodeRight: UInt16 = 124

    /// 面板宽度：随图标数量增长，下限 440、上限 640，且不超出安全区。
    nonisolated static func panelWidth(forItemCount count: Int, safeFrame: CGRect) -> CGFloat {
        min(max(440, CGFloat(count) * 68 + 80), min(640, safeFrame.width - 24))
    }

    /// 会话中菜单栏项增减时保证面板装得下。只增宽不缩宽：
    /// 窗口号在 2.5 秒轮询间可能小幅抖动，双向自适应会让宽度反复横跳；
    /// 重新打开时 show() 会按当时的数量重新定宽。
    private func growToFitItemCount() {
        guard isVisible, let currentScreen = screen ?? NSScreen.main else { return }
        let safeFrame = currentScreen.visibleFrame
        let target = Self.panelWidth(forItemCount: model.items.count, safeFrame: safeFrame)
        guard target > frame.width + 0.5 else { return }
        var next = frame
        next.size.width = target
        next.origin.x = min(max(frame.midX - target / 2, safeFrame.minX + 12), safeFrame.maxX - target - 12)
        setFrame(next, display: true)
    }

    deinit {
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
        if let spaceChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceChangeObserver)
        }
        if let displayChangeObserver {
            NotificationCenter.default.removeObserver(displayChangeObserver)
        }
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func toggle(relativeTo anchor: NSStatusBarButton?) {
        if isVisible {
            close()
        } else {
            show(relativeTo: anchor)
        }
    }

    func show(relativeTo anchor: NSStatusBarButton?, makeKey: Bool = true) {
        guard Date.now.timeIntervalSince(lastClosedAt) > Self.reopenDebounce else { return }
        let targetScreen = anchor?.window?.screen ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen = targetScreen else { return }

        // 先置 isShelfPresented：它的 didSet 标记新会话，
        // 随后的刷新会全量重查名称与快照。
        model.isShelfPresented = true
        model.refreshShelf()
        model.shelfFocusRequest += 1
        startRefreshLoop()

        let safeFrame = screen.visibleFrame
        let anchorFrame = anchor?.window?.frame ?? NSRect(x: safeFrame.midX, y: safeFrame.maxY, width: 1, height: 1)
        let width = Self.panelWidth(forItemCount: model.items.count, safeFrame: safeFrame)
        let height: CGFloat = model.items.isEmpty ? 230 : 248
        let x = min(max(anchorFrame.midX - width / 2, safeFrame.minX + 12), safeFrame.maxX - width - 12)
        let y = safeFrame.maxY - height - 8

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        alphaValue = 0
        orderFrontRegardless()
        if makeKey {
            super.makeKey()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            animator().alphaValue = 1
        }
    }

    override func close() {
        guard isVisible || isKeyWindow else { return }
        lastClosedAt = Date.now
        refreshTask?.cancel()
        refreshTask = nil
        model.isShelfPresented = false
        super.close()
    }

    /// 菜单栏状态项会随 VPN、云盘、会议工具等应用启动/退出而变化。
    /// 竞品会在浮窗打开期间持续同步；短轮询让港湾不需要用户手动重开或点击”重新扫描”。
    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled, let self, self.isVisible else { return }
                self.model.refreshShelf(force: true)
                self.growToFitItemCount()
            }
        }
    }
}
