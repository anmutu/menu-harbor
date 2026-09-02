import Foundation
import XCTest

@testable import MenuHarbor

final class PreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: PreferencesStore!

    override func setUp() {
        super.setUp()
        let suiteName = "MenuHarborTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = PreferencesStore(defaults: defaults)
    }

    func testMissingPreferencesReturnDefaults() {
        XCTAssertEqual(store.load(), .defaults)
    }

    func testPreferencesRoundTrip() {
        var expected = HarborPreferences.defaults
        expected.autoHideDelay = 30
        expected.iconStyle = .dot
        expected.hasCompletedOnboarding = true

        store.save(expected)

        XCTAssertEqual(store.load(), expected)
    }

    func testCorruptPreferencesFallBackToDefaults() {
        defaults.set(Data("bad".utf8), forKey: PreferencesStore.storageKey)

        XCTAssertEqual(store.load(), .defaults)
    }
}

