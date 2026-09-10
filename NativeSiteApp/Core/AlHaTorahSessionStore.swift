import Foundation
import WebKit

public final class AlHaTorahSessionStore: NSObject, ObservableObject, WKHTTPCookieStoreObserver {
    public static let shared = AlHaTorahSessionStore()

    @Published public private(set) var isLoggedIn: Bool = false
    @Published public private(set) var userEmail: String? = nil
    @Published public private(set) var isCheckingSession: Bool = false
    @Published public private(set) var lastValidatedAt: Date? = nil

    private let cookieStore: WKHTTPCookieStore
    private let urlSession: URLSession

    public init(cookieStore: WKHTTPCookieStore = WKWebsiteDataStore.default().httpCookieStore) {
        self.cookieStore = cookieStore
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        self.urlSession = URLSession(configuration: configuration)
        super.init()
        self.cookieStore.add(self)
        Task {
            await self.validateSession()
        }
    }

    deinit {
        cookieStore.remove(self)
    }

    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in
            await self.validateSession()
        }
    }

    public func fetchSessionCookie() async -> HTTPCookie? {
        await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { cookies in
                let session = cookies.first { cookie in
                    cookie.name == "connect.sid" &&
                    (cookie.domain == "users.alhatorah.org" ||
                     cookie.domain == ".alhatorah.org" ||
                     cookie.domain.contains("alhatorah.org"))
                }
                continuation.resume(returning: session)
            }
        }
    }

    @MainActor
    public func validateSession() async {
        isCheckingSession = true
        defer { isCheckingSession = false }

        guard let cookie = await fetchSessionCookie() else {
            isLoggedIn = false
            userEmail = nil
            lastValidatedAt = Date()
            return
        }

        guard let whoisURL = URL(string: "https://users.alhatorah.org/json/whois") else { return }
        var request = URLRequest(url: whoisURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let headers = HTTPCookie.requestHeaderFields(with: [cookie])
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                isLoggedIn = false
                userEmail = nil
                lastValidatedAt = Date()
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let email = json["email"] as? String, !email.isEmpty {
                    self.isLoggedIn = true
                    self.userEmail = email
                } else {
                    self.isLoggedIn = false
                    self.userEmail = nil
                }
            } else {
                self.isLoggedIn = false
                self.userEmail = nil
            }
        } catch {
            // Network error: don't wipe out logged in status if we have the cookie and it's a transient connection failure
            AppLogger.shared.log("Session validation failed: \(error.localizedDescription)")
        }
        lastValidatedAt = Date()
    }

    public func logOut() async {
        await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self else {
                    continuation.resume()
                    return
                }
                let group = DispatchGroup()
                for cookie in cookies where cookie.domain.contains("alhatorah.org") {
                    group.enter()
                    self.cookieStore.delete(cookie) {
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.isLoggedIn = false
                    self.userEmail = nil
                    continuation.resume()
                }
            }
        }
    }
}
