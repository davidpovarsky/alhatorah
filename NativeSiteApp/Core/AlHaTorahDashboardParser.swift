import Foundation

public enum HTMLEntityDecoder {
    private static let namedEntities: [String: String] = [
        "&quot;": "\"",
        "&apos;": "'",
        "&amp;": "&",
        "&lt;": "<",
        "&gt;": ">",
        "&nbsp;": " ",
        "&rlm;": "\u{200F}",
        "&lrm;": "\u{200E}",
        "&mdash;": "—",
        "&ndash;": "–",
        "&hellip;": "…",
        "&rsquo;": "'",
        "&lsquo;": "'",
        "&rdquo;": "\"",
        "&ldquo;": "\"",
        "&laquo;": "«",
        "&raquo;": "»"
    ]

    public static func decode(_ string: String) -> String {
        var result = string
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        guard result.contains("&#") else { return result }

        // Decimal entities: &#([0-9]{1,7});
        if let decimalRegex = try? NSRegularExpression(pattern: #"&#([0-9]{1,7});"#) {
            let ns = result as NSString
            let matches = decimalRegex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length)).reversed()
            var mutable = result
            for match in matches {
                guard let fullRange = Range(match.range, in: mutable),
                      let numRange = Range(match.range(at: 1), in: mutable),
                      let code = UInt32(mutable[numRange]),
                      let scalar = UnicodeScalar(code) else { continue }
                mutable.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
            result = mutable
        }

        // Hex entities: &#x([0-9a-fA-F]{1,6});
        if let hexRegex = try? NSRegularExpression(pattern: #"&#x([0-9a-fA-F]{1,6});"#, options: [.caseInsensitive]) {
            let ns = result as NSString
            let matches = hexRegex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length)).reversed()
            var mutable = result
            for match in matches {
                guard let fullRange = Range(match.range, in: mutable),
                      let hexRange = Range(match.range(at: 1), in: mutable),
                      let code = UInt32(mutable[hexRange], radix: 16),
                      let scalar = UnicodeScalar(code) else { continue }
                mutable.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
            result = mutable
        }

        return result
    }
}

public enum AlHaTorahDashboardParser {
    public static func parseHistory(from html: String, preferredLang: String = "he") -> [AlHaTorahHistoryItem] {
        var items: [AlHaTorahHistoryItem] = []
        
        let rowPattern = #"(?s)<tr\b([^>]*(?:data-id=|data-base=|history-item)[^>]*)>(.*?)<\/tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive]) else {
            return []
        }

        let idPattern = #"data-id="([^"]+)""#
        let basePattern = #"data-base="([^"]+)""#
        let locnumPattern = #"data-locnum="([^"]+)""#
        let datePattern = #"data-date="([^"]+)""#
        let linkPattern = #"(?s)<a\s+[^>]*?href="([^"]+)"[^>]*?>(.*?)<\/a>"#
        let tdPattern = #"(?s)<td\b[^>]*>(.*?)<\/td>"#

        let idRegex = try? NSRegularExpression(pattern: idPattern)
        let baseRegex = try? NSRegularExpression(pattern: basePattern)
        let locnumRegex = try? NSRegularExpression(pattern: locnumPattern)
        let dateRegex = try? NSRegularExpression(pattern: datePattern)
        let linkRegex = try? NSRegularExpression(pattern: linkPattern)
        let tdRegex = try? NSRegularExpression(pattern: tdPattern)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIsoFormatter = ISO8601DateFormatter()
        fallbackIsoFormatter.formatOptions = [.withInternetDateTime]

