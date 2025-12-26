//
//  SettingsViewController+Helpers.swift
//  Taskly
//
//  Created by EfeBülbül on 04.10.2025.
//
import UIKit

extension SettingsViewController {

    // MARK: - Helpers
    func presentOK(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("settings.ok"), style: .default))
        present(ac, animated: true)
    }

    func showSimpleAlert(title: String, message: String) {
        let ac = UIAlertController(title: title,
                                   message: message,
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Tamam", style: .default))
        present(ac, animated: true)
    }
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            showSimpleAlert(title: "Ayarlar", message: "Ayarlar açılamadı.")
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
