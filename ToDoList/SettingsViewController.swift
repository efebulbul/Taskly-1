import UIKit
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif


final class SettingsViewController: UITableViewController {

    // MARK: - Sections
    private enum Section: Int, CaseIterable { case profile = 0, settings }

    // MARK: - Profile
    private enum ProfileRow: Int, CaseIterable { case summary = 0, signOut }

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
    private enum Row: Int, CaseIterable { case language = 0, theme, dailyReminder, notifications, about }

    // MARK: - Theme
    private enum ThemeOption: Int, CaseIterable {
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

    private let themeKey = "settings.theme.option"
    private let dailyReminderKey = "settings.dailyReminder.enabled"
    private let dailyReminderIdentifier = "daily.reminder.08"

    // MARK: - Cached profile
    private var cachedDisplayName: String?
    private var cachedEmail: String?

    private var currentTheme: ThemeOption {
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

    // MARK: - Table
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .profile:
            #if canImport(FirebaseAuth)
            if Auth.auth().currentUser != nil {
                return ProfileRow.allCases.count
            } else {
                return 1 // sadece özet hücresi (içinde “Giriş Yap” görünümü)
            }
            #else
            return 1
            #endif
        case .settings:
            return Row.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        switch section {
        case .profile:
            if indexPath.row == ProfileRow.summary.rawValue {
                return buildProfileSummaryCell(tableView)
            } else {
                // Sign out cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                var cfg = cell.defaultContentConfiguration()
                cfg.text = L("actions.signout")
                cfg.textProperties.color = .systemRed
                cell.contentConfiguration = cfg
                cell.accessoryType = .none
                cell.gestureRecognizers?.forEach { cell.removeGestureRecognizer($0) }
                var bgSign = UIBackgroundConfiguration.listGroupedCell()
                bgSign.backgroundColor = .secondarySystemGroupedBackground
                cell.backgroundConfiguration = bgSign
                cell.layer.cornerRadius = 12
                cell.layer.masksToBounds = true
                return cell
            }

        case .settings:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var cfg = cell.defaultContentConfiguration()
            cell.gestureRecognizers?.forEach { cell.removeGestureRecognizer($0) }
            cfg.textProperties.adjustsFontForContentSizeCategory = true
            guard let row = Row(rawValue: indexPath.row) else { return cell }

            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
            cell.accessoryView = nil
            cell.accessoryType = .none
            cell.selectionStyle = .default

            switch row {
            case .language:
                cfg.text = L("settings.language")
                cfg.secondaryText = L("settings.language.system")
                cfg.secondaryTextProperties.color = .secondaryLabel
                cfg.image = UIImage(systemName: "globe")
                cell.accessoryType = .disclosureIndicator

            case .theme:
                cfg.text = L("settings.theme")
                cfg.secondaryText = currentTheme.title
                cfg.secondaryTextProperties.color = .secondaryLabel
                cfg.image = UIImage(systemName: "paintpalette")
                cell.accessoryType = .disclosureIndicator

            case .dailyReminder:
                cfg.text = L("settings.dailyReminder")
                // "Every day at 08:00" — sistem diline göre format
                let timeStr: String = {
                    var comps = DateComponents(); comps.hour = 8; comps.minute = 0
                    let date = Calendar.current.date(from: comps) ?? Date()
                    let df = DateFormatter()
                    df.setLocalizedDateFormatFromTemplate("HHmm")
                    return df.string(from: date)
                }()
                cfg.secondaryText = String(format: L("settings.dailyReminder.subtitle.everydayAt"), timeStr)
                cfg.secondaryTextProperties.color = .secondaryLabel
                cfg.image = UIImage(systemName: "alarm")

                let sw = UISwitch()
                sw.isOn = UserDefaults.standard.bool(forKey: dailyReminderKey)
                sw.onTintColor = UIColor(named: "AppPurple") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1.0)
                sw.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    let enabled = sw.isOn
                    UserDefaults.standard.set(enabled, forKey: self.dailyReminderKey)
                    if enabled { self.enableDailyReminder() } else { self.cancelDailyReminder() }
                }, for: .valueChanged)
                cell.accessoryView = sw
                cell.accessoryType = .none
                cell.selectionStyle = .none

