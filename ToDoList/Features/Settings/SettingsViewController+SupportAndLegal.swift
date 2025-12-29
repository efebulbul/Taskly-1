//
//  SettingsViewController+SupportAndLegal.swift
//  Taskly
//
//  Created by EfeBülbül on 24.12.2025.
//

import UIKit
import MessageUI
import SafariServices

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    
    // MARK: - Support & Feedback

    private var supportEmailAddress: String { "info@efebulbul.com" }
    private var supportEmailSubject: String { L("support.email.subject") }

    func presentSupportFeedback() {
        let ac = UIAlertController(title: L("settings.support"), message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: L("support.sendEmail"), style: .default, handler: { [weak self] _ in
            self?.presentSupportMailComposer()
        }))

        ac.addAction(UIAlertAction(title: L("support.reportBug"), style: .default, handler: { [weak self] _ in
            self?.presentSupportMailComposer(isBugReport: true)
        }))

        ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX,
                                    y: self.view.bounds.midY,
                                    width: 0,
                                    height: 0)
        }

        present(ac, animated: true)
    }

    private func presentSupportMailComposer(isBugReport: Bool = false) {
        let subject = isBugReport ? L("support.email.subject.bug") : supportEmailSubject
        let body = buildSupportMailBody(isBugReport: isBugReport)

        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.setToRecipients([supportEmailAddress])
            vc.setSubject(subject)
            vc.setMessageBody(body, isHTML: false)
            vc.mailComposeDelegate = self
            present(vc, animated: true)
            return
        }

        // Fallback: mailto
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let mailto = "mailto:\(supportEmailAddress)?subject=\(encodedSubject)&body=\(encodedBody)"
        guard let url = URL(string: mailto), UIApplication.shared.canOpenURL(url) else {
            showSimpleAlert(
                title: L("mail.error.title"),
                message: L("mail.error.message")
            )
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func buildSupportMailBody(isBugReport: Bool) -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let device = UIDevice.current.model
        let os = UIDevice.current.systemVersion

        var lines: [String] = []
        lines.append(L("support.mail.greeting"))
        lines.append("")
        lines.append(isBugReport ? L("support.mail.bugPrompt") : L("support.mail.feedbackPrompt"))
        lines.append("")
        lines.append("—")
        lines.append(String(format: L("support.mail.appLine"), "Taskly"))
        lines.append(String(format: L("support.mail.versionLine"), appVersion, buildNumber))
        lines.append(String(format: L("support.mail.deviceLine"), device))
        lines.append(String(format: L("support.mail.osLine"), os))
        lines.append("—")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - MFMailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }

    // MARK: - Legal

    private var privacyPolicyURLString: String { "https://www.efebulbul.com/Project/TasklyX/" }
    private var termsOfUseURLString: String { "https://www.efebulbul.com/Project/TasklyX/" }

    func presentLegalLinks() {
        let ac = UIAlertController(title: L("settings.legal"), message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: L("legal.privacyPolicy"), style: .default, handler: { [weak self] _ in
            self?.openInSafariView(self?.privacyPolicyURLString)
        }))
        ac.addAction(UIAlertAction(title: L("legal.termsOfUse"), style: .default, handler: { [weak self] _ in
            self?.openInSafariView(self?.termsOfUseURLString)
        }))
        ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = self.view
            pop.sourceRect = CGRect(x: self.view.bounds.midX,
                                    y: self.view.bounds.midY,
                                    width: 0,
                                    height: 0)
        }

        present(ac, animated: true)
    }

    private func openInSafariView(_ urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            showSimpleAlert(title: L("link.error.title"), message: L("link.error.message"))
            return
        }
        let vc = SFSafariViewController(url: url)
        present(vc, animated: true)
    }

}
