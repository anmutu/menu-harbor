import AppKit
import ApplicationServices

/// 辅助功能查询的共享封装：代点击的定位和图标命名共用同一套读取逻辑。
enum AccessibilityQuery {
    /// 读取目标进程"菜单栏附加区"（状态项区域）的全部元素。
    static func extrasMenuBarChildren(ofPID pid: Int32) -> [AXUIElement] {
        let application = AXUIElementCreateApplication(pid)
        var extrasRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(application, kAXExtrasMenuBarAttribute as CFString, &extrasRef) == .success,
            let extrasRef,
            CFGetTypeID(extrasRef) == AXUIElementGetTypeID()
        else {
            return []
        }
        let extras = unsafeBitCast(extrasRef, to: AXUIElement.self)

        var childrenRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(extras, kAXChildrenAttribute as CFString, &childrenRef) == .success,
            let children = childrenRef as? [AXUIElement]
        else {
            return []
        }
        return children
    }

    /// 元素左上角的全局坐标（左上原点，与 CGWindow 坐标一致）。
    static func point(_ element: AXUIElement) -> CGPoint? {
        guard let value = copy(element, attribute: kAXPositionAttribute) else { return nil }
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        let axValue = unsafeBitCast(value, to: AXValue.self)
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func string(_ element: AXUIElement, attribute: String) -> String? {
        copy(element, attribute: attribute) as? String
    }

    static func performPress(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    private static func copy(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var valueRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success
        else {
            return nil
        }
        return valueRef
    }
}
