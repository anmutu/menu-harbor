import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import ServiceManagement
import ScreenCaptureKit

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var hasScreenCapturePermission = false
    @Published private(set) var hasAccessibilityPermission = false

    init() {
        refresh()
    }

    var capability: HarborCapability {
        HarborCapability.resolve(
            screenCapture: hasScreenCapturePermission,
            accessibility: hasAccessibilityPermission
        )
    }

    func refresh() {
        hasScreenCapturePermission = CGPreflightScreenCaptureAccess()
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestScreenCapture() {
        if #available(macOS 15.0, *) {
            Task {
                _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                refresh()
            }
        } else {
            CGRequestScreenCaptureAccess()
            scheduleRefresh()
        }
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        scheduleRefresh()
    }

    func openScreenCaptureSettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    func openAccessibilitySettings() {
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openSettings(_ value: String) {
        guard let url = URL(string: value) else { return }
        NSWorkspace.shared.open(url)
    }

    private func scheduleRefresh() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self?.refresh()
        }
    }
}

@MainActor
final class LaunchAtLoginController {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled, SMAppService.mainApp.status != .enabled {
            try SMAppService.mainApp.register()
        } else if !enabled, SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class GlobalShortcut {
    private static var callback: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        Self.callback = action
        installHandler()
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? register() : unregister()
    }

    private func installHandler() {
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                Task { @MainActor in GlobalShortcut.callback?() }
                return noErr
            },
            1,
            &specification,
            nil,
            &eventHandler
        )
    }

    private func register() {
        guard hotKey == nil else { return }
        let identifier = EventHotKeyID(signature: OSType(0x4D_48_42_52), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(controlKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    private func unregister() {
        guard let hotKey else { return }
        UnregisterEventHotKey(hotKey)
        self.hotKey = nil
    }
}
