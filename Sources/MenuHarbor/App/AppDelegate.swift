import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MenuBarController()
        controller.onPrimaryAction = { [weak controller] in
            controller?.toggle()
        }
        controller.onOpenSettings = {
            NSApp.activate(ignoringOtherApps: true)
        }
        controller.onQuit = {
            NSApp.terminate(nil)
        }
        menuBarController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController?.restore()
    }
}

