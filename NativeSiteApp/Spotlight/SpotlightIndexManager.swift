import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

final class SpotlightIndexManager {
    static let shared = SpotlightIndexManager()

    private let queue = DispatchQueue(label: "com.davidpovarsky.alhatorah.spotlight", qos: .utility)
    private let domainIdentifier = "com.davidpovarsky.alhatorah.books"
    private let spotlightSignatureKey = "aht_spotlight_signature"
    private let spotlightIDPrefix = "aht-book:"
    private let batchSize = 250

    private init() {}

    func refreshIfNeeded(force: Bool = false, completion: ((Result<SpotlightRefreshSummary, Error>) -> Void)? = nil) {
        AppLogger.shared.log("Spotlight refresh started; force=\(force)")
        RefPHPStore.shared.loadRefPHP(forceDownload: force) { result in
            switch result {
            case .failure(let error):
                AppLogger.shared.log("Spotlight refresh failed while loading ref.php: \(error.localizedDescription)")
                completion?(.failure(error))
            case .success(let document):
                self.queue.async {
                    do {
                        AppLogger.shared.log("Spotlight refresh loading/building bundle; refSignature=\(document.signature), source=\(document.source.rawValue)")
                        let bundle = try self.loadOrBuildBundle(document: document)
                        AppLogger.shared.log("Book index bundle ready; itemCount=\(bundle.booksIndex.count)")
                        let signature = self.spotlightSignature(refSignature: document.signature, itemCount: bundle.booksIndex.count)
                        let storedSignature = UserDefaults.standard.string(forKey: self.spotlightSignatureKey) ?? ""

                        if !force && storedSignature == signature {
                            AppLogger.shared.log("Spotlight already up to date; signature=\(signature)")
                            completion?(.success(SpotlightRefreshSummary(
                                itemCount: bundle.booksIndex.count,
                                indexedCount: 0,
                                skipped: true,
                                source: document.source,
                                signature: signature,
                                message: "Spotlight already up to date"
                            )))
                            return
                        }

                        self.index(bundle.booksIndex, signature: signature, source: document.source, completion: completion)
                    } catch {
                        AppLogger.shared.log("Spotlight refresh failed while building index: \(error.localizedDescription)")
                        completion?(.failure(error))
                    }
                }
            }
        }
    }

