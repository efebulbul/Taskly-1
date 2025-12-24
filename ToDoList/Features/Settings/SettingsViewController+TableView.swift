//
//  SettingsViewController+TableView.swift
//  Taskly
//
//  Created by EfeBülbül on 04.10.2025.
//
import UIKit
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

extension SettingsViewController {

    // MARK: - Table sections
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
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

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        switch section {
        case .profile:
            return buildProfileSummaryCell(tableView)

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
                sw.onTintColor = .appBlue
                sw.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    let enabled = sw.isOn
                    UserDefaults.standard.set(enabled, forKey: self.dailyReminderKey)
                    if enabled { self.enableDailyReminder() } else { self.cancelDailyReminder() }
                }, for: .valueChanged)
                cell.accessoryView = sw
                cell.accessoryType = .none
                cell.selectionStyle = .none

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

    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else { return }

        switch section {
        case .profile:
            #if canImport(FirebaseAuth)
            if Auth.auth().currentUser == nil {
                presentLogin()
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
            case .notifications:
                requestNotifications()
            case .dailyReminder:
                break
            case .about:
                presentAbout()
            }
        }
    }
}
