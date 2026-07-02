import Foundation

final class AppLogger {
    static let shared = AppLogger()

    private let queue = DispatchQueue(label: "com.davidpovarsky.alhatorah.diagnostics", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = formatter
        ensureLogFileExists()
    }

    var logFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("AlHaTorah", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("diagnostic-log.txt")
    }

    func log(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(file):\(line) \(function) - \(message)\n"

        queue.async {
            self.trimIfNeeded()
            self.append(entry)
        }
    }

    func logSync(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(file):\(line) \(function) - \(message)\n"

        queue.sync {
            self.trimIfNeeded()
            self.append(entry)
        }
    }

    func readLog() -> String {
        (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
    }

    func clear() {
        queue.async {
            try? "".write(to: self.logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func ensureLogFileExists() {
        let url = logFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func append(_ entry: String) {
        ensureLogFileExists()
        guard let data = entry.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: logFileURL) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? entry.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private func trimIfNeeded() {
        let url = logFileURL
        let maxSize = 600_000
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber,
            size.intValue > maxSize,
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return }

        let suffix = String(text.suffix(300_000))
        try? suffix.write(to: url, atomically: true, encoding: .utf8)
    }
}
