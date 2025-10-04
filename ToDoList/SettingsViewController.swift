import UIKit
import UserNotifications

final class SettingsViewController: UITableViewController {

    // MARK: - Sections
    private enum Section: Int, CaseIterable { case profile = 0, settings }

    // MARK: - Profile
    private enum ProfileRow: Int, CaseIterable { case summary = 0, signOut }

    /// Basit bir kullanıcı modeli ve geçici oturum yöneticisi
    struct AppUser {
        let name: String
        let email: String
        let avatar: UIImage?
    }

    final class UserSession {
        static let shared = UserSession()
        /// Oturum açmış kullanıcıyı buraya atayın. (Gerçek uygulamada Auth servisinizden besleyin.)
        var currentUser: AppUser? = nil
        private init() {}
        func signOut() { currentUser = nil }
    }

    // MARK: - Rows
    private enum Row: Int, CaseIterable { case language = 0, theme, notifications, about }

    // MARK: - Theme
    private enum ThemeOption: Int, CaseIterable {
        case system = 0
        case light
        case dark

        var title: String {
            switch self {
            case .system: return "Sistem"
            case .light:  return "Açık"
            case .dark:   return "Koyu"
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
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTexts), name: .languageDidChange, object: nil)

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.sectionHeaderTopPadding = 8
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ekrana gelince temayı uygula (örn. başka ekrandan dönülmüş olabilir)
        applyTheme(currentTheme)
        tableView.reloadData()
    }

    // MARK: - Table
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .profile:
            // Özet + (giriş yapmışsa) Çıkış Yap
            if UserSession.shared.currentUser != nil {
                return ProfileRow.allCases.count
            } else {
                return 1 // sadece özet hücresi, içinde "Giriş Yap" buton görünümü
            }
        case .settings:
            // Hakkında altında Çıkış Yap kaldırıldı; sadece sabit ayarlar göster
            return Row.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .profile:
            if indexPath.row == ProfileRow.summary.rawValue {
                return buildProfileSummaryCell(tableView)
            } else {
                // sign out cell
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                var cfg = cell.defaultContentConfiguration()
                cfg.text = "Çıkış Yap"
                cfg.textProperties.color = .systemRed
                cell.contentConfiguration = cfg
                cell.accessoryType = .none
                return cell
            }

        case .settings:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var cfg = cell.defaultContentConfiguration()
            cfg.textProperties.adjustsFontForContentSizeCategory = true

