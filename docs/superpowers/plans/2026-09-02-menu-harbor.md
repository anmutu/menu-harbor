# MenuHarbor MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that folds overflow status items behind a divider and exposes them through a notch-safe, searchable shelf with graceful permission fallback.

**Architecture:** A small pure Swift domain defines preferences, item partitioning, filtering, and capability degradation. AppKit adapters own status items, window discovery, snapshots, clicks, permissions, login, and the floating panel; SwiftUI renders onboarding, shelf, and settings through one observable `AppModel`.

**Tech Stack:** Swift 6.2 toolchain in Swift 5 language mode, SwiftUI, AppKit, CoreGraphics, ApplicationServices, ServiceManagement, Swift Package Manager, XCTest.

---

## File map

- `Package.swift`: executable and test target definition.
- `Info.plist`: menu-bar-only bundle metadata and screen-capture explanation.
- `Makefile`: build, test, bundle, sign, and run commands.
- `Sources/MenuHarbor/Domain/MenuBarDomain.swift`: stable descriptors, preferences, partition/search/capability logic.
- `Sources/MenuHarbor/System/PreferencesStore.swift`: `UserDefaults` persistence.
- `Sources/MenuHarbor/System/SystemServices.swift`: permissions, launch-at-login, and global shortcut adapters.
- `Sources/MenuHarbor/MenuBar/MenuBarScanner.swift`: status-window discovery and icon snapshots.
- `Sources/MenuHarbor/MenuBar/MenuBarController.swift`: control/divider status items and fold state.
- `Sources/MenuHarbor/MenuBar/MenuBarInteractor.swift`: safe native click forwarding with fallback.
- `Sources/MenuHarbor/App/AppModel.swift`: presentation state and use-case orchestration.
- `Sources/MenuHarbor/App/AppDelegate.swift`: process lifecycle and dependency wiring.
- `Sources/MenuHarbor/App/MenuHarborApp.swift`: executable entry point.
- `Sources/MenuHarbor/UI/ShelfPanel.swift`: notch-safe nonactivating panel placement.
- `Sources/MenuHarbor/UI/ShelfView.swift`: searchable icon shelf.
- `Sources/MenuHarbor/UI/SettingsView.swift`: preferences, permission diagnostics, and restore action.
- `Sources/MenuHarbor/UI/OnboardingView.swift`: first-run three-step guide.
- `Tests/MenuHarborTests/DomainTests.swift`: pure behavior tests.
- `Tests/MenuHarborTests/PreferencesStoreTests.swift`: persistence tests.

### Task 1: Project shell and domain defaults

**Files:**
- Create: `Package.swift`
- Create: `Info.plist`
- Create: `Makefile`
- Create: `Sources/MenuHarbor/Domain/MenuBarDomain.swift`
- Create: `Tests/MenuHarborTests/DomainTests.swift`

- [ ] **Step 1: Write failing defaults and capability tests**

```swift
func testDefaultsFavorCalmRecoverableBehavior() {
    let value = HarborPreferences.defaults
    XCTAssertEqual(value.autoHideDelay, 10)
    XCTAssertTrue(value.shortcutEnabled)
    XCTAssertEqual(value.iconStyle, .harbor)
}

func testCapabilityDegradesWithoutPermissions() {
    XCTAssertEqual(HarborCapability.resolve(screenCapture: false, accessibility: false), .foldOnly)
    XCTAssertEqual(HarborCapability.resolve(screenCapture: true, accessibility: false), .browsable)
    XCTAssertEqual(HarborCapability.resolve(screenCapture: true, accessibility: true), .interactive)
}
```

- [ ] **Step 2: Run the tests and confirm RED**

Run: `swift test --filter DomainTests`  
Expected: compile failure because the domain types do not exist.

- [ ] **Step 3: Add the minimum domain implementation**

```swift
enum HarborCapability: Equatable {
    case foldOnly, browsable, interactive
    static func resolve(screenCapture: Bool, accessibility: Bool) -> Self {
        guard screenCapture else { return .foldOnly }
        return accessibility ? .interactive : .browsable
    }
}

struct HarborPreferences: Equatable, Codable {
    enum IconStyle: String, Codable { case harbor, dot }
    var autoHideDelay: TimeInterval
    var shortcutEnabled: Bool
    var iconStyle: IconStyle
    var launchAtLogin: Bool
    var hasCompletedOnboarding: Bool
    static let defaults = Self(autoHideDelay: 10, shortcutEnabled: true, iconStyle: .harbor, launchAtLogin: false, hasCompletedOnboarding: false)
}
```

