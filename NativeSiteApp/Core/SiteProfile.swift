import Foundation

struct SiteProfile: Codable, Identifiable, Equatable {
    static let alHaTorahID = "alhatorah"

    let id: String
    var name: String
    var homeURLString: String
    var allowedDomains: [String]

    init(id: String = UUID().uuidString, name: String, homeURLString: String, allowedDomains: [String]) {
        self.id = id
        self.name = name
        self.homeURLString = homeURLString
        self.allowedDomains = allowedDomains
    }

    static var alHaTorahDefault: SiteProfile {
        SiteProfile(
            id: alHaTorahID,
            name: "AlHaTorah",
            homeURLString: "https://alhatorah.org/",
            allowedDomains: ["alhatorah.org"]
        )
    }

    var homeURL: URL {
        URL(string: homeURLString) ?? URL(string: Self.alHaTorahDefault.homeURLString)!
    }

    var displayHost: String {
        homeURL.host ?? homeURLString
    }

    func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        for domain in allowedDomains.compactMap(DomainNormalizer.normalize) {
            if normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)") {
                return true
            }
        }
        return false
    }

    mutating func normalize() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            name = displayHost
        }

        homeURLString = homeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if homeURLString.isEmpty {
            homeURLString = Self.alHaTorahDefault.homeURLString
        }

        let normalizedDomains = allowedDomains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(DomainNormalizer.normalize)

        var seen = Set<String>()
        allowedDomains = normalizedDomains.filter { seen.insert($0).inserted }

        if allowedDomains.isEmpty, let host = homeURL.host, let normalized = DomainNormalizer.normalize(host) {
            allowedDomains = [normalized]
        }

        if allowedDomains.isEmpty {
            allowedDomains = Self.alHaTorahDefault.allowedDomains
        }
    }
}