    func deleteAllSpotlightItems(completion: ((Result<Void, Error>) -> Void)? = nil) {
        AppLogger.shared.log("Deleting Spotlight items for domain=\(domainIdentifier)")
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error {
                AppLogger.shared.log("Deleting Spotlight items failed: \(error.localizedDescription)")
                completion?(.failure(error))
            } else {
                AppLogger.shared.log("Deleted Spotlight items successfully")
                UserDefaults.standard.removeObject(forKey: self.spotlightSignatureKey)
                completion?(.success(()))
            }
        }
    }

    func urlForSpotlightIdentifier(_ identifier: String, completion: @escaping (URL?) -> Void) {
        AppLogger.shared.log("Resolving Spotlight identifier: \(identifier)")
        guard let bookId = bookId(from: identifier) else {
            AppLogger.shared.log("Spotlight identifier was not an AlHaTorah book identifier")
            completion(nil)
            return
        }

        queue.async {
            let cachedItem = RefPHPStore.shared.readCachedBundle()?.booksIndex.first { $0.id == bookId }
            let basicCandidates = self.openingCandidates(for: cachedItem, fallbackBookId: bookId)
            AppLogger.shared.log("Resolving bookId=\(bookId); candidates=\(basicCandidates.prefix(8).joined(separator: " | "))")

            RefPHPStore.shared.loadRefPHP(forceDownload: false) { result in
                switch result {
                case .failure(let error):
                    AppLogger.shared.log("Could not load ref.php for Spotlight open: \(error.localizedDescription)")
                    completion(nil)
                case .success(let document):
                    self.queue.async {
                        do {
                            AppLogger.shared.log("Creating JS engine to resolve Spotlight open URL")
                            let engine = try AHTJavaScriptEngine(refPHP: document.text)
                            if let url = engine.resolveReferenceURL(candidates: basicCandidates) {
                                AppLogger.shared.log("Resolved Spotlight URL: \(url.absoluteString)")
                                completion(url)
                            } else {
                                AppLogger.shared.log("Could not resolve Spotlight URL for bookId=\(bookId)")
                                completion(nil)
                            }
                        } catch {
                            AppLogger.shared.log("Spotlight URL resolve failed: \(error.localizedDescription)")
                            completion(nil)
                        }
                    }
                }
            }
        }
    }

    private func loadOrBuildBundle(document: RefPHPDocument) throws -> BookIndexBundle {
        if let cached = RefPHPStore.shared.readCachedBundle(), cached.signature == document.signature {
            AppLogger.shared.log("Using cached book index bundle; items=\(cached.booksIndex.count)")
            return cached
        }

        AppLogger.shared.log("No matching cached book index bundle; creating JS engine")
        let engine = try AHTJavaScriptEngine(refPHP: document.text)
        AppLogger.shared.log("JS engine created; building book index bundle")
        let builder = BookIndexBuilder(engine: engine)
        let bundle = builder.buildBundle(signature: document.signature)
        AppLogger.shared.log("Book index builder finished; items=\(bundle.booksIndex.count)")
        RefPHPStore.shared.writeCachedBundle(bundle)
        return bundle
    }

    private func index(
        _ items: [BookIndexItem],
        signature: String,
        source: RefPHPSource,
        completion: ((Result<SpotlightRefreshSummary, Error>) -> Void)?
    ) {
        AppLogger.shared.log("Preparing \(items.count) Spotlight searchable items")
        let searchableItems = items.map(makeSearchableItem)
        var indexedCount = 0

        func indexNextBatch(start: Int) {
            if start >= searchableItems.count {
                UserDefaults.standard.set(signature, forKey: self.spotlightSignatureKey)
                AppLogger.shared.log("Spotlight indexing finished; indexed=\(indexedCount), signature=\(signature)")
                completion?(.success(SpotlightRefreshSummary(
                    itemCount: items.count,
                    indexedCount: indexedCount,
                    skipped: false,
                    source: source,
                    signature: signature,
                    message: "Spotlight index updated"
                )))
                return
            }

            let end = min(start + batchSize, searchableItems.count)
            let batch = Array(searchableItems[start..<end])
            AppLogger.shared.log("Indexing Spotlight batch \(start)-\(end) of \(searchableItems.count)")
            CSSearchableIndex.default().indexSearchableItems(batch) { error in
                if let error {
                    AppLogger.shared.log("Spotlight batch failed at start=\(start): \(error.localizedDescription)")
                    completion?(.failure(error))
                    return
                }
                indexedCount += batch.count
                AppLogger.shared.log("Spotlight batch completed; indexedCount=\(indexedCount)")
                indexNextBatch(start: end)
            }
        }

        indexNextBatch(start: 0)
    }

    private func makeSearchableItem(from item: BookIndexItem) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        let categories = item.categoryTitles.joined(separator: " â€º ")
        let sectionNames = item.sectionNames.joined(separator: " â€º ")
        let aliases = compact([item.titleHe, item.titleEn, item.id] + item.aliases, limit: 20)
        let keywords = compact(item.categoryTitles + item.sectionNames + item.aliases, limit: 40)

        attributeSet.title = item.titleHe
        attributeSet.displayName = item.titleHe
        attributeSet.alternateNames = aliases
        attributeSet.contentDescription = compact([item.titleEn, categories, sectionNames], limit: 3).joined(separator: "\n")
        attributeSet.kind = "AlHaTorah source"
        attributeSet.keywords = keywords
        attributeSet.textContent = compact([item.titleHe, item.titleEn, item.id, item.searchableText] + item.aliases, limit: 12).joined(separator: " ")

        return CSSearchableItem(
            uniqueIdentifier: spotlightIdentifier(for: item.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }

    private func spotlightSignature(refSignature: String, itemCount: Int) -> String {
        "\(refSignature):\(itemCount):native-spotlight"
    }

    func spotlightIdentifier(for bookId: String) -> String {
        let encoded = bookId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? bookId
        return "\(spotlightIDPrefix)\(encoded)"
    }

    private func bookId(from identifier: String) -> String? {
        guard identifier.hasPrefix(spotlightIDPrefix) else { return nil }
        let encoded = String(identifier.dropFirst(spotlightIDPrefix.count))
        return encoded.removingPercentEncoding ?? encoded
    }

    private func openingCandidates(for item: BookIndexItem?, fallbackBookId: String) -> [String] {
        guard let item else {
            return [fallbackBookId, "\(fallbackBookId) 1"]
        }

        let hasSections = !item.sectionNames.isEmpty
        var candidates = [
            item.titleHe,
            hasSections ? "\(item.titleHe) 1" : "",
            item.id,
            hasSections ? "\(item.id) 1" : "",
            item.titleEn,
            hasSections ? "\(item.titleEn) 1" : ""
        ]

        for alias in item.aliases {
            candidates.append(alias)
            if hasSections { candidates.append("\(alias) 1") }
        }

        return compact(candidates, limit: 40)
    }

    private func compact(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            result.append(cleaned)
            if result.count >= limit { break }
        }
        return result
    }
}