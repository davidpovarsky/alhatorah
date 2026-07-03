import Foundation

protocol SettingsStoreDelegate: AnyObject {
    func settingsStoreDidChange(_ store: SettingsStore)
}

final class SettingsStore {
    weak var delegate: SettingsStoreDelegate?

    private let userDefaults: UserDefaults
    private let key = "native_site_app.settings.v2"
    private let legacyKey = "native_site_app.settings.v1"

    private(set) var settings: AppSettings {
        didSet {
            save()
            AppShortcutManager.updateQuickActions(settings: settings)
            delegate?.settingsStoreDidChange(self)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            var cleaned = decoded
            cleaned.normalize()
            self.settings = cleaned
        } else if let legacyData = userDefaults.data(forKey: legacyKey),
                  let decoded = try? JSONDecoder().decode(AppSettings.self, from: legacyData) {
            var cleaned = decoded
            cleaned.normalize()
            self.settings = cleaned
            saveMigratedSettings(cleaned)
        } else {
            self.settings = .defaults
        }

        AppShortcutManager.updateQuickActions(settings: settings)
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        copy.normalize()
        settings = copy
    }

    func reset() {
        settings = .defaults
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func saveMigratedSettings(_ migrated: AppSettings) {
        guard let data = try? JSONEncoder().encode(migrated) else { return }
        userDefaults.set(data, forKey: key)
    }
}
