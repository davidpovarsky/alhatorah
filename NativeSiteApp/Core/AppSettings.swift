import Foundation

struct AppSettings: Codable, Equatable {
    var siteProfiles: [SiteProfile]
    var defaultSiteID: String
    var openConfiguredSitesInNewWindows: Bool
    var openExternalLinksInSafariView: Bool
    var hideToolbarOnScroll: Bool
    var preferDesktopUserAgent: Bool

    static let defaultHomeURLString = SiteProfile.alHaTorahDefault.homeURLString

    static var defaults: AppSettings {
        AppSettings(
            siteProfiles: [.alHaTorahDefault],
            defaultSiteID: SiteProfile.alHaTorahID,
            openConfiguredSitesInNewWindows: true,
            openExternalLinksInSafariView: true,
            hideToolbarOnScroll: true,
            preferDesktopUserAgent: false
        )
    }

    init(
        siteProfiles: [SiteProfile],
        defaultSiteID: String,
        openConfiguredSitesInNewWindows: Bool,
        openExternalLinksInSafariView: Bool,
        hideToolbarOnScroll: Bool,
        preferDesktopUserAgent: Bool
    ) {
        self.siteProfiles = siteProfiles
        self.defaultSiteID = defaultSiteID
        self.openConfiguredSitesInNewWindows = openConfiguredSitesInNewWindows
        self.openExternalLinksInSafariView = openExternalLinksInSafariView
        self.hideToolbarOnScroll = hideToolbarOnScroll
        self.preferDesktopUserAgent = preferDesktopUserAgent
        normalize()
    }

    private enum CodingKeys: String, CodingKey {
        case siteProfiles
        case defaultSiteID
        case openConfiguredSitesInNewWindows
        case openExternalLinksInSafariView
        case hideToolbarOnScroll
        case preferDesktopUserAgent

        // Legacy v1 settings keys. Kept so existing installs migrate cleanly.
        case homeURLString
        case allowedDomains
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let legacyHomeURLString = try container.decodeIfPresent(String.self, forKey: .homeURLString) ?? Self.defaultHomeURLString
        let legacyAllowedDomains = try container.decodeIfPresent([String].self, forKey: .allowedDomains) ?? SiteProfile.alHaTorahDefault.allowedDomains

        let decodedProfiles = try container.decodeIfPresent([SiteProfile].self, forKey: .siteProfiles)
        siteProfiles = decodedProfiles?.isEmpty == false
            ? decodedProfiles!
            : [SiteProfile(id: SiteProfile.alHaTorahID, name: "AlHaTorah", homeURLString: legacyHomeURLString, allowedDomains: legacyAllowedDomains)]

        defaultSiteID = try container.decodeIfPresent(String.self, forKey: .defaultSiteID) ?? siteProfiles.first?.id ?? SiteProfile.alHaTorahID
        openConfiguredSitesInNewWindows = try container.decodeIfPresent(Bool.self, forKey: .openConfiguredSitesInNewWindows) ?? true
        openExternalLinksInSafariView = try container.decodeIfPresent(Bool.self, forKey: .openExternalLinksInSafariView) ?? true
        hideToolbarOnScroll = try container.decodeIfPresent(Bool.self, forKey: .hideToolbarOnScroll) ?? true
        preferDesktopUserAgent = try container.decodeIfPresent(Bool.self, forKey: .preferDesktopUserAgent) ?? false

        normalize()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(siteProfiles, forKey: .siteProfiles)
        try container.encode(defaultSiteID, forKey: .defaultSiteID)
        try container.encode(openConfiguredSitesInNewWindows, forKey: .openConfiguredSitesInNewWindows)
        try container.encode(openExternalLinksInSafariView, forKey: .openExternalLinksInSafariView)
        try container.encode(hideToolbarOnScroll, forKey: .hideToolbarOnScroll)
        try container.encode(preferDesktopUserAgent, forKey: .preferDesktopUserAgent)

        // Legacy compatibility for any old code/build still reading v1 keys.
        try container.encode(homeURLString, forKey: .homeURLString)
        try container.encode(allowedDomains, forKey: .allowedDomains)
    }

    var defaultSite: SiteProfile {
        siteProfile(withID: defaultSiteID) ?? siteProfiles.first ?? .alHaTorahDefault
    }

    var homeURLString: String {
        get { defaultSite.homeURLString }
        set {
            updateDefaultSite { site in
                site.homeURLString = newValue
            }
        }
    }

    var allowedDomains: [String] {
        get { defaultSite.allowedDomains }
        set {
            updateDefaultSite { site in
                site.allowedDomains = newValue
            }
        }
    }

    var homeURL: URL {
        defaultSite.homeURL
    }

    func siteProfile(withID id: String?) -> SiteProfile? {
        guard let id else { return nil }
        return siteProfiles.first(where: { $0.id == id })
    }

    func matchingSite(for url: URL) -> SiteProfile? {
        siteProfiles.first(where: { $0.matches(url) })
    }

    mutating func upsertSiteProfile(_ profile: SiteProfile) {
        var cleaned = profile
        cleaned.normalize()

        if let index = siteProfiles.firstIndex(where: { $0.id == cleaned.id }) {
            siteProfiles[index] = cleaned
        } else {
            siteProfiles.append(cleaned)
        }
        normalize()
    }

    mutating func deleteSiteProfile(id: String) {
        guard siteProfiles.count > 1 else { return }
        siteProfiles.removeAll { $0.id == id }
        if defaultSiteID == id {
            defaultSiteID = siteProfiles.first?.id ?? SiteProfile.alHaTorahID
        }
        normalize()
    }

    mutating func setDefaultSiteID(_ id: String) {
        guard siteProfiles.contains(where: { $0.id == id }) else { return }
        defaultSiteID = id
        normalize()
    }

    mutating func updateDefaultSite(_ mutate: (inout SiteProfile) -> Void) {
        let id = defaultSiteID
        if let index = siteProfiles.firstIndex(where: { $0.id == id }) {
            mutate(&siteProfiles[index])
        } else if !siteProfiles.isEmpty {
            mutate(&siteProfiles[0])
            defaultSiteID = siteProfiles[0].id
        } else {
            var site = SiteProfile.alHaTorahDefault
            mutate(&site)
            siteProfiles = [site]
            defaultSiteID = site.id
        }
        normalize()
    }

    mutating func normalize() {
        if siteProfiles.isEmpty {
            siteProfiles = [.alHaTorahDefault]
        }

        siteProfiles = siteProfiles.map { profile in
            var cleaned = profile
            cleaned.normalize()
            return cleaned
        }

        var seen = Set<String>()
        siteProfiles = siteProfiles.filter { seen.insert($0.id).inserted }

        if !siteProfiles.contains(where: { $0.id == defaultSiteID }) {
            defaultSiteID = siteProfiles.first?.id ?? SiteProfile.alHaTorahID
        }
    }
}