- [ ] **Step 4: Run tests and confirm GREEN**

Run: `swift test --filter DomainTests`  
Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Info.plist Makefile Sources/MenuHarbor/Domain Tests/MenuHarborTests/DomainTests.swift
git commit -m "feat: establish MenuHarbor domain"
```

### Task 2: Partitioning, search, and preference persistence

**Files:**
- Modify: `Sources/MenuHarbor/Domain/MenuBarDomain.swift`
- Create: `Sources/MenuHarbor/System/PreferencesStore.swift`
- Modify: `Tests/MenuHarborTests/DomainTests.swift`
- Create: `Tests/MenuHarborTests/PreferencesStoreTests.swift`

- [ ] **Step 1: Write failing behavior tests**

```swift
func testPartitionUsesDividerAndKeepsRightToLeftOrder() {
    let items = [item("Clock", x: 900), item("Divider", x: 700, own: true), item("VPN", x: 650), item("Sync", x: 610)]
    XCTAssertEqual(ItemPartitioner.hiddenItems(in: items, dividerWindowID: 2).map(\.name), ["VPN", "Sync"])
}

func testSearchMatchesNameAndOwnerIgnoringCase() {
    let item = MenuBarItemDescriptor(windowID: 1, ownerPID: 2, ownerName: "Acme VPN", name: "Secure Tunnel", frame: .zero, isOnScreen: false)
    XCTAssertEqual(ItemSearch.filter([item], query: "vpn"), [item])
    XCTAssertEqual(ItemSearch.filter([item], query: "TUNNEL"), [item])
}

func testCorruptPreferencesFallBackToDefaults() {
    defaults.set(Data("bad".utf8), forKey: "preferences")
    XCTAssertEqual(store.load(), .defaults)
}
```

- [ ] **Step 2: Run the focused tests and confirm RED**

Run: `swift test --filter 'DomainTests|PreferencesStoreTests'`  
Expected: compile failure for partition/search/store APIs.

- [ ] **Step 3: Implement deterministic pure logic and JSON persistence**

```swift
enum ItemSearch {
    static func filter(_ items: [MenuBarItemDescriptor], query: String) -> [MenuBarItemDescriptor] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(needle) || $0.ownerName.localizedCaseInsensitiveContains(needle) }
    }
}

final class PreferencesStore {
    func load() -> HarborPreferences {
        guard let data = defaults.data(forKey: key), let value = try? decoder.decode(HarborPreferences.self, from: data) else { return .defaults }
        return value
    }
    func save(_ value: HarborPreferences) { if let data = try? encoder.encode(value) { defaults.set(data, forKey: key) } }
}
```

- [ ] **Step 4: Run the focused tests and confirm GREEN**

Run: `swift test --filter 'DomainTests|PreferencesStoreTests'`  
Expected: all selected tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/MenuHarbor/Domain/MenuBarDomain.swift Sources/MenuHarbor/System/PreferencesStore.swift Tests/MenuHarborTests
git commit -m "feat: classify and persist menu bar state"
```

### Task 3: Native fold controller

**Files:**
- Create: `Sources/MenuHarbor/MenuBar/MenuBarController.swift`
- Create: `Sources/MenuHarbor/App/MenuHarborApp.swift`
- Create: `Sources/MenuHarbor/App/AppDelegate.swift`

- [ ] **Step 1: Add a failing state-transition test**

```swift
func testFoldStateTogglesAndRestoreAlwaysExpands() {
    var state = FoldState.folded
    state.toggle()
    XCTAssertEqual(state, .expanded)
    state.restore()
    XCTAssertEqual(state, .expanded)
}
```

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter DomainTests.testFoldStateTogglesAndRestoreAlwaysExpands`  
Expected: compile failure for `FoldState`.

- [ ] **Step 3: Implement the pure state and AppKit adapter**

```swift
enum FoldState: Equatable {
    case folded, expanded
    mutating func toggle() { self = self == .folded ? .expanded : .folded }
    mutating func restore() { self = .expanded }
}

