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
        expected.hoverOpensShelf = true
        expected.notchLauncherEnabled = false
        expected.hoverZoneWide = true
        expected.scrollTogglesMenuBar = true
        expected.shortcutKeyCode = 11
        expected.shortcutModifiers = 4_608
        expected.shortcutDisplay = "⌃⌥B"
        expected.foldSupported = false

        store.save(expected)

        // 覆盖全部字段：将来新增字段若没进 CodingKeys，会在这里静默丢失。
        XCTAssertEqual(store.load(), expected)
    }

    func testCorruptPreferencesFallBackToDefaults() {
        defaults.set(Data("bad".utf8), forKey: PreferencesStore.storageKey)

        XCTAssertEqual(store.load(), .defaults)
    }

    func testLegacyPreferencesKeepExistingValuesWhenNewFieldsAreMissing() throws {
        let legacyJSON = """
        {"autoHideDelay":30,"shortcutEnabled":false,"iconStyle":"dot","launchAtLogin":true,"hasCompletedOnboarding":true}
        """
        defaults.set(Data(legacyJSON.utf8), forKey: PreferencesStore.storageKey)

        let loaded = store.load()
        XCTAssertEqual(loaded.autoHideDelay, 30)
        XCTAssertFalse(loaded.shortcutEnabled)
        XCTAssertEqual(loaded.iconStyle, .dot)
        XCTAssertTrue(loaded.launchAtLogin)
        XCTAssertFalse(loaded.hoverOpensShelf)
        XCTAssertTrue(loaded.notchLauncherEnabled)
        XCTAssertEqual(loaded.shortcutKeyCode, HarborPreferences.defaultShortcutKeyCode)
        XCTAssertEqual(loaded.shortcutModifiers, HarborPreferences.defaultShortcutModifiers)
        XCTAssertEqual(loaded.shortcutDisplay, "⌃⌥H")
        XCTAssertNil(loaded.foldSupported)
        XCTAssertTrue(loaded.hasCompletedOnboarding)
    }
}

