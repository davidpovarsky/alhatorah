import UIKit

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
        let iconName = profile.id == SiteProfile.alHaTorahID ? "book" : "globe"
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
