import Foundation

public enum AlHaTorahAPIError: LocalizedError {
    case notLoggedIn
    case badURL
    case httpError(statusCode: Int, message: String?)
    case invalidResponse
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Please log in to your AlHaTorah account."
        case .badURL:
            return "Invalid API URL."
        case .httpError(let code, let msg):
            return "Server error (\(code)): \(msg ?? "unknown")"
        case .invalidResponse:
            return "Invalid response from AlHaTorah."
        case .decodingError(let err):
            return "Data decoding failed: \(err.localizedDescription)"
        }
    }
}

public final class AlHaTorahAPIClient {
    public static let shared = AlHaTorahAPIClient()

    private let sessionStore: AlHaTorahSessionStore
    private let urlSession: URLSession

    public init(sessionStore: AlHaTorahSessionStore = .shared) {
        self.sessionStore = sessionStore
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Export / Whois

    public func whois() async throws -> String? {
        guard let url = URL(string: "https://users.alhatorah.org/json/whois") else {
            throw AlHaTorahAPIError.badURL
        }
        let (data, _) = try await performGet(url: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let email = json["email"] as? String, !email.isEmpty {
            return email
        }
        return nil
    }

    public func exportData() async throws -> AlHaTorahExportResponse {
        guard let url = URL(string: "https://users.alhatorah.org/json/export") else {
            throw AlHaTorahAPIError.badURL
        }
        let (data, _) = try await performGet(url: url)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = json["err"] as? String, err.lowercased().contains("login") {
            throw AlHaTorahAPIError.notLoggedIn
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(AlHaTorahExportResponse.self, from: data)
        } catch {
            throw AlHaTorahAPIError.decodingError(error)
        }
    }

    // MARK: - Chapter Annotations

    public func fetchAnnotations(mg: String, book: String, unit: String) async throws -> [AlHaTorahRawAnnotation] {
        var components = URLComponents(string: "https://users.alhatorah.org/json/data/get")
        let canonical = HebrewNames.canonicalMg(from: mg)
        components?.queryItems = [
            URLQueryItem(name: "type", value: "mg-all"),
            URLQueryItem(name: "mg", value: canonical),
            URLQueryItem(name: "book", value: book),
            URLQueryItem(name: "unit", value: unit)
        ]
        guard let url = components?.url else {
            throw AlHaTorahAPIError.badURL
        }
        let (data, _) = try await performGet(url: url)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([AlHaTorahRawAnnotation].self, from: data)
        } catch {
            throw AlHaTorahAPIError.decodingError(error)
        }
    }

    // MARK: - Dashboard History

    public func fetchDashboardHistory() async throws -> [AlHaTorahHistoryItem] {
        guard let url = URL(string: "https://users.alhatorah.org/dashboard") else {
            throw AlHaTorahAPIError.badURL
        }
        let (data, _) = try await performGet(url: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw AlHaTorahAPIError.invalidResponse
        }
        return AlHaTorahDashboardParser.parseHistory(from: html)
    }

    // MARK: - Bookmarks

    public func addBookmark(location: AlHaTorahLocation) async throws -> Bool {
        guard let url = URL(string: "https://users.alhatorah.org/json/bookmarks/add") else {
            throw AlHaTorahAPIError.badURL
        }
        var loc = location
        loc.mg = HebrewNames.canonicalMg(from: loc.mg)
        let body = loc.formUrlEncodedString(includeOffsets: false)
        let (data, _) = try await performPost(url: url, formBody: body)
        return isSuccessResponse(data)
    }

    public func removeBookmark(location: AlHaTorahLocation) async throws -> Bool {
        guard let url = URL(string: "https://users.alhatorah.org/json/bookmarks/remove") else {
            throw AlHaTorahAPIError.badURL
        }
        var loc = location
        loc.mg = HebrewNames.canonicalMg(from: loc.mg)
        let body = loc.formUrlEncodedString(includeOffsets: false)
        let (data, _) = try await performPost(url: url, formBody: body)
        return isSuccessResponse(data)
    }

    // MARK: - Generic Data Remove (for bookmarks, notes, highlights, history)

    public func removeData(id: String) async throws -> Bool {
        guard let url = URL(string: "https://users.alhatorah.org/json/data/remove") else {
            throw AlHaTorahAPIError.badURL
        }
        let body = FormURLEncoder.encode([("id", id)])
        let (data, _) = try await performPost(url: url, formBody: body)
        return isSuccessResponse(data)
    }

    // MARK: - Notes (Gilayon)

    public func createNote(
        title: String,
        content: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int = 0,
        end: Int = 0
    ) async throws -> AlHaTorahNote {
        guard let url = URL(string: "https://users.alhatorah.org/json/data/add") else {
            throw AlHaTorahAPIError.badURL
        }

        var loc = location
        loc.mg = HebrewNames.canonicalMg(from: loc.mg)
        loc.paragraph = paragraph
        loc.begin = begin
        loc.end = end

        let formattedContent: String
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<p") {
            formattedContent = content
        } else {
            formattedContent = "<p dir=\"rtl\">\(content)</p>"
        }

        let params: [(String, String)] = [
            ("dataType", "gilayon"),
            ("title", title),
            ("content", formattedContent),
            ("type", loc.type),
            ("mg", loc.mg),
            ("book", loc.book),
            ("unit", loc.unit),
            ("subUnit", String(loc.subUnit)),
            ("parshan", loc.parshan),
            ("paragraph", String(paragraph ?? 0)),
            ("begin", String(begin)),
            ("end", String(end))
        ]

        let body = FormURLEncoder.encode(params)
        let (data, _) = try await performPost(url: url, formBody: body)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let noteDict = json["data"] as? [String: Any],
           let id = noteDict["_id"] as? String {
            return AlHaTorahNote(
                id: id,
                dataType: "gilayon",
                title: title,
                content: formattedContent,
                paragraph: paragraph,
                begin: begin,
                end: end,
                type: loc.type,
                location: loc
            )
        }

        throw AlHaTorahAPIError.invalidResponse
    }