        let nsHtml = html as NSString
        let matches = rowRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))

        for match in matches {
            let rowContent = nsHtml.substring(with: match.range)
            let nsRow = rowContent as NSString
            let rowRange = NSRange(location: 0, length: nsRow.length)

            let id = extractFirstCapture(using: idRegex, in: nsRow, range: rowRange) ?? UUID().uuidString
            let rawBase = extractFirstCapture(using: baseRegex, in: nsRow, range: rowRange) ?? "tanakh"
            let base = rawBase.lowercased()
            let locnum = extractFirstCapture(using: locnumRegex, in: nsRow, range: rowRange)
            let dateStr = extractFirstCapture(using: dateRegex, in: nsRow, range: rowRange)

            var visitedDate = Date()
            if let dateStr = dateStr {
                visitedDate = isoFormatter.date(from: dateStr) ?? fallbackIsoFormatter.date(from: dateStr) ?? Date()
            }

            var rawUrl = ""
            var rawTitle = ""
            if let linkMatch = linkRegex?.firstMatch(in: rowContent, options: [], range: rowRange) {
                if linkMatch.numberOfRanges > 1 {
                    rawUrl = nsRow.substring(with: linkMatch.range(at: 1))
                }
                if linkMatch.numberOfRanges > 2 {
                    rawTitle = nsRow.substring(with: linkMatch.range(at: 2))
                }
            }

            // Clean URLs like https:////mg.alhatorah.org -> https://mg.alhatorah.org
            var cleanUrl = rawUrl.replacingOccurrences(of: "https:////", with: "https://")
            cleanUrl = cleanUrl.replacingOccurrences(of: "http:////", with: "http://")
            if cleanUrl.hasPrefix("//") {
                cleanUrl = "https:" + cleanUrl
            }

            // Extract cells from the row
            var commentator: String? = nil
            if let tdMatches = tdRegex?.matches(in: rowContent, options: [], range: rowRange), tdMatches.count >= 3 {
                let cell3Range = tdMatches[2].range(at: 1)
                let cell3Html = nsRow.substring(with: cell3Range)
                let commText = extractLocalizedText(from: cell3Html, preferredLang: preferredLang)
                if !commText.isEmpty {
                    commentator = commText
                }
            }

            // Extract localized clean title (without language concatenation or raw entities)
            let parsedTitle = extractLocalizedText(from: rawTitle, preferredLang: preferredLang)
            let finalTitle = parsedTitle.isEmpty ? (locnum ?? base) : parsedTitle

            let item = AlHaTorahHistoryItem(
                id: id,
                base: base,
                locnum: locnum,
                title: finalTitle,
                urlString: cleanUrl,
                commentator: commentator,
                visitedAt: visitedDate,
                isSynced: true
            )
            items.append(item)
        }

        return items
    }

    public static func extractLocalizedText(from html: String, preferredLang: String = "he") -> String {
        let preferredClass = preferredLang == "en" ? #"(?:lang-en|mg-lang-en)"# : #"(?:lang-he|mg-lang-he)"#
        let fallbackClass = preferredLang == "en" ? #"(?:lang-he|mg-lang-he)"# : #"(?:lang-en|mg-lang-en)"#

        // 1. Try preferred language span
        let preferredPattern = #"(?s)<span[^>]*class="[^"]*?\b"# + preferredClass + #"\b[^"]*?"[^>]*?>(.*?)<\/span>"#
        if let regex = try? NSRegularExpression(pattern: preferredPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges > 1 {
            let captured = (html as NSString).substring(with: match.range(at: 1))
            let stripped = stripTags(from: captured)
            return HTMLEntityDecoder.decode(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 2. Try fallback language span if preferred not found
        let fallbackPattern = #"(?s)<span[^>]*class="[^"]*?\b"# + fallbackClass + #"\b[^"]*?"[^>]*?>(.*?)<\/span>"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges > 1 {
            let captured = (html as NSString).substring(with: match.range(at: 1))
            let stripped = stripTags(from: captured)
            return HTMLEntityDecoder.decode(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 3. Strip all tags and decode entities
        let stripped = stripTags(from: html)
        return HTMLEntityDecoder.decode(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripTags(from html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    private static func extractFirstCapture(using regex: NSRegularExpression?, in string: NSString, range: NSRange) -> String? {
        guard let match = regex?.firstMatch(in: string as String, options: [], range: range),
              match.numberOfRanges > 1 else { return nil }
        return string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
