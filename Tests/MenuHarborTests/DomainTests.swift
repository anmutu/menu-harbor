import CoreGraphics
import XCTest

@testable import MenuHarbor

final class DomainTests: XCTestCase {
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
}

