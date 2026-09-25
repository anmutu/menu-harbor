import AppKit

/// 可选的"滚动切换"交互：在菜单栏上滚动滚轮即收起/展开菜单栏。
/// 菜单栏本身不消费滚动事件，属于死区，误触风险低；
/// 轨迹板惯性滚动会连续触发，用累积量 + 冷却窗口去抖。
@MainActor
final class MenuBarScrollController {
    /// 累计滚动量达到该阈值才触发，过滤轻微滚动。
    private static let triggerThreshold: CGFloat = 8
    /// 触发后的冷却期，忽略惯性滚动的余量。
    private static let cooldownInterval: TimeInterval = 1.0

    private let model: AppModel
    private var monitor: Any?
    private var accumulatedDelta: CGFloat = 0
    private var cooldownUntil = Date.distantPast

    init(model: AppModel) {
        self.model = model
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? install() : uninstall()
    }

    private func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            // 全局监听回调线程不保证是主线程，安全 hop，不用 assumeIsolated。
            Task { @MainActor in
                self?.handleScroll(event)
            }
        }
    }

    private func uninstall() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        accumulatedDelta = 0
    }

    private func handleScroll(_ event: NSEvent) {
        guard model.preferences.scrollTogglesMenuBar else { return }
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.minX <= location.x && location.x <= $0.frame.maxX }),
              let menuBarHeight = menuBarHeight(of: screen),
              location.y >= screen.frame.maxY - menuBarHeight
        else { return }

        guard Date.now >= cooldownUntil else { return }
        accumulatedDelta += abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX)
        guard accumulatedDelta >= Self.triggerThreshold else { return }

        accumulatedDelta = 0
        cooldownUntil = Date.now.addingTimeInterval(Self.cooldownInterval)
        model.performPrimaryShortcut()
    }

    /// 菜单栏高度 = 屏幕高度与可见区域上沿的差（可见区域不含菜单栏，但可能含 Dock）。
    /// 全屏空间下两者相等，返回 nil 表示该屏幕没有可交互的菜单栏。
    private func menuBarHeight(of screen: NSScreen) -> CGFloat? {
        let height = screen.frame.maxY - screen.visibleFrame.maxY
        return height > 1 ? height : nil
    }
}
