import Foundation

struct AppSettings: Codable, Equatable {
    var homeURLString: String
    var allowedDomains: [String]
    var openExternalLinksInSafariView: Bool
    var hideToolbarOnScroll: Bool
    var preferDesktopUserAgent: Bool

    static let defaultHomeURLString = "https://alhatorah.org/"

    static var defaults: AppSettings {
        AppSettings(
            homeURLString: defaultHomeURLString,
            allowedDomains: ["alhatorah.org"],
            openExternalLinksInSafariView: true,
            hideToolbarOnScroll: true,
            preferDesktopUserAgent: false
        )
    }

    var homeURL: URL {
        URL(string: homeURLString) ?? URL(string: Self.defaultHomeURLString)!
    }
}