            case .notifications:
                cfg.text = L("settings.notifications")
                cfg.image = UIImage(systemName: "bell.badge")
                cell.accessoryType = .disclosureIndicator
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        if settings.authorizationStatus == .authorized {
                            cfg.secondaryText = L("settings.notifications.on")
                            cfg.secondaryTextProperties.color = .systemGreen
                        } else {
                            cfg.secondaryText = L("settings.notifications.off")
                            cfg.secondaryTextProperties.color = .systemRed
                        }
                        cell.contentConfiguration = cfg
                    }
                }

            case .about:
                cfg.text = L("settings.about")
                cfg.image = UIImage(systemName: "info.circle")
                let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
                cfg.secondaryText = "v\(ver)"
                cfg.secondaryTextProperties.color = .secondaryLabel
                cell.accessoryType = .disclosureIndicator
            }

            cell.contentConfiguration = cfg
            var bgSet = UIBackgroundConfiguration.listGroupedCell()
            bgSet.backgroundColor = .secondarySystemGroupedBackground
            cell.backgroundConfiguration = bgSet
            cell.layer.cornerRadius = 12
            cell.layer.masksToBounds = true
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .profile:
            #if canImport(FirebaseAuth)
            if Auth.auth().currentUser == nil {
                presentLogin()
            } else if indexPath.row == ProfileRow.signOut.rawValue {
                presentSignOutConfirm()
            }
            #else
            presentLogin()
            #endif

        case .settings:
            guard let row = Row(rawValue: indexPath.row) else { return }
            switch row {
            case .language:
                presentSystemLanguageHintAndOpenSettings()
            case .theme:
                presentThemePicker()
            case .dailyReminder:
                break
            case .notifications:
                requestNotifications()
            case .about:
                presentAbout()
            }
        }
    }

    /// Profil özet hücresi: avatar + ad (e-posta tap ile açılır). Giriş yoksa "Giriş Yap" görünümü.
    private func buildProfileSummaryCell(_ tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "profileCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "profileCell")
        var cfg = UIListContentConfiguration.subtitleCell()

        #if canImport(FirebaseAuth)
        if let user = Auth.auth().currentUser {
            cfg.text = cachedDisplayName ?? user.displayName ?? L("profile.unknownName")
            cfg.secondaryText = ""
            cfg.image = UIImage(systemName: "person.circle.fill")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            let appColor = UIColor(named: "AppPurple") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1.0)
            cfg.imageProperties.tintColor = appColor

            // Tap to show email
            cell.gestureRecognizers?.forEach { cell.removeGestureRecognizer($0) }
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.showEmail))
            cell.addGestureRecognizer(tap)
            cell.isUserInteractionEnabled = true

            // Edit button
            let editButton = UIButton(type: .system)
            editButton.setTitle(L("actions.edit"), for: .normal)
            editButton.setTitleColor(appColor, for: .normal)
            editButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            editButton.addAction(UIAction { _ in
                self.presentLogin()
            }, for: .touchUpInside)
            cell.accessoryView = editButton

        } else {
            cfg.text = L("profile.signin")
            cfg.secondaryText = L("profile.signin.subtitle")
            cfg.image = UIImage(systemName: "person.crop.circle")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            let appColor = UIColor(named: "AppPurple") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1.0)
            cfg.imageProperties.tintColor = appColor

            let loginButton = UIButton(type: .system)
            loginButton.setTitle(L("profile.signin"), for: .normal)
            loginButton.setTitleColor(appColor, for: .normal)
            loginButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            loginButton.addAction(UIAction { _ in
                self.presentLogin()
            }, for: .touchUpInside)
            cell.accessoryView = loginButton
        }
        #else
        cfg.text = L("profile.signin")
        cfg.secondaryText = L("profile.signin.subtitle")
        cfg.image = UIImage(systemName: "person.crop.circle")
        cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        let appColor = UIColor(named: "AppPurple") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1.0)
        cfg.imageProperties.tintColor = appColor
        #endif

        cfg.textProperties.font = .preferredFont(forTextStyle: .headline)
        cfg.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = cfg

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true

        return cell
    }

    // MARK: - Profile actions
    @objc private func showEmail(_ sender: UITapGestureRecognizer) {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else { return }
        let email = user.email ?? L("profile.email.missing")
        let alert = UIAlertController(title: L("profile.email.title"), message: email, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L("settings.ok"), style: .default))
        present(alert, animated: true)
        #endif
    }

    private func presentLogin() {
        let login = LoginViewController()
        login.modalPresentationStyle = .fullScreen
        present(login, animated: true)
    }

    private func presentSignOutConfirm() {
        let ac = UIAlertController(title: L("actions.signout"), message: L("signout.confirm.message"), preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        ac.addAction(UIAlertAction(title: L("actions.signout"), style: .destructive, handler: { _ in
            #if canImport(FirebaseAuth)
            do { try Auth.auth().signOut() } catch { print("SignOut error: \(error)") }
            #endif
            self.cachedDisplayName = nil
            self.cachedEmail = nil
            self.tableView.reloadData()

            let login = LoginViewController()
            login.modalPresentationStyle = .fullScreen
            DispatchQueue.main.async {
                self.present(login, animated: true)
            }
        }))
        present(ac, animated: true)
    }

    // MARK: - Theme picker
    private func presentThemePicker() {
        let ac = UIAlertController(title: L("settings.theme"), message: nil, preferredStyle: .actionSheet)

        for option in ThemeOption.allCases {
            let action = UIAlertAction(title: option.title + (option == currentTheme ? " ✓" : ""), style: .default) { [weak self] _ in
                self?.currentTheme = option
                self?.tableView.reloadRows(at: [IndexPath(row: Row.theme.rawValue, section: 1)], with: .automatic)
            }
            ac.addAction(action)
        }

        ac.addAction(UIAlertAction(title: L("add.cancel"), style: .cancel))

        if let pop = ac.popoverPresentationController,
           let cell = tableView.cellForRow(at: IndexPath(row: Row.theme.rawValue, section: 1)) {
            pop.sourceView = cell
            pop.sourceRect = cell.bounds
        }
        present(ac, animated: true)
    }

    // MARK: - System language (redirect to iOS Settings)
    private func presentSystemLanguageHintAndOpenSettings() {
        let ac = UIAlertController(
            title: L("lang.system.sheet.title"),
            message: L("lang.system.sheet.message"),
            preferredStyle: .alert
        )
        ac.addAction(UIAlertAction(title: L("lang.system.sheet.cancel"), style: .cancel))
        ac.addAction(UIAlertAction(title: L("lang.system.sheet.continue"), style: .default, handler: { _ in
            let urlStr = UIApplication.openSettingsURLString
            guard let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) else {
                self.presentOK(title: L("settings.language"), message: L("lang.system.unavailable"))
                return
            }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }))
        present(ac, animated: true)
    }

    private func applyTheme(_ option: ThemeOption) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = option.interfaceStyle }
    }

    // MARK: - Daily Reminder 08:00
    private func enableDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.scheduleDailyReminder()
                case .notDetermined:
                    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        DispatchQueue.main.async {
                            if granted { self.scheduleDailyReminder() }
                            else {
                                UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                                self.presentOK(title: L("settings.notifications"), message: L("notifications.permission.denied"))
                                self.tableView.reloadData()
                            }
                        }
                    }
                case .denied:
                    UserDefaults.standard.set(false, forKey: self.dailyReminderKey)
                    self.presentOK(title: L("settings.notifications"), message: L("notifications.permission.settings"))
                    self.tableView.reloadData()
                @unknown default:
                    break
                }
            }
        }
    }

    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = L("app.title")
        content.body = L("notif.daily.body")
        content.sound = .default

        var comp = DateComponents()
        comp.hour = 8
        comp.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comp, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)

        center.add(request) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    UserDefaults.standard.set(false, forKey: self?.dailyReminderKey ?? "")
                    self?.presentOK(title: L("settings.notifications"), message: error.localizedDescription)
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }

    // MARK: - Notifications
    private func requestNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.presentOK(title: L("common.error"), message: error.localizedDescription)
                    return
                }
                if granted {
                    self?.presentOK(title: L("settings.notifications"), message: L("notifications.permission.sampleScheduled"))
                    self?.scheduleSampleNotification()
                } else {
                    self?.presentOK(title: L("settings.notifications"), message: L("notifications.permission.denied"))
                }
            }
        }
    }

    private func scheduleSampleNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("app.title")
        content.body = L("notif.sample.body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - About
    private func presentAbout() {
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Taskly"
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let msg = "\(app) v\(ver)\n" + L("about.subtitle")
        presentOK(title: L("settings.about"), message: msg)
    }

    // MARK: - Helpers
    private func presentOK(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("settings.ok"), style: .default))
        present(ac, animated: true)
    }

    @objc private func reloadTexts() {
        // iOS dil değişimini sistem yönetiyor; bu yine de başlığı tazelemek için kalabilir.
        title = L("tab.settings")
        tabBarItem.title = L("tab.settings")
        tableView.reloadData()
    }

    // MARK: - Profile loading
    private func updateProfileUI() {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            cachedDisplayName = nil
            cachedEmail = nil
            return
        }
        cachedDisplayName = user.displayName
        cachedEmail = user.email

        #if canImport(FirebaseFirestore)
        if cachedDisplayName == nil || cachedEmail == nil {
            Firestore.firestore().collection("users").document(user.uid).getDocument { [weak self] snap, _ in
                guard let self = self else { return }
                let dict = snap?.data()?["profile"] as? [String: Any]
                let displayFS = dict?["displayName"] as? String
                let emailFS = dict?["email"] as? String
                if self.cachedDisplayName == nil { self.cachedDisplayName = displayFS }
                if self.cachedEmail == nil { self.cachedEmail = emailFS }
                DispatchQueue.main.async { self.tableView.reloadData() }
            }
        }
        #endif
        #endif
    }

    @objc private func handleDidLogin() {
        updateProfileUI()
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .tasklyDidLogin, object: nil)
        NotificationCenter.default.removeObserver(self, name: .languageDidChange, object: nil)
    }
}
