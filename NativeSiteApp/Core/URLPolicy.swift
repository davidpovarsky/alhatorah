import Foundation

enum URLPolicyDecision: Equatable {
    case internalWeb
    case externalWeb
    case systemExternal
}

struct URLPolicy {
    var settings: AppSettings

    func decision(for url: URL) -> URLPolicyDecision {
        guard let scheme = url.scheme?.lowercased() else { return .systemExternal }

        switch scheme {
        case "http", "https":
            return isInternalWebURL(url) ? .internalWeb : .externalWeb
        case "about":
            return .internalWeb
        default:
            return .systemExternal
        }
    }

    func isInternalWebURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))

        for domain in settings.allowedDomains.compactMap(DomainNormalizer.normalize) {
            if normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)") {
                return true
            }
        }
        return false
    }
}
