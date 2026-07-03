import Foundation

struct DeepLinkDestination: Equatable {
    let url: URL
    let siteID: String?
    let prefersNewWindow: Bool
}

struct DeepLinkParser {
    static let customScheme = "nativeweb"

    static func destination(from incomingURL: URL) -> DeepLinkDestination? {
        if let scheme = incomingURL.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return DeepLinkDestination(url: incomingURL, siteID: nil, prefersNewWindow: false)
        }

        guard incomingURL.scheme?.lowercased() == customScheme else { return nil }
        guard let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false) else { return nil }

        let queryItems = components.queryItems ?? []
        guard let encodedURL = queryItems.first(where: { $0.name == "url" })?.value,
              let destinationURL = URL(string: encodedURL) else { return nil }

        let siteID = queryItems.first(where: { $0.name == "site" || $0.name == "siteID" })?.value
        let newWindowValue = queryItems.first(where: { $0.name == "newWindow" || $0.name == "window" })?.value?.lowercased()
        let prefersNewWindow = ["1", "true", "yes", "new"].contains(newWindowValue ?? "")

        return DeepLinkDestination(url: destinationURL, siteID: siteID, prefersNewWindow: prefersNewWindow)
    }

    static func destinationURL(from incomingURL: URL) -> URL? {
        destination(from: incomingURL)?.url
    }

    static func exampleURL(for destination: URL, siteID: String? = nil, prefersNewWindow: Bool = false) -> URL? {
        var components = URLComponents()
        components.scheme = customScheme
        components.host = "open"

        var items = [URLQueryItem(name: "url", value: destination.absoluteString)]
        if let siteID, !siteID.isEmpty {
            items.append(URLQueryItem(name: "site", value: siteID))
        }
        if prefersNewWindow {
            items.append(URLQueryItem(name: "newWindow", value: "1"))
        }
        components.queryItems = items
        return components.url
    }
}
