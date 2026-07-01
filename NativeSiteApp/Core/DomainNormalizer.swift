import Foundation

enum DomainNormalizer {
    static func normalize(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let valueWithoutWildcard = trimmed
            .replacingOccurrences(of: "applinks:", with: "")
            .replacingOccurrences(of: "*.", with: "")

        if let url = URL(string: valueWithoutWildcard), let host = url.host {
            return cleanup(host)
        }

        if let url = URL(string: "https://\(valueWithoutWildcard)"), let host = url.host {
            return cleanup(host)
        }

        return cleanup(valueWithoutWildcard)
    }

    static func normalizeList(_ rawText: String) -> [String] {
        let separators = CharacterSet(charactersIn: "\n,;")
        return rawText
            .components(separatedBy: separators)
            .compactMap { normalize($0) }
            .removingDuplicates()
    }

    private static func cleanup(_ host: String) -> String? {
        let cleaned = host
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard !cleaned.isEmpty else { return nil }
        guard cleaned.contains(".") else { return nil }
        return cleaned
    }
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
