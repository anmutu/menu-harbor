import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var model: AppModel?
    private var shelfPanel: ShelfPanel?
    private var hoverController: HoverShelfController?
    private var scrollController: MenuBarScrollController?
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var shortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController()
        let permissions = PermissionManager()
        let scanner = MenuBarScanner()
        let interactor = MenuBarInteractor(controller: controller, scanner: scanner, permissions: permissions)
        let model = AppModel(
            store: PreferencesStore(),
            menuBar: controller,
            scanner: scanner,
            interactor: interactor,
            permissions: permissions,
            launchAtLogin: LaunchAtLoginController()
        )
        let shelf = ShelfPanel(model: model)
        let hover = HoverShelfController(model: model, menuBar: controller, shelf: shelf)
        let scroll = MenuBarScrollController(model: model)

        let openShelf = { [weak self, weak shelf, weak controller] in
            guard let self, let shelf, let controller else { return }
            shelf.toggle(relativeTo: controller.mainButton)
            self.dismissOnboardingIfNeeded()
        }
        controller.onPrimaryAction = openShelf
        model.onPrimaryShortcut = openShelf
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.onRestoreAll = { [weak model] in model?.restore() }
        controller.onQuit = { NSApp.terminate(nil) }

        let shortcut = GlobalShortcut(
            keyCode: UInt32(model.preferences.shortcutKeyCode),
            modifiers: UInt32(model.preferences.shortcutModifiers)
        ) { [weak model] in model?.performPrimaryShortcut() }
        if model.preferences.shortcutEnabled, !shortcut.setEnabled(true) {
            model.reportShortcutConflict()
        }
        model.onShortcutPreferenceChanged = { [weak shortcut, weak model] enabled in
            guard let shortcut else { return }
            if enabled, !shortcut.setEnabled(true) {
                model?.reportShortcutConflict()
            }
        }
        model.onShortcutCombinationChanged = { [weak shortcut, weak model] code, modifiers in
            guard let shortcut else { return }
            if !shortcut.updateCombination(keyCode: UInt32(code), modifiers: UInt32(modifiers)) {
                model?.reportShortcutConflict()
            }
        }

        hover.setEnabled(model.preferences.hoverOpensShelf)
        model.onHoverPreferenceChanged = { [weak hover] enabled in hover?.setEnabled(enabled) }

        scroll.setEnabled(model.preferences.scrollTogglesMenuBar)
        model.onScrollPreferenceChanged = { [weak scroll] enabled in scroll?.setEnabled(enabled) }

        menuBarController = controller
        self.model = model
        shelfPanel = shelf
        hoverController = hover
        scrollController = scroll
        self.shortcut = shortcut

        if !model.preferences.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in self?.showOnboarding() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.restore()
    }

    private func showSettings() {
        guard let model else { return }
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MenuHarbor 设置"
        window.isReleasedWhenClosed = false
        // 应用是 accessory 且常驻所有 Space，设置窗口必须跟随，
        // 否则用户在全屏应用所在 Space 里打不开设置。
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model, openOnboarding: { [weak self] in self?.showOnboarding() }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func showOnboarding() {
        guard let model else { return }
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 410),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MenuHarbor"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentViewController = NSHostingController(rootView: OnboardingView(model: model, finish: { [weak self] in self?.closeOnboarding() }))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    private func dismissOnboardingIfNeeded() {
        if model?.preferences.hasCompletedOnboarding == false {
            showOnboarding()
        }
    }
}
