import Foundation

enum AppLanguage: String, CaseIterable {
    case system   // iOS sistem dilini kullan
    case tr
    case en
    case de

    var locale: Locale {
        switch self {
        case .system: return Locale.autoupdatingCurrent
        case .tr: return Locale(identifier: "tr_TR")
        case .en: return Locale(identifier: "en_US")
        case .de: return Locale(identifier: "de_DE")
        }
    }

    var lprojCode: String? {
        switch self {
        case .system: return nil
        case .tr: return "tr"
        case .en: return "en"
        case .de: return "de"
        }
    }

    var displayName: String {
        switch self {
        case .system: return NSLocalizedString("settings.language.system", comment: "")
        case .tr:     return NSLocalizedString("settings.language.turkish", comment: "")
        case .en:     return NSLocalizedString("settings.language.english", comment: "")
        case .de:     return NSLocalizedString("settings.language.german", comment: "")
        }
    }
}

final class LanguageManager {
    static let shared = LanguageManager()

    private let key = "app.language"
    private(set) var current: AppLanguage = .system
    private var bundle: Bundle = .main

    private init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let lang = AppLanguage(rawValue: raw) {
            set(language: lang, broadcast: false)
        } else {
            current = .system
            bundle = .main
        }
    }

    func set(language: AppLanguage, broadcast: Bool = true) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: key)

        if let code = language.lprojCode,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let b = Bundle(path: path) {
            bundle = b
        } else {
            bundle = .main // sistem diline geri dön
        }

        if broadcast {
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    // Tarih/Saat formatlayıcılar bu locale'i kullansın
    var currentLocale: Locale { current.locale }
}

extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

// Kısa yardımcı
func L(_ key: String) -> String {
    LanguageManager.shared.localized(key)
}
