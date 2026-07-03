import Foundation

enum URLPolicyDecision: Equatable {
    case internalWeb
    case configuredSite(siteID: String)
    case externalWeb
    case systemExternal
}

struct URLPolicy {
    var settings: AppSettings
    var currentSiteID: String?

    init(settings: AppSettings, currentSiteID: String? = nil) {
        self.settings = settings
        self.currentSiteID = currentSiteID
    }

    func decision(for url: URL) -> URLPolicyDecision {
        guard let scheme = url.scheme?.lowercased() else { return .systemExternal }

        switch scheme {
        case "http", "https":
            let currentSite = settings.siteProfile(withID: currentSiteID) ?? settings.defaultSite
            if currentSite.matches(url) {
                return .internalWeb
            }

            if let matchingSite = settings.matchingSite(for: url) {
                if matchingSite.id == currentSite.id {
                    return .internalWeb
                }
                return settings.openConfiguredSitesInNewWindows
                    ? .configuredSite(siteID: matchingSite.id)
                    : .internalWeb
            }

            return .externalWeb

        case "about":
            return .internalWeb

        default:
            return .systemExternal
        }
    }

    func isInternalWebURL(_ url: URL) -> Bool {
        switch decision(for: url) {
        case .internalWeb, .configuredSite:
            return true
        case .externalWeb, .systemExternal:
            return false
        }
    }
}
