import Foundation

final class RefPHPStore {
    static let shared = RefPHPStore()

    private let remoteURL = URL(string: "https://alhatorah.org/Home/ref.php")!
    private let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private let lastCheckKey = "aht_ref_last_check_at"
    private let queue = DispatchQueue(label: "com.davidpovarsky.alhatorah.refphp", qos: .utility)

    private init() {}

    var refFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("ref.php")
    }

    var cacheFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("aht-books-index-cache.json")
    }

    private var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("AlHaTorah", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func loadRefPHP(forceDownload: Bool, completion: @escaping (Result<RefPHPDocument, Error>) -> Void) {
        AppLogger.shared.log("loadRefPHP requested; forceDownload=\(forceDownload)")
        queue.async {
            let localDocument = self.readLocalRefPHP()
            let shouldDownload = forceDownload || localDocument == nil || self.shouldCheckRemote()
            AppLogger.shared.log("loadRefPHP state; hasLocal=\(localDocument != nil), shouldDownload=\(shouldDownload)")

            guard shouldDownload else {
                if let localDocument {
                    AppLogger.shared.log("Using cached local ref.php; signature=\(localDocument.signature)")
                    completion(.success(localDocument))
                } else {
                    AppLogger.shared.log("No local ref.php available")
                    completion(.failure(RefPHPStoreError.missingLocalRef))
                }
                return
            }

            self.downloadRefPHP { result in
                switch result {
                case .success(let document):
                    AppLogger.shared.log("Downloaded ref.php successfully; signature=\(document.signature)")
                    completion(.success(document))
                case .failure(let error):
                    AppLogger.shared.log("ref.php download failed: \(error.localizedDescription)")
                    if let localDocument {
                        AppLogger.shared.log("Falling back to cached ref.php; signature=\(localDocument.signature)")
                        completion(.success(localDocument))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func readCachedBundle() -> BookIndexBundle? {
        AppLogger.shared.log("Reading cached book index bundle from \(cacheFileURL.path)")
        guard let data = try? Data(contentsOf: cacheFileURL) else {
            AppLogger.shared.log("Cached book index bundle not found")
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bundle = try? decoder.decode(BookIndexBundle.self, from: data)
        AppLogger.shared.log("Cached book index decode result; success=\(bundle != nil), bytes=\(data.count)")
        return bundle
    }

    func writeCachedBundle(_ bundle: BookIndexBundle) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(bundle) {
            do {
                try data.write(to: cacheFileURL, options: [.atomic])
                AppLogger.shared.log("Wrote book index cache; items=\(bundle.booksIndex.count), bytes=\(data.count)")
            } catch {
                AppLogger.shared.log("Could not write book index cache: \(error.localizedDescription)")
            }
        } else {
            AppLogger.shared.log("Could not encode book index cache")
        }
    }

    private func shouldCheckRemote() -> Bool {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        guard let lastCheck else {
            AppLogger.shared.log("No previous ref.php check date; remote check needed")
            return true
        }
        let shouldCheck = Date().timeIntervalSince(lastCheck) >= refreshInterval
        AppLogger.shared.log("Weekly ref.php check evaluated; lastCheck=\(lastCheck), shouldCheck=\(shouldCheck)")
        return shouldCheck
    }

    private func readLocalRefPHP() -> RefPHPDocument? {
        guard let text = try? String(contentsOf: refFileURL, encoding: .utf8), !text.isEmpty else {
            AppLogger.shared.log("Local ref.php not available at \(refFileURL.path)")
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: refFileURL.path)
        let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
        let signature = Self.signature(for: text)
        AppLogger.shared.log("Read local ref.php; chars=\(text.count), signature=\(signature)")
        return RefPHPDocument(
            text: text,
            signature: signature,
            downloadedAt: modifiedAt,
            source: .cached
        )
    }

    private func downloadRefPHP(completion: @escaping (Result<RefPHPDocument, Error>) -> Void) {
        AppLogger.shared.log("Starting ref.php download from \(remoteURL.absoluteString)")
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                AppLogger.shared.log("ref.php URLSession error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                AppLogger.shared.log("ref.php HTTP error: \(http.statusCode)")
                completion(.failure(RefPHPStoreError.badStatusCode(http.statusCode)))
                return
            }

            AppLogger.shared.log("ref.php response received; bytes=\(data?.count ?? 0)")
            guard let data, let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                completion(.failure(RefPHPStoreError.invalidData))
                return
            }

            do {
                try text.write(to: self.refFileURL, atomically: true, encoding: .utf8)
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                let signature = Self.signature(for: text)
                AppLogger.shared.log("Saved ref.php to \(self.refFileURL.path); chars=\(text.count), signature=\(signature)")
                completion(.success(RefPHPDocument(
                    text: text,
                    signature: signature,
                    downloadedAt: Date(),
                    source: .downloaded
                )))
            } catch {
                AppLogger.shared.log("Failed saving ref.php: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    static func signature(for text: String) -> String {
        var hash: UInt32 = 2_166_136_261
        for scalar in text.unicodeScalars {
            hash ^= UInt32(scalar.value & 0xff)
            hash = hash &* 16_777_619
        }
        return "\(text.count):\(String(hash, radix: 16))"
    }
}

enum RefPHPStoreError: LocalizedError {
    case missingLocalRef
    case invalidData
    case badStatusCode(Int)

    var errorDescription: String? {
        switch self {
        case .missingLocalRef:
            return "ref.php is not available yet."
        case .invalidData:
            return "Downloaded ref.php was empty or unreadable."
        case .badStatusCode(let statusCode):
            return "ref.php download failed with HTTP \(statusCode)."
        }
    }
}