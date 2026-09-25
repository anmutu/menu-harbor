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
    private let action: () -> Void
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var keyCode: UInt32
    private var modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        self.keyCode = keyCode
        self.modifiers = modifiers
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

    /// 用户录制了新组合时更新注册；仅在当前已注册（即开关打开）时重挂。
    func updateCombination(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        guard hotKey != nil else { return }
        unregister()
        register()
    }

    private func installHandler() {
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
                // Carbon 回调线程不受我们控制，必须安全 hop 到 MainActor，
                // 不能用 assumeIsolated（非主线程时直接 trap）。
                Task { @MainActor in
                    shortcut.fire()
                }
                return noErr
            },
            1,
            &specification,
            context,
            &eventHandler
        )
    }

    private func fire() {
        action()
    }

    private func register() {
        guard hotKey == nil else { return }
        let identifier = EventHotKeyID(signature: OSType(0x4D_48_42_52), id: 1)
        RegisterEventHotKey(
            keyCode,
            modifiers,
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
