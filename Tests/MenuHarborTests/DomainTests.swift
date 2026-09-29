import CoreGraphics
import XCTest

@testable import MenuHarbor

final class DomainTests: XCTestCase {
    private func item(
        _ name: String,
        id: UInt32,
        x: CGFloat,
        owner: String = "Example",
        isOnScreen: Bool = true
    ) -> MenuBarItemDescriptor {
        MenuBarItemDescriptor(
            windowID: id,
            ownerPID: 42,
            ownerName: owner,
            name: name,
            frame: CGRect(x: x, y: 0, width: 24, height: 24),
            isOnScreen: isOnScreen
        )
    }

    func testDefaultsFavorCalmRecoverableBehavior() {
        let value = HarborPreferences.defaults

        XCTAssertEqual(value.autoHideDelay, 10)
        XCTAssertTrue(value.shortcutEnabled)
        XCTAssertEqual(value.iconStyle, .harbor)
        XCTAssertFalse(value.launchAtLogin)
        XCTAssertTrue(value.hoverOpensShelf)
        XCTAssertFalse(value.scrollTogglesMenuBar)
        XCTAssertEqual(value.shortcutKeyCode, HarborPreferences.defaultShortcutKeyCode)
        XCTAssertEqual(value.shortcutModifiers, HarborPreferences.defaultShortcutModifiers)
        XCTAssertEqual(value.shortcutDisplay, "⌃⌥H")
        XCTAssertNil(value.foldSupported)
        XCTAssertFalse(value.hasCompletedOnboarding)
        XCTAssertFalse(value.usesCollectOnlyMode)
    }

    func testCollectOnlyModeActivatesWhenFoldKnownUnsupported() {
        var preferences = HarborPreferences.defaults
        XCTAssertFalse(preferences.usesCollectOnlyMode)

        preferences.foldSupported = true
        XCTAssertFalse(preferences.usesCollectOnlyMode)

        preferences.foldSupported = nil
        XCTAssertFalse(preferences.usesCollectOnlyMode)

        preferences.foldSupported = false
        XCTAssertTrue(preferences.usesCollectOnlyMode)
    }

