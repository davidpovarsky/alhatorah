import Foundation

struct BookIndexItem: Codable, Equatable {
    let id: String
    let titleHe: String
    let titleEn: String
    let aliases: [String]
    let categoryTitles: [String]
    let sectionNames: [String]
    let searchableText: String
}

struct BookTreeNode: Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    var children: [BookTreeNode]
    let item: BookIndexItem?
    var bookCount: Int
}

struct BookIndexBundle: Codable, Equatable {
    let signature: String
    let createdAt: Date
    let booksIndex: [BookIndexItem]
    let booksTree: BookTreeNode
}

struct RefPHPDocument {
    let text: String
    let signature: String
    let downloadedAt: Date
    let source: RefPHPSource
}

enum RefPHPSource: String {
    case downloaded
    case cached
}

struct SpotlightRefreshSummary {
    let itemCount: Int
    let indexedCount: Int
    let skipped: Bool
    let source: RefPHPSource
    let signature: String
    let message: String
}

extension AlHaTorahCanonicalTitles {
    static func buildBaseIndexItems() -> [BookIndexItem] {
        var items: [BookIndexItem] = []
        var seen = Set<String>()
        let lines = data.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let en = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let he = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !en.isEmpty, !he.isEmpty, !seen.contains(en) else { continue }
            seen.insert(en)

            var categories: [String] = []
            let enLower = en.lowercased()
            let heLower = he.lowercased()

            if enLower.contains("rashi") || enLower.contains("ramban") || enLower.contains("ibn ezra") ||
               enLower.contains("sforno") || enLower.contains("rashbam") || enLower.contains("radak") ||
               enLower.contains("commentary") || enLower.contains("collected") || enLower.contains("glosses") ||
               heLower.contains("פירוש") || heLower.contains("ליקוט") || heLower.contains("מפרש") ||
               heLower.contains("רש\"י") || heLower.contains("רמב\"ן") || heLower.contains("ראב\"ע") ||
               heLower.contains("אבן עזרא") || heLower.contains("ספורנו") || heLower.contains("רד\"ק") {
                categories.append("מפרשים")
                categories.append("Commentators")
            } else if enLower.contains("bavli") || enLower.contains("talmud") || heLower.contains("בבלי") {
                categories.append("ש\"ס")
                categories.append("Shas")
            } else if enLower.contains("mishnah") || enLower.contains("mishna") || heLower.contains("משנה") {
                categories.append("משנה")
                categories.append("Mishnah")
            } else if enLower.contains("tosefta") || heLower.contains("תוספתא") {
                categories.append("תוספתא")
                categories.append("Tosefta")
            } else if enLower.contains("yerushalmi") || heLower.contains("ירושלמי") {
                categories.append("ירושלמי")
                categories.append("Yerushalmi")
            } else if enLower.contains("rambam") || enLower.contains("mishneh torah") || heLower.contains("רמב\"ם") {
                categories.append("רמב\"ם")
                categories.append("Rambam")
            } else if enLower.contains("tur") || enLower.contains("shulchan") || heLower.contains("טור") || heLower.contains("שולחן ערוך") {
                categories.append("טור ושולחן ערוך")
                categories.append("Tur & Shulchan Arukh")
            } else {
                categories.append("תנ\"ך ומדרשים")
                categories.append("Tanakh & Midrash")
            }

            let searchable = "\(en) \(he) \(categories.joined(separator: " "))".lowercased()
            items.append(BookIndexItem(
                id: en,
                titleHe: he,
                titleEn: en,
                aliases: [he, en],
                categoryTitles: categories,
                sectionNames: [],
                searchableText: searchable
            ))
        }
        return items
    }
}
