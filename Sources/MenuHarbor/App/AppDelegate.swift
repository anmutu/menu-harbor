import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var model: AppModel?
    private var shelfPanel: ShelfPanel?
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

        controller.onPrimaryAction = { [weak self, weak model, weak shelf, weak controller] in
            guard let self, let model, let shelf, let controller else { return }
            shelf.toggle(relativeTo: controller.mainButton)
            if shelf.isVisible { model.refreshShelf() }
            self.dismissOnboardingIfNeeded()
        }
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        controller.onQuit = { NSApp.terminate(nil) }

        let shortcut = GlobalShortcut { [weak model] in model?.toggleFold() }
        shortcut.setEnabled(model.preferences.shortcutEnabled)
        model.onShortcutPreferenceChanged = { [weak shortcut] enabled in shortcut?.setEnabled(enabled) }

        menuBarController = controller
        self.model = model
        shelfPanel = shelf
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