@MainActor final class MenuBarController {
    static let foldedLength: CGFloat = 10_000
    static let dividerLength: CGFloat = 18
    func apply(_ state: FoldState) {
        dividerItem.length = state == .folded ? Self.foldedLength : Self.dividerLength
    }
}
```

Configure an autosaved main item and divider item, expose their window IDs, route left/right clicks separately, and set `LSUIElement=true` in the bundle.

- [ ] **Step 4: Run test and bundle smoke build**

Run: `swift test --filter DomainTests && make app`  
Expected: tests pass, `.build/release/MenuHarbor.app` exists and ad-hoc signing succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/MenuHarbor/App Sources/MenuHarbor/MenuBar/MenuBarController.swift
git commit -m "feat: fold menu bar items behind a divider"
```

### Task 4: Discovery, snapshots, and safe interaction

**Files:**
- Create: `Sources/MenuHarbor/MenuBar/MenuBarScanner.swift`
- Create: `Sources/MenuHarbor/MenuBar/MenuBarInteractor.swift`
- Create: `Sources/MenuHarbor/System/SystemServices.swift`
- Modify: `Tests/MenuHarborTests/DomainTests.swift`

- [ ] **Step 1: Write failing tests for fallback actions**

```swift
func testSelectingItemWithoutAccessibilityRequestsNativeExpansion() {
    XCTAssertEqual(ItemActivationPlan.make(itemExists: true, accessibility: false), .expandForManualClick)
}

func testMissingItemRequestsRefresh() {
    XCTAssertEqual(ItemActivationPlan.make(itemExists: false, accessibility: true), .refresh)
}
```

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter DomainTests`  
Expected: compile failure for `ItemActivationPlan`.

- [ ] **Step 3: Implement scanning and interaction adapters**

```swift
enum ItemActivationPlan: Equatable {
    case click, expandForManualClick, refresh
    static func make(itemExists: Bool, accessibility: Bool) -> Self {
        guard itemExists else { return .refresh }
        return accessibility ? .click : .expandForManualClick
    }
}
```

Use `CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID)` to discover `kCGStatusWindowLevel` windows. Exclude the current process and non-positive frames. Capture only while the shelf is opening and only with screen-capture permission. On interactive selection, expand first, rediscover by window ID/owner/title, post a process-targeted click, then schedule refolding; otherwise expand for manual use.

- [ ] **Step 4: Verify tests and compile**

Run: `swift test && swift build`  
Expected: all tests pass and debug build exits 0.

- [ ] **Step 5: Commit**

```bash
git add Sources/MenuHarbor/MenuBar Sources/MenuHarbor/System/SystemServices.swift Tests/MenuHarborTests/DomainTests.swift
git commit -m "feat: discover and activate hidden menu items"
```

### Task 5: Shelf, settings, and onboarding UI

**Files:**
- Create: `Sources/MenuHarbor/App/AppModel.swift`
- Create: `Sources/MenuHarbor/UI/ShelfPanel.swift`
- Create: `Sources/MenuHarbor/UI/ShelfView.swift`
- Create: `Sources/MenuHarbor/UI/SettingsView.swift`
- Create: `Sources/MenuHarbor/UI/OnboardingView.swift`
- Modify: `Sources/MenuHarbor/App/AppDelegate.swift`

- [ ] **Step 1: Add a failing presentation test**

```swift
func testEmptyQueryShowsAllItemsAndPermissionCopyMatchesCapability() {
    XCTAssertEqual(ShelfPresentation.filtered(items: fixtures, query: ""), fixtures)
    XCTAssertEqual(ShelfPresentation.permissionMessage(for: .foldOnly), "开启增强模式，直接在港湾中识别和点击图标")
}
```

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter DomainTests`  
Expected: compile failure for `ShelfPresentation`.

- [ ] **Step 3: Implement presentation logic and native views**

```swift
enum ShelfPresentation {
    static func filtered(items: [MenuBarItemDescriptor], query: String) -> [MenuBarItemDescriptor] { ItemSearch.filter(items, query: query) }
    static func permissionMessage(for capability: HarborCapability) -> String? {
        capability == .foldOnly ? "开启增强模式，直接在港湾中识别和点击图标" : nil
    }
}
```

