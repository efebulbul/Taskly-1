//
//  ProfilePanelViewController.swift
//  Taskly
//
//  Created by EfeBülbül on 04.10.2025.
//
import UIKit

final class ProfilePanelViewController: UITableViewController {
    var displayName: String?
    var email: String?
    weak var host: SettingsViewController?

    private enum Row: Int, CaseIterable { case name = 0, mail, signOut, delete }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = .systemGroupedBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 64
        tableView.estimatedRowHeight = 64
        title = L("settings.account.title")
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let symbolCfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)

        switch Row(rawValue: indexPath.row)! {
        case .name:
            var cfg = UIListContentConfiguration.valueCell()
            cfg.text = L("profile.name.title")
            cfg.secondaryText = displayName ?? "—"
            cfg.textProperties.adjustsFontForContentSizeCategory = true
            cfg.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cfg.textProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.color = .secondaryLabel
            cfg.prefersSideBySideTextAndSecondaryText = true
            cfg.image = UIImage(systemName: "person.circle")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
            cell.accessoryType = .none

        case .mail:
            var cfg = UIListContentConfiguration.valueCell()
            cfg.text = L("profile.email.title")
            cfg.secondaryText = email ?? "—"
            cfg.textProperties.adjustsFontForContentSizeCategory = true
            cfg.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cfg.textProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.font = .preferredFont(forTextStyle: .body)
            cfg.secondaryTextProperties.color = .secondaryLabel
            cfg.prefersSideBySideTextAndSecondaryText = true
            cfg.image = UIImage(systemName: "envelope")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.selectionStyle = .none
            cell.accessoryType = .none

        case .signOut:
            var cfg = UIListContentConfiguration.cell()
            cfg.text = L("actions.signout")
            cfg.textProperties.font = .preferredFont(forTextStyle: .footnote)
            cfg.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.accessoryType = .none

        case .delete:
            var cfg = UIListContentConfiguration.cell()
            cfg.text = L("settings.account.delete")
            cfg.textProperties.font = .preferredFont(forTextStyle: .footnote)
            cfg.textProperties.color = .systemRed
            cfg.image = UIImage(systemName: "trash")
            cfg.imageProperties.preferredSymbolConfiguration = symbolCfg
            cfg.imageProperties.maximumSize = CGSize(width: 30, height: 30)
            cfg.imageToTextPadding = 12
            cell.contentConfiguration = cfg
            cell.accessoryType = .none
        }

        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let parent = host ?? (presentingViewController as? SettingsViewController) else { return }
        switch Row(rawValue: indexPath.row)! {
        case .name, .mail:
            break
        case .signOut:
            dismiss(animated: true) {
                parent.presentSignOutConfirm()
            }
        case .delete:
            dismiss(animated: true) {
                parent.presentAccountDeleteConfirm()
            }
        }
    }
}
