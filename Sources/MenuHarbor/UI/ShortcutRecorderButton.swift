import AppKit
import Carbon.HIToolbox
import SwiftUI

/// 快捷键录制按钮：点击进入录制态，捕获下一个带修饰键的按键组合。
/// Escape 取消；无修饰键的按键被忽略（防止劫持普通输入）。
struct ShortcutRecorderButton: View {
    let display: String
    let onCapture: (_ keyCode: Int, _ modifiers: Int, _ displayText: String) -> Void

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording.toggle()
        } label: {
            Text(recording ? "按下新组合…" : display)
                .monospacedDigit()
                .frame(minWidth: 68)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(recording ? .teal : nil)
        .onChange(of: recording) { _, active in
            if active {
                startListening()
            } else {
                stopListening()
            }
        }
        .onDisappear { stopListening() }
    }

    private func startListening() {
        stopListening()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async { recording = false }
                return nil
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let carbonModifiers = Self.carbonModifiers(from: flags)
            let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard carbonModifiers != 0, !characters.isEmpty else {
                return event
            }
            let text = Self.displayText(flags: flags, characters: characters)
            DispatchQueue.main.async {
                onCapture(Int(event.keyCode), carbonModifiers, text)
                recording = false
            }
            return nil
        }
    }

    private func stopListening() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var modifiers = 0
        if flags.contains(.control) { modifiers |= controlKey }
        if flags.contains(.option) { modifiers |= optionKey }
        if flags.contains(.shift) { modifiers |= shiftKey }
        if flags.contains(.command) { modifiers |= cmdKey }
        return modifiers
    }

    private static func displayText(flags: NSEvent.ModifierFlags, characters: String) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + characters.uppercased()
    }
}
