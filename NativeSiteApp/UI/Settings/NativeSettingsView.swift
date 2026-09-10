import SwiftUI
import WebKit

public struct NativeSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sessionStore: AlHaTorahSessionStore = .shared
    @ObservedObject var dataStore: AlHaTorahDataStore = .shared
    @ObservedObject var coordinator: AppCoordinator = .shared

    @State private var homeURLString: String
    @State private var allowedDomainsString: String

    @State private var showingSpotlightProgress = false
    @State private var spotlightMessage: String?
    @State private var showingDeleteSpotlightAlert = false
    @State private var showingClearHistoryAlert = false
    @State private var showingClearWebsiteDataAlert = false
    @State private var showingResetAlert = false
    @State private var showingLogOutAlert = false
    @State private var statusToast: String?

    public init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        _homeURLString = State(initialValue: settingsStore.settings.homeURLString)
        _allowedDomainsString = State(initialValue: settingsStore.settings.allowedDomains.joined(separator: "\n"))
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section: AlHaTorah Account
                Section(header: Text(AppLocalization.text("settings.section.account", "חשבון על־התורה")),
                        footer: Text(AppLocalization.text("settings.footer.account", "ההתחברות מתבצעת דרך קורא על־התורה ומסנכרנת אוטומטית סימניות, הערות, הדגשות והיסטוריה."))) {
                    HStack {
                        Image(systemName: sessionStore.isLoggedIn ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                            .foregroundColor(sessionStore.isLoggedIn ? .green : .secondary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sessionStore.isLoggedIn ? (sessionStore.userEmail ?? "מחובר") : AppLocalization.text("settings.account.not_logged_in", "לא מחובר"))
                                .font(.headline)
                            Text(sessionStore.isLoggedIn
                                 ? AppLocalization.text("settings.account.status_connected", "מחובר ל־users.alhatorah.org")
                                 : AppLocalization.text("settings.account.status_disconnected", "התחבר כדי לגשת לסימניות ולהערות שלך"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if sessionStore.isLoggedIn {
                        Button {
                            Task {
                                await dataStore.syncAll()
                                showToast(AppLocalization.text("settings.account.synced", "הנתונים סונכרנו בהצלחה"))
                            }
                        } label: {
                            Label(AppLocalization.text("settings.account.sync_now", "סנכרן נתונים עכשיו"), systemImage: "arrow.triangle.2.circlepath")
                        }

                        Button(role: .destructive) {
                            showingLogOutAlert = true
                        } label: {
                            Label(AppLocalization.text("settings.account.logout", "התנתק"), systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button {
                            if let loginURL = URL(string: "https://users.alhatorah.org/login") {
                                coordinator.openInReader(url: loginURL)
                            }
                        } label: {
                            Label(AppLocalization.text("settings.account.login_via_reader", "התחבר דרך הקורא"), systemImage: "arrow.up.right.square")
                        }
                    }
                }

                // Section: Website
                Section(header: Text(AppLocalization.text("settings.section.website", "אתר")),
                        footer: Text(AppLocalization.text("settings.footer.website", "עריכת דף הבית והדומיינים המורשים. דומיין אחד בכל שורה."))) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.text("settings.website.home_url", "כתובת דף הבית"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("https://alhatorah.org/", text: $homeURLString)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: homeURLString) { newValue in
                                let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                settingsStore.update {
                                    $0.homeURLString = cleaned.isEmpty ? AppSettings.defaultHomeURLString : cleaned
                                }
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppLocalization.text("settings.website.allowed_domains", "דומיינים מורשים"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $allowedDomainsString)
                            .frame(minHeight: 70)
                            .font(.body)
                            .onChange(of: allowedDomainsString) { newValue in
                                let domains = newValue
                                    .split(whereSeparator: { $0.isNewline })
                                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                settingsStore.update {
                                    $0.allowedDomains = domains.isEmpty ? AppSettings.defaults.allowedDomains : domains
                                }
                            }
                    }
                }

                // Section: Behavior
                Section(header: Text(AppLocalization.text("settings.section.behavior", "התנהגות")),
                        footer: Text(AppLocalization.text("settings.footer.behavior", "קישורים לאתרים חיצוניים ייפתחו בתצוגת Safari פנימית כאשר האפשרות פעילה."))) {
                    Toggle(AppLocalization.text("settings.behavior.external_links", "קישורים חיצוניים ב-Safari"), isOn: Binding(
                        get: { settingsStore.settings.openExternalLinksInSafariView },
                        set: { val in settingsStore.update { $0.openExternalLinksInSafariView = val } }
                    ))

                    Toggle(AppLocalization.text("settings.behavior.toolbar_auto_hide", "הסתרת סרגל בגלילה"), isOn: Binding(
                        get: { settingsStore.settings.hideToolbarOnScroll },
                        set: { val in settingsStore.update { $0.hideToolbarOnScroll = val } }
                    ))

                    Toggle(AppLocalization.text("settings.behavior.desktop_mode", "מצב אתר שולחני"), isOn: Binding(
                        get: { settingsStore.settings.preferDesktopUserAgent },
                        set: { val in settingsStore.update { $0.preferDesktopUserAgent = val } }
                    ))
                }

                // Section: Spotlight
                Section(header: Text(AppLocalization.text("settings.section.spotlight", "Spotlight")),
                        footer: Text(AppLocalization.text("settings.footer.spotlight", "בונה את אינדקס הספרים מקומית ומעדכן את Spotlight של iOS ברקע."))) {
                    Button {
                        runSpotlightRefresh(force: false)
                    } label: {
                        HStack {
                            Text(AppLocalization.text("settings.spotlight.update_index", "עדכון אינדקס Spotlight"))
                            Spacer()
                            if showingSpotlightProgress {
                                ProgressView()
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteSpotlightAlert = true
                    } label: {
                        Text(AppLocalization.text("settings.spotlight.delete_index", "מחיקת אינדקס Spotlight"))
                    }

                    Button {
                        shareDiagnosticLog()
                    } label: {
                        Label(AppLocalization.text("settings.spotlight.share_log", "שיתוף לוג אבחון"), systemImage: "square.and.arrow.up")
                    }
                }

                // Section: Data
                Section(header: Text(AppLocalization.text("settings.section.data", "נתונים"))) {
                    Button(role: .destructive) {
                        showingClearHistoryAlert = true
                    } label: {
                        Text(AppLocalization.text("settings.data.clear_history", "ניקוי היסטוריה"))
                    }

                    Button(role: .destructive) {
                        showingClearWebsiteDataAlert = true
                    } label: {
                        Text(AppLocalization.text("settings.data.clear_website_data", "ניקוי נתוני אתר (Cookies / Cache)"))
                    }

                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Text(AppLocalization.text("settings.data.reset_settings", "איפוס הגדרות לברירת מחדל"))
                    }
                }

                // Section: Deep Links
                Section(header: Text(AppLocalization.text("settings.section.links", "קישורים עמוקים")),
                        footer: Text(AppLocalization.text("settings.footer.links", "סכמת ה-URL המותאמת עובדת מיד."))) {
                    Button {
                        let text = "nativeweb://open?url=https://alhatorah.org/"
                        UIPasteboard.general.string = text
                        showToast(AppLocalization.text("common.copied", "הועתק"))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppLocalization.text("settings.links.custom_scheme", "סכמת URL מותאמת"))
                                    .foregroundColor(.primary)
                                Text("nativeweb://open?url=https://alhatorah.org/")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section: About
                Section(header: Text(AppLocalization.text("settings.section.about", "אודות"))) {
                    HStack {
                        Text(AppLocalization.text("settings.about.title", "על־התורה"))
                        Spacer()
                        Text("AlHaTorah iOS")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(AppLocalization.text("tabs.settings", "הגדרות"))
            .alert(spotlightMessage ?? "", isPresented: Binding(
                get: { spotlightMessage != nil },
                set: { if !$0 { spotlightMessage = nil } }
            )) {
                Button(AppLocalization.text("common.ok", "אישור"), role: .cancel) {}
            }
            .confirmationDialog(
                AppLocalization.text("settings.account.logout_confirm_title", "התנתקות"),
                isPresented: $showingLogOutAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("settings.account.logout", "התנתק"), role: .destructive) {
                    Task {
                        await sessionStore.logOut()
                        showToast(AppLocalization.text("settings.account.logged_out", "התנתקת בהצלחה"))
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            } message: {
                Text(AppLocalization.text("settings.account.logout_confirm_message", "האם להתנתק מחשבון על־התורה?"))
            }
            .confirmationDialog(
                AppLocalization.text("settings.spotlight.delete_confirm", "להסיר את ספרי על־התורה מ־Spotlight?"),
                isPresented: $showingDeleteSpotlightAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("common.delete", "מחק"), role: .destructive) {
                    SpotlightIndexManager.shared.deleteAllSpotlightItems { _ in
                        showToast(AppLocalization.text("settings.spotlight.deleted", "אינדקס Spotlight נמחק"))
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            }
            .confirmationDialog(
                AppLocalization.text("settings.data.clear_history_confirm", "למחוק את כל פריטי ההיסטוריה?"),
                isPresented: $showingClearHistoryAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("common.clear", "נקה"), role: .destructive) {
                    dataStore.clearAllHistory()
                    showToast(AppLocalization.text("settings.data.history_cleared", "ההיסטוריה נמחקה"))
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            }
            .confirmationDialog(
                AppLocalization.text("settings.data.clear_website_confirm", "למחוק cookies, cache ונתוני אתר?"),
                isPresented: $showingClearWebsiteDataAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("common.clear", "נקה נתונים"), role: .destructive) {
                    let store = WKWebsiteDataStore.default()
                    store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
                        DispatchQueue.main.async {
                            showToast(AppLocalization.text("settings.data.website_data_cleared", "נתוני האתר נמחקו"))
                        }
                    }
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            }
            .confirmationDialog(
                AppLocalization.text("settings.data.reset_confirm", "לשחזר את הגדרות ברירת המחדל?"),
                isPresented: $showingResetAlert,
                titleVisibility: .visible
            ) {
                Button(AppLocalization.text("common.reset", "איפוס"), role: .destructive) {
                    settingsStore.reset()
                    homeURLString = settingsStore.settings.homeURLString
                    allowedDomainsString = settingsStore.settings.allowedDomains.joined(separator: "\n")
                    showToast(AppLocalization.text("settings.data.settings_reset", "ההגדרות אופסו"))
                }
                Button(AppLocalization.text("common.cancel", "ביטול"), role: .cancel) {}
            }
        }
    }

    private func showToast(_ message: String) {
        statusToast = message
        spotlightMessage = message
    }

    private func runSpotlightRefresh(force: Bool) {
        showingSpotlightProgress = true
        SpotlightIndexManager.shared.refreshIfNeeded(force: force) { result in
            DispatchQueue.main.async {
                self.showingSpotlightProgress = false
                switch result {
                case .success(let summary):
                    let template = AppLocalization.text("settings.spotlight.result_message", "ספרים: %@\nאונדקסו כעת: %@\nמקור: %@")
                    self.spotlightMessage = String(format: template, "\(summary.itemCount)", "\(summary.indexedCount)", summary.source.rawValue)
                case .failure(let error):
                    self.spotlightMessage = error.localizedDescription
                }
            }
        }
    }

    private func shareDiagnosticLog() {
        let url = AppLogger.shared.logFileURL
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            controller.popoverPresentationController?.sourceView = root.view
            controller.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 1, height: 1)
            root.present(controller, animated: true)
        }
    }
}
