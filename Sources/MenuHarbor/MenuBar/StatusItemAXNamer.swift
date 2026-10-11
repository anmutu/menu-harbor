import AppKit
import ApplicationServices

/// 用辅助功能读取状态项的可读名称。
/// macOS 26 上所有状态项窗口的 owner 都变成 Control Center、窗口名
/// 多为 "Item-0"，只有 AX 的 description/title 才是用户认识的名字
/// （如 "WiFi"、"飞书"）。有辅助功能权限时港湾以此命名，支持搜索。
@MainActor
final class StatusItemAXNamer {
    /// 返回 windowID → 可读名称；读不到的条目不出现在结果里。
    func resolveNames(for items: [MenuBarItemDescriptor]) -> [UInt32: String] {
        var result: [UInt32: String] = [:]
        guard !items.isEmpty else { return result }

        for (pid, group) in Dictionary(grouping: items, by: \.ownerPID) {
            // 位置是 AX 跨进程往返的主要开销，同一进程的元素只读一次，
            // 不再为组内每个条目重复读取全部元素。
            let positionedElements: [(element: AXUIElement, position: CGPoint)] =
                AccessibilityQuery.extrasMenuBarChildren(ofPID: pid)
                    .compactMap { element in
                        guard let position = AccessibilityQuery.point(element) else { return nil }
                        return (element, position)
                    }
            guard !positionedElements.isEmpty else { continue }

            for item in group {
                for positioned in positionedElements
                where abs(positioned.position.x - item.frame.origin.x) <= 8
                    && abs(positioned.position.y - item.frame.origin.y) <= 8 {
                    let name = AccessibilityQuery.string(positioned.element, attribute: kAXDescriptionAttribute)
                        ?? AccessibilityQuery.string(positioned.element, attribute: kAXTitleAttribute)
                    if let name, !name.isEmpty {
                        result[item.windowID] = name
                    }
                    break
                }
            }
        }
        return result
    }
}
