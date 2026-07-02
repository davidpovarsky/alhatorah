import Foundation

enum AppLocalization {
    static var preferredLanguageCode: String {
        let bundleLanguage = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        if bundleLanguage.lowercased().hasPrefix("he") { return "he" }
        return "en"
    }

    static var isHebrew: Bool {
        preferredLanguageCode == "he"
    }

    static func text(_ key: String, _ fallback: String) -> String {
        Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }
}
