import Foundation

struct BookIndexBuilder {
    private let engine: AHTJavaScriptEngine
    private let aliasesLimit = 30
    private let displayAliasesLimit = 10
    private let maxCategoryDepth = 6
    private let controlKeys: Set<String> = [
        "he", "en", "ref", "branch", "seriesData", "inDatabase", "isLeaf",
        "tooltip", "data", "url", "href"
    ]

    init(engine: AHTJavaScriptEngine) {
        self.engine = engine
    }

    func buildBundle(signature: String) -> BookIndexBundle {
        let booksIndex = buildBooksIndex()
        let booksTree = buildBooksTree(index: booksIndex)
        return BookIndexBundle(
            signature: signature,
            createdAt: Date(),
            booksIndex: booksIndex,
            booksTree: booksTree
        )
    }

    private func buildBooksIndex() -> [BookIndexItem] {
        let aliasesBySource = buildAliasesBySource()
        let branches = engine.branches
        let data = engine.data
        var items: [BookIndexItem] = []
        var seen = Set<String>()

        func addBook(key: String, value: [String: Any], path: [String]) {
            let id = nodeEnglishTitle(key: key, value: value)
            guard !id.isEmpty, !seen.contains(id) else { return }

            let titleHe = nodeTitle(key: key, value: value)
            let titleEn = nodeEnglishTitle(key: key, value: value)
            guard !titleHe.isEmpty, !titleEn.isEmpty else { return }

            let sourceData = dictionary(data[id])
            let rawAliases = uniqueCleaned([
                id,
                titleHe,
                titleEn
            ] + safeArray(sourceData["variants"]) + safeArray(sourceData["allVariants"]) + safeArray(sourceData["otherNames"]) + Array(aliasesBySource[id] ?? []))

            let sectionNames = safeArray(sourceData["sectionNames"])
            let categoryTitles = compactPath(path)
            let searchableText = normalizeSearchText(
                ([id, titleHe, titleEn] + categoryTitles + Array(rawAliases.prefix(aliasesLimit)) + sectionNames).joined(separator: " ")
            )

            seen.insert(id)
            items.append(BookIndexItem(
                id: id,
                titleHe: titleHe,
                titleEn: titleEn,
                aliases: Array(rawAliases.prefix(displayAliasesLimit)),
                categoryTitles: categoryTitles,
                sectionNames: sectionNames,
                searchableText: searchableText
            ))
        }

        func addBookFromData(id: String, sourceData: [String: Any]) {
            guard !id.isEmpty, !seen.contains(id) else { return }
            if bool(sourceData["baseOnly"]) == true || bool(sourceData["branch"]) == false { return }

            let titleStarts = dictionary(sourceData["titleStarts"])
            let titleHe = cleanTitle(string(sourceData["he"]) ?? string(titleStarts["he"]))
            let titleEn = cleanTitle(string(titleStarts["en"]) ?? string(sourceData["en"]) ?? id)
            guard !titleHe.isEmpty, !titleEn.isEmpty else { return }

            let sectionNames = safeArray(sourceData["sectionNames"])
            guard !sectionNames.isEmpty else { return }
            guard engine.expandedSectionCount(for: id) > 0 else { return }

            let categories = array(sourceData["categories"]).map { cleanTitle(string($0)) }.filter { !$0.isEmpty }
            let categoryTitles = compactPath([
                cleanTitle(string(sourceData["branch"])),
                cleanTitle(string(sourceData["subbranch"]))
            ] + categories)

            let original = dictionary(sourceData["original"])
            let originalAliases = [string(original["he"]), string(original["en"])].compactMap { $0 }
            let rawAliases = uniqueCleaned([
                id,
                titleHe,
                titleEn
            ] + originalAliases + safeArray(sourceData["variants"]) + safeArray(sourceData["allVariants"]) + safeArray(sourceData["otherNames"]) + Array(aliasesBySource[id] ?? []))

            let searchableText = normalizeSearchText(
                ([id, titleHe, titleEn] + categoryTitles + Array(rawAliases.prefix(aliasesLimit)) + sectionNames).joined(separator: " ")
            )

            seen.insert(id)
            items.append(BookIndexItem(
                id: id,
                titleHe: titleHe,
                titleEn: titleEn,
                aliases: Array(rawAliases.prefix(displayAliasesLimit)),
                categoryTitles: categoryTitles,
                sectionNames: sectionNames,
                searchableText: searchableText
            ))
        }

        func traverse(_ object: [String: Any], path: [String]) {
            for (key, rawValue) in object {
                guard !controlKeys.contains(key), !shouldSkipGroupKey(key), let value = rawValue as? [String: Any] else { continue }

                if isBookLeaf(key: key, value: value) {
                    addBook(key: key, value: value, path: path)
                    continue
                }

                let title = nodeTitle(key: key, value: value)
                traverse(value, path: title.isEmpty ? path : path + [title])
            }
        }

        traverse(branches, path: [])

        for (id, sourceData) in data {
            addBookFromData(id: id, sourceData: dictionary(sourceData))
        }

        return items.sorted { $0.titleHe.localizedStandardCompare($1.titleHe) == .orderedAscending }
    }

