import Foundation

// MARK: - Apple-recommended localization approach
// We rely entirely on iOS/App Settings for the app language.
// No custom bundle switching. All strings are resolved via NSLocalizedString.
// Keep a thin helper so existing calls L("key") continue to work.

enum AppLanguage: String, CaseIterable {
    // Kept for backward compatibility with existing code, but we always follow system.
    case system
    case tr, en, de
}

final class LanguageManager {
    static let shared = LanguageManager()

    // We keep the stored value only for compatibility (e.g., UI that may read it),
    // but it does NOT override the system/App Settings language anymore.
    private let key = "app.language"
    private(set) var current: AppLanguage = .system

    private init() {
        // If something was stored earlier, keep it for UI display purposes only.
        if let raw = UserDefaults.standard.string(forKey: key),
           let lang = AppLanguage(rawValue: raw) {
            current = lang
        } else {
            current = .system
        }
    }

    // Compatibility: allow writing a preferred language without changing the runtime bundle.
    // We still broadcast so UI that listens can refresh if desired.
    func set(language: AppLanguage, broadcast: Bool = true) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: key)
        if broadcast {
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    // Always resolve using the system/App Settings-selected language.
    func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    // Date/number/etc. formatters should use the system/app language automatically.
    // (Do NOT force a specific locale here.)
    var currentLocale: Locale { .autoupdatingCurrent }
}

// We keep the notification name for any listeners (harmless if unused).
extension Notification.Name {
    static let languageDidChange = Notification.Name("LanguageDidChange")
}

// Short helpers (kept to avoid touching all call sites)
func L(_ key: String) -> String {
    LanguageManager.shared.localized(key)
}

func Lf(_ key: String, _ fallback: String) -> String {
    let v = LanguageManager.shared.localized(key)
    return (v == key) ? fallback : v
}