Build a 420–620 pt adaptive shelf with material background, search field, 36 pt item targets, empty/error states, permission CTA, restore action, visible focus, Escape dismissal, and reduced-motion-aware transitions. Place it below the active screen menu bar and clamp it to `visibleFrame`. Build a 520×430 settings/onboarding window with General and Privacy sections, explicit per-permission explanations, and no decorative emoji.

- [ ] **Step 4: Verify tests and launch smoke test**

Run: `swift test && make app && open .build/release/MenuHarbor.app`  
Expected: all tests pass; one MenuHarbor status icon and one divider appear; first launch opens onboarding; no Dock icon appears.

- [ ] **Step 5: Commit**

```bash
git add Sources/MenuHarbor/App Sources/MenuHarbor/UI
git commit -m "feat: add the Harbor shelf and onboarding"
```

### Task 6: Automation and recovery

**Files:**
- Modify: `Sources/MenuHarbor/App/AppModel.swift`
- Modify: `Sources/MenuHarbor/System/SystemServices.swift`
- Modify: `Sources/MenuHarbor/UI/SettingsView.swift`
- Modify: `Tests/MenuHarborTests/DomainTests.swift`

- [ ] **Step 1: Write failing auto-hide policy tests**

```swift
func testAutoHideDisabledReturnsNoDeadline() {
    XCTAssertNil(AutoHidePolicy.deadline(now: Date(timeIntervalSince1970: 100), delay: 0))
}

func testInteractionRenewsDeadline() {
    XCTAssertEqual(AutoHidePolicy.deadline(now: Date(timeIntervalSince1970: 100), delay: 10), Date(timeIntervalSince1970: 110))
}
```

- [ ] **Step 2: Run and confirm RED**

Run: `swift test --filter DomainTests`  
Expected: compile failure for `AutoHidePolicy`.

- [ ] **Step 3: Implement automation**

```swift
enum AutoHidePolicy {
    static func deadline(now: Date, delay: TimeInterval) -> Date? { delay > 0 ? now.addingTimeInterval(delay) : nil }
}
```

Wire a cancel-and-replace `Task` in `AppModel`, register `⌃⌥H` with Carbon `RegisterEventHotKey`, update `SMAppService.mainApp` only after user interaction, close the shelf on active-space/screen changes, and call restore before normal termination.

- [ ] **Step 4: Run the full suite and production build**

Run: `swift test && make app`  
Expected: all tests pass and release bundle signs successfully.

- [ ] **Step 5: Commit**

```bash
git add Sources/MenuHarbor Tests/MenuHarborTests/DomainTests.swift
git commit -m "feat: add auto-hide shortcut and recovery"
```

### Task 7: Documentation and release verification

**Files:**
- Create: `README.md`
- Create: `docs/privacy.md`
- Modify: `Info.plist`

- [ ] **Step 1: Document exact install and permission behavior**

```markdown
make app
open .build/release/MenuHarbor.app
```

Document `⌘`-drag placement, base-mode behavior, optional permission scope, local-only processing, restore/quit behavior, known private-system limitations, and troubleshooting links to System Settings.

- [ ] **Step 2: Run formatting/static hygiene checks**

Run: `swift format lint --recursive Sources Tests Package.swift`  
Expected: exit 0, or if `swift-format` is not installed, record that fact and run `swiftc`/build warnings inspection instead.

- [ ] **Step 3: Run fresh release verification**

Run: `swift test && make app && codesign --verify --deep --strict .build/release/MenuHarbor.app && plutil -lint .build/release/MenuHarbor.app/Contents/Info.plist`  
Expected: tests report zero failures; bundle, signature, and plist checks exit 0.

- [ ] **Step 4: Inspect repository state and commit**

```bash
git status --short
git add README.md docs/privacy.md Info.plist
git commit -m "docs: explain MenuHarbor setup and privacy"
```

- [ ] **Step 5: Manual acceptance pass**

Launch the built app, verify status icon/divider/onboarding, fold/restore behavior, shelf keyboard dismissal, settings, permission CTAs, and clean quit. Record any hardware-only limitation honestly in the handoff.

