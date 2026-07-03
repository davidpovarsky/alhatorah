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
            let siteID = userActivity.userInfo?[Self.siteIDKey] as? String
            let urlString = userActivity.userInfo?[Self.urlKey] as? String
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
}
