import UIKit

struct SceneLaunchRequest: Equatable {
    static let activityType = "com.davidpovarsky.alhatorah.open-site"
    static let siteIDKey = "siteID"
    static let urlKey = "url"
    static let newWindowKey = "newWindow"

    let siteID: String?
    let url: URL?
    let prefersNewWindow: Bool

    init(siteID: String?, url: URL?, prefersNewWindow: Bool = false) {
        self.siteID = siteID
        self.url = url
        self.prefersNewWindow = prefersNewWindow
    }

    init(destination: DeepLinkDestination) {
        self.siteID = destination.siteID
        self.url = destination.url
        self.prefersNewWindow = destination.prefersNewWindow
    }

    func resolvedSiteID(settings: AppSettings) -> String {
        if let siteID, settings.siteProfile(withID: siteID) != nil {
            return siteID
        }
        if let url, let matching = settings.matchingSite(for: url) {
            return matching.id
        }
        return settings.defaultSiteID
    }

    func resolvedURL(settings: AppSettings) -> URL {
        if let url { return url }
        let resolvedSiteID = resolvedSiteID(settings: settings)
        return settings.siteProfile(withID: resolvedSiteID)?.homeURL ?? settings.defaultSite.homeURL
    }

    func makeUserActivity(settings: AppSettings? = nil) -> NSUserActivity {
        let activity = NSUserActivity(activityType: Self.activityType)
        activity.title = title(settings: settings)
        var userInfo: [String: Any] = [Self.newWindowKey: prefersNewWindow]
        if let siteID {
            userInfo[Self.siteIDKey] = siteID
        }
        if let url {
            userInfo[Self.urlKey] = url.absoluteString
        }
        activity.userInfo = userInfo
        activity.isEligibleForHandoff = true
        activity.targetContentIdentifier = siteID ?? url?.host
        return activity
    }

    private func title(settings: AppSettings?) -> String {
        if let siteID, let site = settings?.siteProfile(withID: siteID) {
            return site.name
        }
        return url?.host ?? "Native Web"
    }

    static func from(urlContexts: Set<UIOpenURLContext>) -> SceneLaunchRequest? {
        guard let incomingURL = urlContexts.first?.url,
              let destination = DeepLinkParser.destination(from: incomingURL) else { return nil }
        return SceneLaunchRequest(destination: destination)
    }

    static func from(userActivity: NSUserActivity) -> SceneLaunchRequest? {
        if userActivity.activityType == Self.activityType {
            let siteID = stringValue(userActivity.userInfo?[Self.siteIDKey])
            let urlString = stringValue(userActivity.userInfo?[Self.urlKey])
            let url = urlString.flatMap(URL.init(string:))
            let newWindow = userActivity.userInfo?[Self.newWindowKey] as? Bool ?? false
            return SceneLaunchRequest(siteID: siteID, url: url, prefersNewWindow: newWindow)
        }

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let webpageURL = userActivity.webpageURL {
            return SceneLaunchRequest(siteID: nil, url: webpageURL, prefersNewWindow: false)
        }

        return nil
    }

    static func from(connectionOptions: UIScene.ConnectionOptions) -> SceneLaunchRequest? {
        if let shortcutItem = connectionOptions.shortcutItem,
           let request = AppShortcutManager.launchRequest(from: shortcutItem) {
            return request
        }

        if let request = from(urlContexts: connectionOptions.urlContexts) {
            return request
        }

        for activity in connectionOptions.userActivities {
            if let request = from(userActivity: activity) {
                return request
            }
        }

        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let string = value as? NSString { return string as String }
        return nil
    }
}

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

enum AppShortcutManager {
    static let shortcutTypePrefix = "com.davidpovarsky.alhatorah.open-site."
    static let maxShortcutCount = 4

    static func updateQuickActions(settings: AppSettings) {
        let items = settings.siteProfiles.prefix(maxShortcutCount).map { profile in
            shortcutItem(for: profile, isDefault: profile.id == settings.defaultSiteID)
        }
        UIApplication.shared.shortcutItems = Array(items)
    }

    static func launchRequest(from shortcutItem: UIApplicationShortcutItem) -> SceneLaunchRequest? {
        guard shortcutItem.type.hasPrefix(shortcutTypePrefix) else { return nil }

        let siteID = stringValue(shortcutItem.userInfo?[SceneLaunchRequest.siteIDKey])
            ?? String(shortcutItem.type.dropFirst(shortcutTypePrefix.count))
        let urlString = stringValue(shortcutItem.userInfo?[SceneLaunchRequest.urlKey])
        let url = urlString.flatMap(URL.init(string:))

        return SceneLaunchRequest(siteID: siteID, url: url, prefersNewWindow: true)
    }

    private static func shortcutItem(for profile: SiteProfile, isDefault: Bool) -> UIApplicationShortcutItem {
        let iconName = "globe"
        let icon = UIApplicationShortcutIcon(systemImageName: iconName)
        var userInfo: [String: NSSecureCoding] = [
            SceneLaunchRequest.siteIDKey: profile.id as NSString,
            SceneLaunchRequest.urlKey: profile.homeURLString as NSString
        ]

        userInfo["isDefault"] = NSNumber(value: isDefault)

        return UIApplicationShortcutItem(
            type: shortcutTypePrefix + profile.id,
            localizedTitle: profile.name,
            localizedSubtitle: profile.displayHost,
            icon: icon,
            userInfo: userInfo
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let string = value as? NSString { return string as String }
        return nil
    }
}
