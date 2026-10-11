import AppKit

/// 可选的"悬停展开"交互：鼠标在主按钮或刘海安全热区上短暂停留时打开港湾，
/// 离开港湾区域后柔和收起。竞品（Bartender / Ice）的标配交互，默认开启。
@MainActor
final class HoverShelfController {
    private static let openDwellInterval: UInt64 = 250_000_000
    private static let closeGraceInterval: UInt64 = 700_000_000
    /// 热区外扩，让按钮边缘的轻微抖动不重置计时。
    private static let hotZonePadding: CGFloat = 4

    private let model: AppModel
    private let menuBar: MenuBarController
    private let shelf: ShelfPanel
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var didOpenByHover = false

    init(model: AppModel, menuBar: MenuBarController, shelf: ShelfPanel) {
        self.model = model
        self.menuBar = menuBar
        self.shelf = shelf
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? install() : uninstall()
    }

    private func install() {
        guard localMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .otherMouseDragged]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handlePointerMove()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.handlePointerMove()
        }
    }

    private func uninstall() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil
        openTask?.cancel()
        openTask = nil
        closeTask?.cancel()
        closeTask = nil
        didOpenByHover = false
    }

    private func handlePointerMove() {
        guard model.preferences.hoverOpensShelf else { return }

        let location = NSEvent.mouseLocation

        if !shelf.isVisible {
            didOpenByHover = false
        }

        // 热区只可能贴着屏幕顶部（主按钮/刘海/菜单栏右半侧）或 Shelf 自身。
        // 全局 mouseMoved 事件在鼠标每次移动时都会到达，提前返回能省掉
        // 大量无关位置的并集计算；未触发的开合任务自带热区复核，不会误开。
        let mayTouchHotZone = shelf.isVisible
            || NSScreen.screens.contains { location.y >= $0.frame.maxY - 64 }
        guard mayTouchHotZone else { return }

        if hotZone.contains(location) {
            closeTask?.cancel()
            closeTask = nil
            if !shelf.isVisible, !model.isShelfPresented {
                scheduleOpen()
            }
        } else {
            openTask?.cancel()
            openTask = nil
            if shelf.isVisible, didOpenByHover {
                scheduleClose()
            }
        }
    }

    private var hotZone: NSRect {
        let buttonFrame = menuBar.mainButton?.window?.frame ?? .zero
        var region = shelf.isVisible ? buttonFrame.union(shelf.frame) : buttonFrame
        if let notchZone {
            region = region.union(notchZone)
        }
        if model.preferences.hoverZoneWide,
           let wideZone = menuBarRightZone(for: NSEvent.mouseLocation) {
            region = region.union(wideZone)
        }
        // 主按钮窗口尚未创建（启动初期）且没有任何其他热区时，
        // 不能让 insetBy 把零矩形吹成贴着屏幕左下角的小热区。
        guard region != .zero else { return .zero }
        return region.insetBy(dx: -Self.hotZonePadding, dy: -Self.hotZonePadding)
    }

    /// 菜单栏右半侧（状态项所在区域）。悬停区域扩展开启时作为入口热区；
    /// 左半侧是应用菜单，不能纳入，否则切换应用菜单时港湾会误弹出。
    private func menuBarRightZone(for location: NSPoint) -> NSRect? {
        guard
            let screen = menuBar.mainButton?.window?.screen
                ?? NSScreen.screens.first(where: { $0.frame.contains(location) })
        else {
            return nil
        }
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        guard menuBarHeight > 1 else { return nil }
        return NSRect(
            x: screen.frame.midX,
            y: screen.frame.maxY - menuBarHeight,
            width: screen.frame.width / 2,
            height: menuBarHeight
        )
    }

    /// 刘海正下方的窄热区。它只在系统提供左右安全区域时存在，
    /// 因而不会把普通屏幕顶部误当成入口。
    private var notchZone: NSRect? {
        let screen = menuBar.mainButton?.window?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        guard
            let screen,
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea,
            right.minX > left.maxX
        else { return nil }

        let height = max(32, screen.safeAreaInsets.top)
        return NSRect(
            x: left.maxX,
            y: screen.frame.maxY - height,
            width: right.minX - left.maxX,
            height: height
        )
    }

    private func scheduleOpen() {
        guard openTask == nil else { return }
        openTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.openDwellInterval)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.openTask = nil
            guard self.model.preferences.hoverOpensShelf, !self.shelf.isVisible,
                  self.hotZone.contains(NSEvent.mouseLocation)
            else { return }
            // 悬停打开不抢键盘焦点，避免打断用户正在进行的输入。
            self.shelf.show(relativeTo: self.menuBar.mainButton, makeKey: false)
            self.didOpenByHover = true
        }
    }

    private func scheduleClose() {
        guard closeTask == nil else { return }
        closeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.closeGraceInterval)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.closeTask = nil
            guard self.shelf.isVisible, self.didOpenByHover,
                  !self.hotZone.contains(NSEvent.mouseLocation)
            else { return }
            self.shelf.close()
            self.didOpenByHover = false
        }
    }
}
