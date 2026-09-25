import AppKit
import CoreGraphics

protocol MenuBarScanning: AnyObject {
    func scan() -> [MenuBarItemDescriptor]
    func descriptor(windowID: UInt32) -> MenuBarItemDescriptor?
    func snapshot(windowID: UInt32, size: CGSize) -> NSImage?
}

final class MenuBarScanner: MenuBarScanning {
    func scan() -> [MenuBarItemDescriptor] {
        guard let rawWindows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] else {
            return []
        }

        return rawWindows
            .compactMap(Self.makeDescriptor)
            .filter { $0.frame.width > 0 && $0.frame.height > 0 }
            .sorted { lhs, rhs in
                if lhs.frame.minX == rhs.frame.minX {
                    return lhs.windowID < rhs.windowID
                }
                return lhs.frame.minX > rhs.frame.minX
            }
    }

    func descriptor(windowID: UInt32) -> MenuBarItemDescriptor? {
        scan().first(where: { $0.windowID == windowID })
    }

    func snapshot(windowID: UInt32, size: CGSize) -> NSImage? {
        guard let image = WindowImageCapture.capture(windowID: windowID) else { return nil }
        return NSImage(cgImage: image, size: size)
    }

    private static func makeDescriptor(_ info: [CFString: Any]) -> MenuBarItemDescriptor? {
        guard
            let rawWindowID = info[kCGWindowNumber] as? NSNumber,
            let ownerPID = (info[kCGWindowOwnerPID] as? NSNumber)?.int32Value,
            let ownerName = info[kCGWindowOwnerName] as? String,
            let bounds = info[kCGWindowBounds] as? NSDictionary,
            let frame = CGRect(dictionaryRepresentation: bounds),
            let layer = (info[kCGWindowLayer] as? NSNumber)?.int32Value,
            layer == CGWindowLevelForKey(.statusWindow)
        else {
            return nil
        }

        guard rawWindowID.int64Value > 0, let windowID = UInt32(exactly: rawWindowID.int64Value) else {
            return nil
        }

        let rawName = (info[kCGWindowName] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = rawName.flatMap { $0.isEmpty ? nil : $0 } ?? ownerName
        let isOnScreen = (info[kCGWindowIsOnscreen] as? NSNumber)?.boolValue ?? false

        return MenuBarItemDescriptor(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            name: name,
            frame: frame,
            isOnScreen: isOnScreen
        )
    }
}

private protocol WindowImageCreating {
    init?(
        windowListFromArrayScreenBounds: CGRect,
        windowArray: CFArray,
        imageOption: CGWindowImageOption
    )
}

private extension WindowImageCreating {
    static func makeWindowImage(
        bounds: CGRect,
        windows: CFArray,
        options: CGWindowImageOption
    ) -> Self? {
        Self(
            windowListFromArrayScreenBounds: bounds,
            windowArray: windows,
            imageOption: options
        )
    }
}

extension CGImage: WindowImageCreating {}

private enum WindowImageCapture {
    static func capture(windowID: UInt32) -> CGImage? {
        var rawPointer = UnsafeRawPointer(bitPattern: UInt(windowID))
        guard let array = CFArrayCreate(kCFAllocatorDefault, &rawPointer, 1, nil) else {
            return nil
        }
        return CGImage.makeWindowImage(
            bounds: .null,
            windows: array,
            options: [.boundsIgnoreFraming, .bestResolution]
        )
    }
}
