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

        if !shelf.isVisible {
            didOpenByHover = false
        }

        if hotZone.contains(NSEvent.mouseLocation) {
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
        return region.insetBy(dx: -Self.hotZonePadding, dy: -Self.hotZonePadding)
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