    public func editNote(id: String, content: String) async throws -> Bool {
        guard let url = URL(string: "https://users.alhatorah.org/json/data/edit") else {
            throw AlHaTorahAPIError.badURL
        }
        let formattedContent: String
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<p") {
            formattedContent = content
        } else {
            formattedContent = "<p dir=\"rtl\">\(content)</p>"
        }
        let body = FormURLEncoder.encode([
            ("id", id),
            ("dataType", "gilayon"),
            ("content", formattedContent)
        ])
        let (data, _) = try await performPost(url: url, formBody: body)
        return isSuccessResponse(data)
    }

    // MARK: - Highlights

    public func addHighlight(
        color: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int,
        end: Int
    ) async throws -> AlHaTorahHighlight {
        guard let url = URL(string: "https://users.alhatorah.org/json/data/add") else {
            throw AlHaTorahAPIError.badURL
        }

        var loc = location
        loc.mg = HebrewNames.canonicalMg(from: loc.mg)
        loc.paragraph = paragraph
        loc.begin = begin
        loc.end = end

        let params: [(String, String)] = [
            ("dataType", "highlight"),
            ("color", color),
            ("type", loc.type),
            ("mg", loc.mg),
            ("book", loc.book),
            ("unit", loc.unit),
            ("subUnit", String(loc.subUnit)),
            ("parshan", loc.parshan),
            ("paragraph", String(paragraph ?? 0)),
            ("begin", String(begin)),
            ("end", String(end))
        ]

        let body = FormURLEncoder.encode(params)
        let (data, _) = try await performPost(url: url, formBody: body)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let itemDict = json["data"] as? [String: Any],
           let id = itemDict["_id"] as? String {
            return AlHaTorahHighlight(
                id: id,
                dataType: "highlight",
                color: color,
                paragraph: paragraph,
                begin: begin,
                end: end,
                type: loc.type,
                location: loc
            )
        }

        throw AlHaTorahAPIError.invalidResponse
    }

    public func changeHighlightColor(
        oldId: String,
        newColor: String,
        location: AlHaTorahLocation,
        paragraph: Int? = nil,
        begin: Int,
        end: Int
    ) async throws -> AlHaTorahHighlight {
        _ = try await removeData(id: oldId)
        return try await addHighlight(
            color: newColor,
            location: location,
            paragraph: paragraph,
            begin: begin,
            end: end
        )
    }

    // MARK: - History Recording

    public func recordHistory(location: AlHaTorahLocation) async throws -> Bool {
        guard let url = URL(string: "https://users.alhatorah.org/json/data/add") else {
            throw AlHaTorahAPIError.badURL
        }
        var loc = location
        loc.mg = HebrewNames.canonicalMg(from: loc.mg)
        let params = [
            ("dataType", "history"),
            ("type", loc.type),
            ("mg", loc.mg),
            ("book", loc.book),
            ("unit", loc.unit),
            ("subUnit", String(loc.subUnit)),
            ("parshan", loc.parshan)
        ]
        let body = FormURLEncoder.encode(params)
        let (data, _) = try await performPost(url: url, formBody: body)
        return isSuccessResponse(data)
    }

    // MARK: - Private Helpers

    private func performGet(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        await attachSessionCookie(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlHaTorahAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8)
            throw AlHaTorahAPIError.httpError(statusCode: http.statusCode, message: msg)
        }
        return (data, http)
    }

    private func performPost(url: URL, formBody: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody.data(using: .utf8)
        await attachSessionCookie(to: &request)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AlHaTorahAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8)
            throw AlHaTorahAPIError.httpError(statusCode: http.statusCode, message: msg)
        }
        return (data, http)
    }

    private func attachSessionCookie(to request: inout URLRequest) async {
        let cookies = await sessionStore.fetchSessionCookies()
        if !cookies.isEmpty {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (field, value) in headers {
                request.setValue(value, forHTTPHeaderField: field)
            }
        }
    }

    private func isSuccessResponse(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if let success = json["success"] as? String, !success.isEmpty {
            return true
        }
        if let removed = json["removed"] as? Int, removed > 0 {
            return true
        }
        return false
    }
}
