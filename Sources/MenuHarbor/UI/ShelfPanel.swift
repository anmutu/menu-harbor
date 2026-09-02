import AppKit
import SwiftUI

@MainActor
final class ShelfPanel: NSPanel {
    private let model: AppModel

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

    func show(relativeTo anchor: NSStatusBarButton?) {
        model.refreshShelf()
        model.isShelfPresented = true

        let targetScreen = anchor?.window?.screen ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen = targetScreen else { return }

        let safeFrame = screen.visibleFrame
        let anchorFrame = anchor?.window?.frame ?? NSRect(x: safeFrame.midX, y: safeFrame.maxY, width: 1, height: 1)
        let width = min(max(440, CGFloat(model.items.count) * 68 + 80), min(640, safeFrame.width - 24))
        let height: CGFloat = model.items.isEmpty ? 230 : 248
        let x = min(max(anchorFrame.midX - width / 2, safeFrame.minX + 12), safeFrame.maxX - width - 12)
        let y = safeFrame.maxY - height - 8

        setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        alphaValue = 0
        orderFrontRegardless()
        makeKey()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            animator().alphaValue = 1
        }
    }

    override func close() {
        model.isShelfPresented = false
        super.close()
    }
}

