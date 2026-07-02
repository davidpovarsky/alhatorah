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
        queue.async {
            let localDocument = self.readLocalRefPHP()
            let shouldDownload = forceDownload || localDocument == nil || self.shouldCheckRemote()

            guard shouldDownload else {
                if let localDocument {
                    completion(.success(localDocument))
                } else {
                    completion(.failure(RefPHPStoreError.missingLocalRef))
                }
                return
            }

            self.downloadRefPHP { result in
                switch result {
                case .success(let document):
                    completion(.success(document))
                case .failure(let error):
                    if let localDocument {
                        completion(.success(localDocument))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func readCachedBundle() -> BookIndexBundle? {
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(BookIndexBundle.self, from: data)
    }

    func writeCachedBundle(_ bundle: BookIndexBundle) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(bundle) {
            try? data.write(to: cacheFileURL, options: [.atomic])
        }
    }

    private func shouldCheckRemote() -> Bool {
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
        guard let lastCheck else { return true }
        return Date().timeIntervalSince(lastCheck) >= refreshInterval
    }

    private func readLocalRefPHP() -> RefPHPDocument? {
        guard let text = try? String(contentsOf: refFileURL, encoding: .utf8), !text.isEmpty else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: refFileURL.path)
        let modifiedAt = attributes?[.modificationDate] as? Date ?? .distantPast
        return RefPHPDocument(
            text: text,
            signature: Self.signature(for: text),
            downloadedAt: modifiedAt,
            source: .cached
        )
    }

    private func downloadRefPHP(completion: @escaping (Result<RefPHPDocument, Error>) -> Void) {
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                completion(.failure(RefPHPStoreError.badStatusCode(http.statusCode)))
                return
            }

            guard let data, let text = String(data: data, encoding: .utf8), !text.isEmpty else {
                completion(.failure(RefPHPStoreError.invalidData))
                return
            }

            do {
                try text.write(to: self.refFileURL, atomically: true, encoding: .utf8)
                UserDefaults.standard.set(Date(), forKey: self.lastCheckKey)
                completion(.success(RefPHPDocument(
                    text: text,
                    signature: Self.signature(for: text),
                    downloadedAt: Date(),
                    source: .downloaded
                )))
            } catch {
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
