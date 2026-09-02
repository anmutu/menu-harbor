import Foundation

final class PreferencesStore {
    static let storageKey = "MenuHarbor.preferences.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HarborPreferences {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let value = try? decoder.decode(HarborPreferences.self, from: data)
        else {
            return .defaults
        }
        return value
    }

    func save(_ value: HarborPreferences) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

