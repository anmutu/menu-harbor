import AppKit
import Combine
import SwiftUI

/// 刘海屏上的固定入口：不替代菜单栏主按钮，只为“主按钮被挤掉”的场景
/// 提供一个可见、低干扰、无需额外权限的第二入口。
@MainActor
final class NotchLauncherPanel: NSPanel {
    private let model: AppModel
    private let menuBar: MenuBarController
    private let openShelf: () -> Void
    private var screenChangeObserver: NSObjectProtocol?
    private var preferenceCancellable: AnyCancellable?
    private var shelfCancellable: AnyCancellable?

    init(model: AppModel, menuBar: MenuBarController, openShelf: @escaping () -> Void) {
        self.model = model
        self.menuBar = menuBar
        self.openShelf = openShelf
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: NotchLauncherLayout.defaultSize.width, height: NotchLauncherLayout.defaultSize.height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "MenuHarbor 港湾入口"
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = NSHostingView(rootView: NotchLauncherView(model: model, openShelf: openShelf))

        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.syncVisibility() }
        }

        preferenceCancellable = model.$preferences
            .map(\.notchLauncherEnabled)
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncVisibility() }

        shelfCancellable = model.$isShelfPresented
            .removeDuplicates()
            .sink { [weak self] _ in self?.syncVisibility() }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func syncVisibility() {
        guard
            model.preferences.notchLauncherEnabled,
            !model.isShelfPresented,
            let screen = targetScreen,
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea,
            NotchLauncherLayout.hasNotch(leftArea: left, rightArea: right)
        else {
            orderOut(nil)
            return
        }

        // 全屏 Space 没有可用的菜单栏条带，不在应用内容上方强行留一个浮层。
        let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
        guard menuBarHeight > 1 else {
            orderOut(nil)
            return
        }

        let notchHeight = max(24, screen.safeAreaInsets.top)
        let notchFrame = CGRect(
            x: left.maxX,
            y: screen.frame.maxY - notchHeight,
            width: right.minX - left.maxX,
            height: notchHeight
        )
        let launcherFrame = NotchLauncherLayout.frame(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            notchFrame: notchFrame
        )

        setFrame(launcherFrame, display: true)
        orderFrontRegardless()
    }

    private var targetScreen: NSScreen? {
        menuBar.mainButton?.window?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
    }
}

private struct NotchLauncherView: View {
    @ObservedObject var model: AppModel
    let openShelf: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: openShelf) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.bottomhalf.inset.filled")
                    .font(.system(size: 12, weight: .semibold))
                Text("港湾")
                    .font(.system(size: 11, weight: .semibold))
                if !model.atRiskItemIDs.isEmpty {
                    Text("\(model.atRiskItemIDs.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: NotchLauncherLayout.defaultSize.width, height: NotchLauncherLayout.defaultSize.height)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isHovered ? Color.teal.opacity(0.8) : Color.primary.opacity(0.18),
                    lineWidth: isHovered ? 1 : 0.5
                )
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .buttonStyle(NotchLauncherButtonStyle())
        .onHover { isHovered = $0 }
        .help("打开 MenuHarbor 港湾")
        .accessibilityLabel("打开 MenuHarbor 港湾")
        .accessibilityHint("查看、搜索并操作当前屏幕的菜单栏图标")
        .accessibilityValue(
            model.atRiskItemIDs.isEmpty
                ? "打开港湾"
                : String(model.atRiskItemIDs.count) + " 个图标可能被刘海挡住"
        )
    }
}

private struct NotchLauncherButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
