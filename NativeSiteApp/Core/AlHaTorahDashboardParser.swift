import Foundation

public enum AlHaTorahDashboardParser {
    public static func parseHistory(from html: String) -> [AlHaTorahHistoryItem] {
        var items: [AlHaTorahHistoryItem] = []
        
        let rowPattern = #"(?s)<tr\s+[^>]*?class="[^"]*?history-item[^"]*?"[^>]*?>(.*?)<\/tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive]) else {
            return []
        }

        let idPattern = #"data-id="([^"]+)""#
        let basePattern = #"data-base="([^"]+)""#
        let locnumPattern = #"data-locnum="([^"]+)""#
        let datePattern = #"data-date="([^"]+)""#
        let linkPattern = #"(?s)<a\s+[^>]*?href="([^"]+)"[^>]*?>(.*?)<\/a>"#
        let commentatorPattern = #"(?s)<td[^>]*?>\s*<span[^>]*?class="[^"]*?lang-he[^"]*?"[^>]*?>(.*?)<\/span>"#

        let idRegex = try? NSRegularExpression(pattern: idPattern)
        let baseRegex = try? NSRegularExpression(pattern: basePattern)
        let locnumRegex = try? NSRegularExpression(pattern: locnumPattern)
        let dateRegex = try? NSRegularExpression(pattern: datePattern)
        let linkRegex = try? NSRegularExpression(pattern: linkPattern)
        let commentatorRegex = try? NSRegularExpression(pattern: commentatorPattern)

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
            let base = extractFirstCapture(using: baseRegex, in: nsRow, range: rowRange) ?? "tanakh"
            let locnum = extractFirstCapture(using: locnumRegex, in: nsRow, range: rowRange)
            let dateStr = extractFirstCapture(using: dateRegex, in: nsRow, range: rowRange)

            var visitedDate = Date()
            if let dateStr = dateStr {
                visitedDate = isoFormatter.date(from: dateStr) ?? fallbackIsoFormatter.date(from: dateStr) ?? Date()
            }

            var rawUrl = ""
            var title = ""
            if let linkMatch = linkRegex?.firstMatch(in: rowContent, options: [], range: rowRange) {
                if linkMatch.numberOfRanges > 1 {
                    rawUrl = nsRow.substring(with: linkMatch.range(at: 1))
                }
                if linkMatch.numberOfRanges > 2 {
                    title = nsRow.substring(with: linkMatch.range(at: 2))
                }
            }

            // Clean URLs like https:////mg.alhatorah.org -> https://mg.alhatorah.org
            var cleanUrl = rawUrl.replacingOccurrences(of: "https:////", with: "https://")
            cleanUrl = cleanUrl.replacingOccurrences(of: "http:////", with: "http://")
            if cleanUrl.hasPrefix("//") {
                cleanUrl = "https:" + cleanUrl
            }

            // Extract commentator if present
            var commentator: String? = nil
            if let commMatches = commentatorRegex?.matches(in: rowContent, options: [], range: rowRange), commMatches.count >= 2 {
                // The first match is corpus (e.g. תנ"ך), second match is commentator (e.g. ספרי במדבר)
                let commMatch = commMatches[1]
                if commMatch.numberOfRanges > 1 {
                    let text = nsRow.substring(with: commMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        commentator = text
                    }
                }
            }

            let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = cleanedTitle.isEmpty ? (locnum ?? base) : cleanedTitle

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

    private static func extractFirstCapture(using regex: NSRegularExpression?, in string: NSString, range: NSRange) -> String? {
        guard let match = regex?.firstMatch(in: string as String, options: [], range: range),
              match.numberOfRanges > 1 else { return nil }
        return string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
