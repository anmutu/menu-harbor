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
        guard NSScreen.screens.contains(where: {
            Self.isMenuBarLocation(location, screenFrame: $0.frame, visibleFrame: $0.visibleFrame)
        }) else { return }

        guard Date.now >= cooldownUntil else { return }
        accumulatedDelta += abs(event.scrollingDeltaY) + abs(event.scrollingDeltaX)
        guard accumulatedDelta >= Self.triggerThreshold else { return }

        accumulatedDelta = 0
        cooldownUntil = Date.now.addingTimeInterval(Self.cooldownInterval)
        model.performPrimaryShortcut()
    }

    /// location 是否落在这一屏的菜单栏条带内。必须同时校验 x 和 y：
    /// 上下堆叠的显示器共享 x 范围，只按 x 选屏会把上方屏幕的任意滚动
    /// 都误判成"在菜单栏上滚动"。全屏空间下菜单栏高度为 0，视为不可交互。
    nonisolated static func isMenuBarLocation(
        _ location: CGPoint,
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> Bool {
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        guard menuBarHeight > 1 else { return false }
        guard screenFrame.minX <= location.x, location.x <= screenFrame.maxX else { return false }
        return screenFrame.maxY - menuBarHeight <= location.y && location.y <= screenFrame.maxY
    }
}
