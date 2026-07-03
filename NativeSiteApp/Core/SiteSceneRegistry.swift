import UIKit

final class SiteSceneRegistry {
    static let shared = SiteSceneRegistry()

    private let userDefaults: UserDefaults
    private let key = "native_site_app.site_scene_registry.v1"
    private let queue = DispatchQueue(label: "native_site_app.site_scene_registry")

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func register(siteID: String, session: UISceneSession) {
        let cleanedSiteID = siteID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSiteID.isEmpty else { return }

        queue.sync {
            var mapping = loadMapping()
            mapping[cleanedSiteID] = session.persistentIdentifier
            saveMapping(mapping)
        }
    }

    func unregister(session: UISceneSession) {
        queue.sync {
            var mapping = loadMapping()
            mapping = mapping.filter { $0.value != session.persistentIdentifier }
            saveMapping(mapping)
        }
    }

    func session(for siteID: String, excluding currentSession: UISceneSession? = nil) -> UISceneSession? {
        let cleanedSiteID = siteID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedSiteID.isEmpty else { return nil }

        let mappedIdentifier = queue.sync { loadMapping()[cleanedSiteID] }
        let openSessions = UIApplication.shared.openSessions

        if let mappedIdentifier,
           let session = openSessions.first(where: { $0.persistentIdentifier == mappedIdentifier }),
           session.persistentIdentifier != currentSession?.persistentIdentifier {
            return session
        }

        removeMissingSessions(validIdentifiers: Set(openSessions.map(\.persistentIdentifier)))
        return nil
    }

    private func removeMissingSessions(validIdentifiers: Set<String>) {
        queue.sync {
            var mapping = loadMapping()
            let originalCount = mapping.count
            mapping = mapping.filter { validIdentifiers.contains($0.value) }
            if mapping.count != originalCount {
                saveMapping(mapping)
            }
        }
    }

    private func loadMapping() -> [String: String] {
        userDefaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    private func saveMapping(_ mapping: [String: String]) {
        userDefaults.set(mapping, forKey: key)
    }
}