    private func buildBooksTree(index: [BookIndexItem]) -> BookTreeNode {
        var root = BookTreeNode(id: "root", title: "עץ הספרים", subtitle: nil, children: [], item: nil, bookCount: 0)

        for item in index {
            let path = item.categoryTitles.isEmpty ? ["ללא קטגוריה"] : item.categoryTitles
            insert(item: item, path: path, into: &root)
        }

        _ = sortAndCount(node: &root)
        return root
    }

    private func insert(item: BookIndexItem, path: [String], into node: inout BookTreeNode) {
        guard let first = path.first else {
            node.children.append(BookTreeNode(
                id: "book-\(item.id)",
                title: item.titleHe,
                subtitle: item.titleEn,
                children: [],
                item: item,
                bookCount: 1
            ))
            return
        }

        let groupId = "group-\(first)"
        if let index = node.children.firstIndex(where: { $0.item == nil && $0.id == groupId }) {
            insert(item: item, path: Array(path.dropFirst()), into: &node.children[index])
        } else {
            var child = BookTreeNode(id: groupId, title: first, subtitle: nil, children: [], item: nil, bookCount: 0)
            insert(item: item, path: Array(path.dropFirst()), into: &child)
            node.children.append(child)
        }
    }

    private func sortAndCount(node: inout BookTreeNode) -> Int {
        var count = node.item == nil ? 0 : 1
        for index in node.children.indices {
            count += sortAndCount(node: &node.children[index])
        }
        node.bookCount = count
        node.children.sort { left, right in
            if left.item == nil && right.item != nil { return true }
            if left.item != nil && right.item == nil { return false }
            return left.title.localizedStandardCompare(right.title) == .orderedAscending
        }
        return count
    }

    private func buildAliasesBySource() -> [String: Set<String>] {
        var aliasesBySource: [String: Set<String>] = [:]
        let map = engine.aliasesMap

        for (aliasRaw, sourceRaw) in map {
            let source = cleanTitle(string(sourceRaw))
            let alias = cleanTitle(aliasRaw)
            guard !source.isEmpty, !alias.isEmpty else { continue }
            var set = aliasesBySource[source] ?? []
            if set.count < aliasesLimit { set.insert(alias) }
            aliasesBySource[source] = set
        }

        return aliasesBySource
    }

    private func nodeTitle(key: String, value: [String: Any]) -> String {
        if let title = string(value["he"]) { return cleanTitle(title) }
        let seriesData = dictionary(value["seriesData"])
        if let title = string(seriesData["he"]) { return cleanTitle(title) }
        return cleanTitle(key)
    }

    private func nodeEnglishTitle(key: String, value: [String: Any]) -> String {
        let seriesData = dictionary(value["seriesData"])
        if let title = string(seriesData["en"]) { return cleanTitle(title) }
        if let title = string(value["en"]) { return cleanTitle(title) }
        return cleanTitle(key)
    }

    private func shouldSkipGroupKey(_ key: String) -> Bool {
        key == "neutral" || key == "By Parashah"
    }

    private func isBookLeaf(key: String, value: [String: Any]) -> Bool {
        if bool(value["ref"]) == true { return true }
        if bool(value["isLeaf"]) == true {
            let seriesData = dictionary(value["seriesData"])
            return string(seriesData["en"]) != nil || string(value["en"]) != nil || string(value["he"]) != nil
        }
        return false
    }

    private func compactPath(_ path: [String]) -> [String] {
        var result: [String] = []
        for part in path.map { cleanTitle($0) }.filter { !$0.isEmpty } {
            if result.last != part { result.append(part) }
            if result.count >= maxCategoryDepth { break }
        }
        return result
    }

    private func uniqueCleaned(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let cleaned = cleanTitle(value)
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            result.append(cleaned)
        }
        return result
    }

    private func safeArray(_ value: Any?) -> [String] {
        array(value).map { cleanTitle(string($0)) }.filter { !$0.isEmpty }
    }

    private func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    private func array(_ value: Any?) -> [Any] {
        value as? [Any] ?? []
    }

    private func string(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func bool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private func cleanTitle(_ value: String?) -> String {
        stripHTML(value ?? "")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ input: String) -> String {
        input.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
    }

    private func normalizeSearchText(_ input: String) -> String {
        cleanTitle(input)
            .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: Locale(identifier: "he"))
            .replacingOccurrences(of: "[\u{0591}-\u{05C7}]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[״׳\"'`]", with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
