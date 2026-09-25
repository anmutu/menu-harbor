import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class MenuBarInteractor {
    enum Result: Equatable {
        case clicked
        case expandedForManualClick
        case missing
        case failed
    }

    private let controller: MenuBarController
    private let scanner: MenuBarScanning
    private let permissions: PermissionManager
    init(
        controller: MenuBarController,
        scanner: MenuBarScanning,
        permissions: PermissionManager
    ) {
        self.controller = controller
        self.scanner = scanner
        self.permissions = permissions
    }

    func activate(_ item: MenuBarItemDescriptor, inCollectOnlyMode: Bool = false) async -> Result {
        let plan = ItemActivationPlan.make(
            itemExists: scanner.descriptor(windowID: item.windowID) != nil,
            accessibility: permissions.hasAccessibilityPermission
        )

        switch plan {
        case .refresh:
            return .missing
        case .expandForManualClick:
            inCollectOnlyMode ? controller.restore() : controller.expand()
            return .expandedForManualClick
        case .click:
            // 聚合模式保持全部原生图标可见；传统折叠模式才需要先展开隐藏区。
            inCollectOnlyMode ? controller.restore() : controller.expand()
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard var current = scanner.descriptor(windowID: item.windowID) else { return .missing }
            if !inCollectOnlyMode, !current.isOnScreen {
                // 始终隐藏区的项目只在整理模式（完全恢复）下可见。
                controller.restore()
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let revealed = scanner.descriptor(windowID: item.windowID) else { return .missing }
                current = revealed
            }
            if pressViaAccessibility(current) {
                return .clicked
            }
            return postClick(to: current) ? .clicked : .failed
        }
    }

    /// 通过辅助功能 API 对状态项执行语义按压（AXPress）。
    /// 不做坐标命中，不受菜单栏布局细节影响，比合成鼠标事件可靠；
    /// 找不到对应元素或元素不支持按压时返回 false，由调用方走 CGEvent 兜底。
    private func pressViaAccessibility(_ item: MenuBarItemDescriptor) -> Bool {
        for element in AccessibilityQuery.extrasMenuBarChildren(ofPID: item.ownerPID) {
            guard let position = AccessibilityQuery.point(element) else { continue }
            // AX 与 CGWindow 共用左上原点的全局坐标系，状态项元素与其窗口原点重合。
            if abs(position.x - item.frame.origin.x) <= 8, abs(position.y - item.frame.origin.y) <= 8 {
                return AccessibilityQuery.performPress(element)
            }
        }
        return false
    }

    private func postClick(to item: MenuBarItemDescriptor) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        guard
            let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
            let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        else {
            return false
        }
        // 状态项的命中测试由 WindowServer 完成，必须走 session tap，
        // postToPid 会绕过命中测试导致点击落在无效位置。
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        return true
    }
}
