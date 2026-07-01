import Foundation

struct DeepLinkParser {
    static let customScheme = "nativeweb"

    static func destinationURL(from incomingURL: URL) -> URL? {
        if let scheme = incomingURL.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return incomingURL
        }

        guard incomingURL.scheme?.lowercased() == customScheme else { return nil }

        if let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
           let encodedURL = components.queryItems?.first(where: { $0.name == "url" })?.value,
           let destination = URL(string: encodedURL) {
            return destination
        }

        return nil
    }

    static func exampleURL(for destination: URL) -> URL? {
        var components = URLComponents()
        components.scheme = customScheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "url", value: destination.absoluteString)]
        return components.url
    }
}