    func testCollectModeItemsExcludeOwnWindowsAndOffAnchorScreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1_440, height: 900)]
        let items = [
            item("Clock", id: 1, x: 900),
            item("Main Button", id: 2, x: 977),
            item("Divider", id: 3, x: 909),
            item("External Copy", id: 4, x: 2_200),
            item("VPN", id: 5, x: 1_100),
        ]

        let collected = ShelfPresentation.collectModeItems(
            in: items,
            excludedWindowIDs: [2, 3],
            screenFrame: screens[0]
        )

        // 外接屏副本（x=2200 超出锚定屏）与自身状态项被排除，保持从右到左。
        XCTAssertEqual(collected.map(\.name), ["VPN", "Clock"])
    }

    func testCollectModeItemsExcludesOffscreenWindowsEvenWhenGeometryMatches() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let items = [
            item("Current Space", id: 1, x: 900),
            item("Other Space", id: 2, x: 860, isOnScreen: false)
        ]

        let collected = ShelfPresentation.collectModeItems(
            in: items,
            excludedWindowIDs: [],
            screenFrame: screen
        )

        XCTAssertEqual(collected.map(\.name), ["Current Space"])
    }

    func testCollectModeItemsRescuesOffscreenWindowOverlappingNotch() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let notch = CGRect(x: 1_000, y: 0, width: 120, height: 24)
        let items = [
            item("Under notch", id: 1, x: 1_008, isOnScreen: false),
            item("Other Space", id: 2, x: 860, isOnScreen: false)
        ]

        let collected = ShelfPresentation.collectModeItems(
            in: items,
            excludedWindowIDs: [],
            screenFrame: screen,
            rescueFrame: notch
        )

        XCTAssertEqual(collected.map(\.name), ["Under notch"])
    }

    func testCollectModeItemsExcludesLargeStatusOverlaysOutsideMenuBarBand() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let menuItem = MenuBarItemDescriptor(
            windowID: 1,
            ownerPID: 42,
            ownerName: "Control Center",
            name: "WiFi",
            frame: CGRect(x: 1_200, y: 0, width: 38, height: 33),
            isOnScreen: true
        )
        let overlay = MenuBarItemDescriptor(
            windowID: 2,
            ownerPID: 43,
            ownerName: "LinkedNotesUIService",
            name: "Window",
            frame: CGRect(x: 1_000, y: 700, width: 254, height: 254),
            isOnScreen: true
        )

        let collected = ShelfPresentation.collectModeItems(
            in: [menuItem, overlay],
            excludedWindowIDs: [],
            screenFrame: screen
        )

        XCTAssertEqual(collected.map(\.name), ["WiFi"])
    }

    func testCollectModeMarksItemsIntersectingNotchAsAtRisk() {
        let items = [
            item("Safe", id: 1, x: 900),
            item("Under notch", id: 2, x: 1_000)
        ]
        let notch = CGRect(x: 1_000, y: 0, width: 120, height: 24)

        XCTAssertEqual(
            ShelfPresentation.atRiskWindowIDs(in: items, notchFrame: notch),
            [2]
        )
    }

    func testFoldReliabilityRequiresEveryHiddenItemOffscreen() {
        let screens = [CGRect(x: 0, y: 0, width: 1_440, height: 900)]
        let offscreen = item("VPN", id: 1, x: -9_500)
        let onscreen = item("VPN", id: 2, x: 640)

        XCTAssertTrue(FoldReliabilityPolicy.isFoldEffective(items: [], screenFrames: screens))
        XCTAssertTrue(FoldReliabilityPolicy.isFoldEffective(items: [offscreen], screenFrames: screens))
        XCTAssertFalse(FoldReliabilityPolicy.isFoldEffective(items: [offscreen, onscreen], screenFrames: screens))
    }

    func testFoldHealthUsesMultipleProbeAttemptsBeforeDegrading() {
        XCTAssertEqual(FoldReliabilityPolicy.healthProbeAttempts, 3)
    }

    func testCapabilityDegradesWithoutPermissions() {
        XCTAssertEqual(HarborCapability.resolve(screenCapture: false, accessibility: false), .foldOnly)
        XCTAssertEqual(HarborCapability.resolve(screenCapture: true, accessibility: false), .browsable)
        XCTAssertEqual(HarborCapability.resolve(screenCapture: true, accessibility: true), .interactive)
    }

    func testFoldStateTogglesAndRestoreAlwaysExpands() {
        var state = FoldState.folded

        state.toggle()
        XCTAssertEqual(state, .expanded)

        state.restore()
        XCTAssertEqual(state, .expanded)
    }

    func testPartitionUsesDividerAndKeepsRightToLeftOrder() {
        let items = [
            item("Clock", id: 1, x: 900),
            item("Divider", id: 2, x: 700),
            item("VPN", id: 3, x: 650),
            item("Sync", id: 4, x: 610),
        ]
        let screens = [CGRect(x: 0, y: 0, width: 1_440, height: 900)]

        let partition = ItemPartitioner.partition(
            in: items,
            hiddenDividerWindowID: 2,
            alwaysHiddenDividerWindowID: nil,
            screenFrames: screens
        )
        XCTAssertEqual(partition.hidden.map(\.name), ["VPN", "Sync"])
        XCTAssertTrue(partition.alwaysHidden.isEmpty)
    }

    func testPartitionReturnsNothingWhenDividerIsMissing() {
        let screens = [CGRect(x: 0, y: 0, width: 1_440, height: 900)]
        let items = [item("VPN", id: 3, x: 650)]

        let partition = ItemPartitioner.partition(
            in: items,
            hiddenDividerWindowID: 99,
            alwaysHiddenDividerWindowID: nil,
            screenFrames: screens
        )
        XCTAssertTrue(partition.hidden.isEmpty)
        XCTAssertTrue(partition.alwaysHidden.isEmpty)
    }

    func testPartitionSplitsAlwaysHiddenZoneBySecondDivider() {
        // 布局（右→左）：可见 | 隐藏分隔(500) | 隐藏项(300) | 始终隐藏分隔(200) | 始终隐藏项(100)
        let items = [
            item("Visible", id: 1, x: 900),
            item("Hidden Divider", id: 2, x: 500),
            item("VPN", id: 3, x: 300),
            item("AlwaysHidden Divider", id: 4, x: 200),
            item("License Icon", id: 5, x: 100),
        ]
        let screens = [CGRect(x: 0, y: 0, width: 1_440, height: 900)]

        let partition = ItemPartitioner.partition(
            in: items,
            hiddenDividerWindowID: 2,
            alwaysHiddenDividerWindowID: 4,
            screenFrames: screens
        )
        XCTAssertEqual(partition.hidden.map(\.name), ["VPN", "License Icon"])
        XCTAssertEqual(partition.alwaysHidden.map(\.name), ["License Icon"])
    }

    func testPartitionExcludesItemsOnExternalScreenLeftOfMainDisplay() {
        // 外接屏排列在主屏左侧：它的菜单栏项 x 更小，
        // 不能因为"在 divider 左边"就被误判成隐藏项。
        let mainScreen = CGRect(x: 1_440, y: 0, width: 1_440, height: 900)
        let externalScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let items = [
            item("Main VPN", id: 1, x: 1_500),
            item("Divider", id: 2, x: 1_600),
            item("External Icon", id: 3, x: 60),
        ]

        let partition = ItemPartitioner.partition(
            in: items,
            hiddenDividerWindowID: 2,
            alwaysHiddenDividerWindowID: nil,
            screenFrames: [externalScreen, mainScreen]
        )
        XCTAssertEqual(partition.hidden.map(\.name), ["Main VPN"])
    }

    func testPartitionKeepsFoldedItemsPushedOffscreen() {
        // 折叠时隐藏项被推出屏幕左侧，不在任何屏幕内，必须保留。
        let mainScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let items = [
            item("Divider", id: 2, x: -9_300),
            item("VPN", id: 3, x: -9_500),
            item("Sync", id: 4, x: -9_560),
            item("Battery", id: 5, x: 900),
        ]

        let partition = ItemPartitioner.partition(
            in: items,
            hiddenDividerWindowID: 2,
            alwaysHiddenDividerWindowID: nil,
            screenFrames: [mainScreen]
        )
        XCTAssertEqual(partition.hidden.map(\.name), ["VPN", "Sync"])
    }

    func testSearchMatchesNameAndOwnerIgnoringCase() {
        let descriptor = item("Secure Tunnel", id: 1, x: 100, owner: "Acme VPN")

        XCTAssertEqual(ItemSearch.filter([descriptor], query: "vpn"), [descriptor])
        XCTAssertEqual(ItemSearch.filter([descriptor], query: "TUNNEL"), [descriptor])
        XCTAssertEqual(ItemSearch.filter([descriptor], query: "   "), [descriptor])
        XCTAssertTrue(ItemSearch.filter([descriptor], query: "calendar").isEmpty)
    }

    func testSearchFallsBackToFuzzySubsequenceWhenNoDirectHit() {
        let wifi = item("WiFi", id: 1, x: 100, owner: "Control Center")
        let battery = item("Battery", id: 2, x: 140, owner: "Control Center")

        // 无子串命中时按字符顺序模糊匹配："wfi" → WiFi，"bty" → Battery
        XCTAssertEqual(ItemSearch.filter([wifi, battery], query: "wfi"), [wifi])
        XCTAssertEqual(ItemSearch.filter([wifi, battery], query: "bty"), [battery])
        // 子串命中存在时不进入模糊分支："at" 子串命中 Battery，不返回 WiFi
        XCTAssertEqual(ItemSearch.filter([wifi, battery], query: "at"), [battery])
        // 顺序不符不命中："wf" 可以，"fw" 不行
        XCTAssertTrue(ItemSearch.filter([wifi], query: "fw").isEmpty)
    }

    func testSelectingItemWithoutAccessibilityRequestsNativeExpansion() {
        XCTAssertEqual(
            ItemActivationPlan.make(itemExists: true, accessibility: false),
            .expandForManualClick
        )
    }

    func testSelectingItemWithAccessibilityClicksOriginalItem() {
        XCTAssertEqual(
            ItemActivationPlan.make(itemExists: true, accessibility: true),
            .click
        )
    }

    func testMissingItemRequestsRefresh() {
        XCTAssertEqual(
            ItemActivationPlan.make(itemExists: false, accessibility: true),
            .refresh
        )
    }

    func testCoordinateClickRequiresAnOnScreenTarget() {
        XCTAssertTrue(ItemActivationPolicy.canUseCoordinateClick(isOnScreen: true))
        XCTAssertFalse(ItemActivationPolicy.canUseCoordinateClick(isOnScreen: false))
    }

    func testShelfPresentationFiltersAndExplainsFoldOnlyMode() {
        let fixtures = [item("Secure Tunnel", id: 1, x: 100, owner: "Acme VPN")]

        XCTAssertEqual(ShelfPresentation.filtered(items: fixtures, query: "vpn"), fixtures)
        XCTAssertEqual(
            ShelfPresentation.permissionMessage(for: .foldOnly),
            "开启屏幕录制，显示真实图标；再开启辅助功能即可直接点击"
        )
        XCTAssertEqual(
            ShelfPresentation.permissionMessage(for: .browsable),
            "开启辅助功能，即可直接在港湾里点击图标"
        )
        XCTAssertEqual(ShelfPresentation.missingPermission(for: .foldOnly), .screenCapture)
        XCTAssertEqual(ShelfPresentation.missingPermission(for: .browsable), .accessibility)
        XCTAssertNil(ShelfPresentation.missingPermission(for: .interactive))
    }

    func testAutoHideDefersWhileShelfIsOpenOrUserIsRearranging() {
        XCTAssertFalse(AutoHidePolicy.shouldDefer(isShelfPresented: false, isCommandKeyDown: false))
        XCTAssertTrue(AutoHidePolicy.shouldDefer(isShelfPresented: true, isCommandKeyDown: false))
        XCTAssertTrue(AutoHidePolicy.shouldDefer(isShelfPresented: false, isCommandKeyDown: true))
        XCTAssertTrue(AutoHidePolicy.shouldDefer(isShelfPresented: true, isCommandKeyDown: true))
    }
}
