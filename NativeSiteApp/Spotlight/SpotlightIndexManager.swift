import CoreSpotlight
import Foundation
import UniformTypeIdentifiers
import UIKit

final class SpotlightIndexManager {
    static let shared = SpotlightIndexManager()

    private let queue = DispatchQueue(label: "com.davidpovarsky.alhatorah.spotlight", qos: .utility)
    private let stateQueue = DispatchQueue(label: "com.davidpovarsky.alhatorah.spotlight.state")
    private let domainIdentifier = "com.davidpovarsky.alhatorah.books"
    private let spotlightSignatureKey = "aht_spotlight_signature"
    private let spotlightIDPrefix = "aht-book:"
    private let batchSize = 250
    private let thumbnailData = UIImage(named: "SpotlightIcon")?.pngData()

    private var isRefreshing = false

    private init() {}

    func refreshIfNeeded(force: Bool = false, completion: ((Result<SpotlightRefreshSummary, Error>) -> Void)? = nil) {
        guard beginRefresh() else {
            AppLogger.shared.log("Spotlight refresh ignored because another refresh is already running")
            completion?(.success(SpotlightRefreshSummary(
                itemCount: 0,
                indexedCount: 0,
                skipped: true,
                source: .cached,
                signature: "in-progress",
                message: AppLocalization.text("settings.spotlight.in_progress", "Spotlight indexing is already in progress")
            )))
            return
        }

        AppLogger.shared.log("Spotlight refresh started; force=\(force)")
        let finish: (Result<SpotlightRefreshSummary, Error>) -> Void = { [weak self] result in
            self?.endRefresh()
            completion?(result)
        }

        RefPHPStore.shared.loadRefPHP(forceDownload: force) { result in
            switch result {
            case .failure(let error):
                AppLogger.shared.log("Spotlight refresh failed while loading ref.php: \(error.localizedDescription)")
                finish(.failure(error))
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
                            finish(.success(SpotlightRefreshSummary(
                                itemCount: bundle.booksIndex.count,
                                indexedCount: 0,
                                skipped: true,
                                source: document.source,
                                signature: signature,
                                message: "Spotlight already up to date"
                            )))
                            return
                        }

                        self.index(bundle.booksIndex, signature: signature, source: document.source, completion: finish)
                    } catch {
                        AppLogger.shared.log("Spotlight refresh failed while building index: \(error.localizedDescription)")
                        finish(.failure(error))
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

    private func beginRefresh() -> Bool {
        stateQueue.sync {
            if isRefreshing { return false }
            isRefreshing = true
            return true
        }
    }

    private func endRefresh() {
        stateQueue.sync {
            isRefreshing = false
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
        let primaryTitle = localizedPrimaryTitle(for: item)
        let alternateTitle = localizedAlternateTitle(for: item)
        let aliases = compact([alternateTitle, item.titleHe, item.titleEn, item.id] + item.aliases, limit: 24)
        let keywords = compact([item.titleHe, item.titleEn, item.id] + item.categoryTitles + item.sectionNames + item.aliases, limit: 60)

        attributeSet.title = primaryTitle
        attributeSet.displayName = primaryTitle
        attributeSet.alternateNames = aliases
        attributeSet.contentDescription = localizedSpotlightDescription(for: item)
        attributeSet.kind = AppLocalization.text("spotlight.kind", "AlHaTorah source")
        attributeSet.keywords = keywords
        attributeSet.textContent = compact([item.titleHe, item.titleEn, item.id, item.searchableText] + item.categoryTitles + item.sectionNames + item.aliases, limit: 30).joined(separator: " ")
        attributeSet.thumbnailData = thumbnailData

        return CSSearchableItem(
            uniqueIdentifier: spotlightIdentifier(for: item.id),
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }

    private func localizedPrimaryTitle(for item: BookIndexItem) -> String {
        if AppLocalization.isHebrew {
            return item.titleHe.isEmpty ? item.titleEn : item.titleHe
        }
        return item.titleEn.isEmpty ? item.titleHe : item.titleEn
    }

    private func localizedAlternateTitle(for item: BookIndexItem) -> String {
        if AppLocalization.isHebrew {
            return item.titleEn.isEmpty ? item.id : item.titleEn
        }
        return item.titleHe.isEmpty ? item.id : item.titleHe
    }

    private func localizedSpotlightDescription(for item: BookIndexItem) -> String {
        if AppLocalization.isHebrew {
            return AppLocalization.text("spotlight.description.he", "מקור בספריית על־התורה")
        }
        return AppLocalization.text("spotlight.description.en", "AlHaTorah library source")
    }

    private func spotlightSignature(refSignature: String, itemCount: Int) -> String {
        "\(refSignature):\(itemCount):native-spotlight-localized-v2"
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
