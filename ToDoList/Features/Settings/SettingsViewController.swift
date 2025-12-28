//
//  SettingsViewController.swift
//  Taskly
//
//  Created by EfeBülbül on 04.10.2025.
//

import UIKit
import UserNotifications
import StoreKit
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
import SwiftUI

#Preview {
    ViewControllerPreview {
        SettingsViewController()
    }
}

final class SettingsViewController: UITableViewController {

    // MARK: - Sections
    enum Section: Int, CaseIterable { case profile = 0, settings }

    // MARK: - Profile
    enum ProfileRow: Int, CaseIterable { case summary = 0 }

    struct AppUser {
        let name: String
        let email: String
        let avatar: UIImage?
    }

    final class UserSession {
        static let shared = UserSession()
        var currentUser: AppUser? = nil
        private init() {}
        func signOut() { currentUser = nil }
    }

    // MARK: - Rows
    enum Row: Int, CaseIterable { case language = 0, theme, dailyReminder, notifications, rateUs, about, support, legal }

    // MARK: - Theme
    enum ThemeOption: Int, CaseIterable {
        case system = 0
        case light
        case dark

        var title: String {
            switch self {
            case .system: return L("theme.system")
            case .light:  return L("theme.light")
            case .dark:   return L("theme.dark")
            }
        }

        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: return .unspecified
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    let themeKey = "settings.theme.option"
    let dailyReminderKey = "settings.dailyReminder.enabled"
    let dailyReminderIdentifier = "daily.reminder.08"

    // MARK: - App Store Review
    // Replace with your real App Store ID (App Store Connect -> App Information)
    private let appStoreAppID = "YOUR_APP_ID" // e.g. "1234567890"

    func requestAppStoreReview() {
        // iOS 14+: request the in-app review prompt in the current active scene
        if let scene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
            return
        }

        // Fallback: open the App Store rating page
        guard appStoreAppID != "YOUR_APP_ID" else { return }
        if let url = URL(string: "https://apps.apple.com/app/id\(appStoreAppID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Cached profile
    var cachedDisplayName: String?
    var cachedEmail: String?

    var currentTheme: ThemeOption {
        get {
            let raw = UserDefaults.standard.integer(forKey: themeKey)
            return ThemeOption(rawValue: raw) ?? .light
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
            applyTheme(newValue)
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = L("tab.settings")

        // Dil değişimini artık iOS yönetiyor; .languageDidChange observer'ına gerek yok.
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidLogin), name: .tasklyDidLogin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTexts), name: .languageDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidLogin), name: Notification.Name("Taskly.UserSessionDidUpdate"), object: nil)

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "profileCell")
        tableView.sectionHeaderTopPadding = 8
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateProfileUI()
        applyTheme(currentTheme)

        // Bildirim izni reddedildiyse anahtarı kapat
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if settings.authorizationStatus == .denied {
                    UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                    self.tableView.reloadData()
                }
            }
        }
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .tasklyDidLogin, object: nil)
        NotificationCenter.default.removeObserver(self, name: .languageDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name("Taskly.UserSessionDidUpdate"), object: nil)
    }
    
}
