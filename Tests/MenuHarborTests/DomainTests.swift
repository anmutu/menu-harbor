import CoreGraphics
import XCTest

@testable import MenuHarbor

final class DomainTests: XCTestCase {
    private func item(
        _ name: String,
        id: UInt32,
        x: CGFloat,
        owner: String = "Example"
    ) -> MenuBarItemDescriptor {
        MenuBarItemDescriptor(
            windowID: id,
            ownerPID: 42,
            ownerName: owner,
            name: name,
            frame: CGRect(x: x, y: 0, width: 24, height: 24),
            isOnScreen: true
        )
    }

    func testDefaultsFavorCalmRecoverableBehavior() {
        let value = HarborPreferences.defaults

        XCTAssertEqual(value.autoHideDelay, 10)
        XCTAssertTrue(value.shortcutEnabled)
        XCTAssertEqual(value.iconStyle, .harbor)
        XCTAssertFalse(value.launchAtLogin)
        XCTAssertFalse(value.hasCompletedOnboarding)
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

        XCTAssertEqual(
            ItemPartitioner.hiddenItems(in: items, dividerWindowID: 2).map(\.name),
            ["VPN", "Sync"]
        )
    }

    func testPartitionReturnsNothingWhenDividerIsMissing() {
        let items = [item("VPN", id: 3, x: 650)]

        XCTAssertTrue(ItemPartitioner.hiddenItems(in: items, dividerWindowID: 99).isEmpty)
    }

    func testSearchMatchesNameAndOwnerIgnoringCase() {
        let descriptor = item("Secure Tunnel", id: 1, x: 100, owner: "Acme VPN")

        XCTAssertEqual(ItemSearch.filter([descriptor], query: "vpn"), [descriptor])
        XCTAssertEqual(ItemSearch.filter([descriptor], query: "TUNNEL"), [descriptor])
        XCTAssertEqual(ItemSearch.filter([descriptor], query: "   "), [descriptor])
        XCTAssertTrue(ItemSearch.filter([descriptor], query: "calendar").isEmpty)
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
}