            guard let row = Row(rawValue: indexPath.row) else { return cell }
            switch row {
            case .language:
                cfg.text = L("settings.language")
                cfg.secondaryText = LanguageManager.shared.current.displayName
                cfg.secondaryTextProperties.color = .secondaryLabel
                cell.accessoryType = .disclosureIndicator
            case .theme:
                cfg.text = L("settings.theme")
                cfg.secondaryText = currentTheme.title
                cfg.secondaryTextProperties.color = .secondaryLabel
                cell.accessoryType = .disclosureIndicator
            case .notifications:
                cfg.text = L("settings.notifications")
                cell.accessoryType = .disclosureIndicator
            case .about:
                cfg.text = L("settings.about")
                cell.accessoryType = .disclosureIndicator
            }
            cell.contentConfiguration = cfg
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .profile:
            if UserSession.shared.currentUser == nil {
                presentLogin()
            } else if indexPath.row == ProfileRow.signOut.rawValue {
                presentSignOutConfirm()
            }
        case .settings:
            guard let row = Row(rawValue: indexPath.row) else { return }
            switch row {
            case .language:
                presentLanguagePicker()
            case .theme:
                presentThemePicker()
            case .notifications:
                requestNotifications()
            case .about:
                presentAbout()
            }
        }
    }

    /// Profil özet hücresi: avatar + ad/eposta. Giriş yoksa "Giriş Yap" çağrısı gösterir.
    private func buildProfileSummaryCell(_ tableView: UITableView) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        var cfg = UIListContentConfiguration.subtitleCell()
        if let user = UserSession.shared.currentUser {
            cfg.text = user.name
            cfg.secondaryText = user.email
            cfg.image = user.avatar ?? UIImage(systemName: "person.circle.fill")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            let appPurple = UIColor(red: 96/255, green: 42/255, blue: 128/255, alpha: 1.0)
            cfg.imageProperties.tintColor = appPurple
        } else {
            cfg.text = "Giriş yap"
            cfg.secondaryText = "Profil bilgilerini görmek için giriş yapın"
            cfg.image = UIImage(systemName: "person.crop.circle")
            cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
            let appPurple = UIColor(red: 96/255, green: 42/255, blue: 128/255, alpha: 1.0)
            cfg.imageProperties.tintColor = appPurple
        }
        cfg.textProperties.font = .preferredFont(forTextStyle: .headline)
        cfg.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = cfg
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    private func presentLogin() {
        // Burada kendi login ekranınızı sunun. Şimdilik bilgilendirme veriyoruz.
        presentOK(title: "Giriş", message: "Giriş ekranını burada gösterebilirsiniz.")
    }

    private func presentSignOutConfirm() {
        let ac = UIAlertController(title: "Çıkış Yap", message: "Hesabınızdan çıkmak istediğinize emin misiniz?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Vazgeç", style: .cancel))
        ac.addAction(UIAlertAction(title: "Çıkış Yap", style: .destructive, handler: { _ in
            // Oturumu kapat
            UserSession.shared.signOut()
            self.tableView.reloadData()

            // Giriş ekranına yönlendir
            let login = LoginViewController()
            login.modalPresentationStyle = .fullScreen
            // Zaten bir controller sunulmuşsa üstünden sunulabilmesi için ana thread üzerinde sun
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

        // iPad için popover anchor
        if let pop = ac.popoverPresentationController, let cell = tableView.cellForRow(at: IndexPath(row: Row.theme.rawValue, section: 1)) {
            pop.sourceView = cell
            pop.sourceRect = cell.bounds
        }
        present(ac, animated: true)
    }

    private func presentLanguagePicker() {
        let ac = UIAlertController(title: L("settings.language"), message: nil, preferredStyle: .actionSheet)
        let options: [AppLanguage] = [.system, .tr, .en, .de]
        for lang in options {
            let title = lang.displayName + (lang == LanguageManager.shared.current ? " ✓" : "")
            ac.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
                LanguageManager.shared.set(language: lang)
                self.tableView.reloadData()
                self.showLanguageUpdated()
            }))
        }
        ac.addAction(UIAlertAction(title: L("add.back"), style: .cancel))
        if let pop = ac.popoverPresentationController, let cell = tableView.cellForRow(at: IndexPath(row: Row.language.rawValue, section: 1)) {
            pop.sourceView = cell
            pop.sourceRect = cell.bounds
        }
        present(ac, animated: true)
    }

    private func showLanguageUpdated() {
        let ok = UIAlertAction(title: L("settings.ok"), style: .default)
        let ac = UIAlertController(title: L("settings.restart.title"),
                                   message: L("settings.restart.message"),
                                   preferredStyle: .alert)
        ac.addAction(ok)
        present(ac, animated: true)
    }

    private func applyTheme(_ option: ThemeOption) {
        // Tüm pencerelere uygula
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = option.interfaceStyle }
    }

    // MARK: - Notifications
    private func requestNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.presentOK(title: L("Hata"), message: error.localizedDescription)
                    return
                }
                if granted {
                    self?.presentOK(title: L("Bildirimler"), message: L("İzin verildi. Örnek bir hatırlatma 5 sn sonra gösterilecek."))
                    self?.scheduleSampleNotification()
                } else {
                    self?.presentOK(title: L("Bildirimler"), message: L("İzin verilmedi."))
                }
            }
        }
    }

    private func scheduleSampleNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("app.title")
        content.body = "Bunu kaçırma! Bir görevin var."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - About
    private func presentAbout() {
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "ToDoList"
        let ver = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let msg = "\(app) v\(ver)\n" + L("Yalın ve hızlı görev yöneticisi.")
        presentOK(title: L("Hakkında"), message: msg)
    }

    // MARK: - Helpers
    private func presentOK(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("settings.ok"), style: .default))
        present(ac, animated: true)
    }

    @objc private func reloadTexts() {
        title = L("tab.settings")
        tabBarItem.title = L("tab.settings")
        tableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .languageDidChange, object: nil)
    }
}
