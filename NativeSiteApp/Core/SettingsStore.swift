import Foundation

protocol SettingsStoreDelegate: AnyObject {
    func settingsStoreDidChange(_ store: SettingsStore)
}

final class SettingsStore {
    weak var delegate: SettingsStoreDelegate?

    private let userDefaults: UserDefaults
    private let key = "native_site_app.settings.v1"

    private(set) var settings: AppSettings {
        didSet {
            save()
            delegate?.settingsStoreDidChange(self)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .defaults
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        if copy.allowedDomains.isEmpty {
            copy.allowedDomains = AppSettings.defaults.allowedDomains
        }
        settings = copy
    }

    func reset() {
        settings = .defaults
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}
