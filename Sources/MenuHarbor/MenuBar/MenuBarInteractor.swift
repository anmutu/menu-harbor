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

    func activate(_ item: MenuBarItemDescriptor) async -> Result {
        let plan = ItemActivationPlan.make(
            itemExists: scanner.descriptor(windowID: item.windowID) != nil,
            accessibility: permissions.hasAccessibilityPermission
        )

        switch plan {
        case .refresh:
            return .missing
        case .expandForManualClick:
            controller.expand()
            return .expandedForManualClick
        case .click:
            controller.expand()
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let current = scanner.descriptor(windowID: item.windowID) else { return .missing }
            return postClick(to: current) ? .clicked : .failed
        }
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
        down.postToPid(item.ownerPID)
        up.postToPid(item.ownerPID)
        return true
    }
}

