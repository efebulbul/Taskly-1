//
//  SceneDelegate.swift
//  ToDoList
//
//  Created by EfeBülbül on 24.09.2025.
//

import UIKit
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // MARK: - Notifications Permission on App Open
    private func requestNotificationPermissionOnAppOpenIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // First-time: show the system permission prompt
                center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

            case .denied:
                // iOS will not show the system prompt again. Show a one-time alert to open Settings.
                let key = "taskly.didPromptNotificationsDenied"
                guard !UserDefaults.standard.bool(forKey: key) else { return }
                UserDefaults.standard.set(true, forKey: key)

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard let root = self.window?.rootViewController else { return }

                    let title = L("settings.notifications")
                    let message = L("notifications.permission.settings")
                    let cancel = L("common.cancel")
                    let openSettingsTitle = L("settings.openSettings")

                    let alert = UIAlertController(title: title,
                                                  message: message,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: cancel, style: .cancel))
                    alert.addAction(UIAlertAction(title: openSettingsTitle, style: .default, handler: { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }))

                    // Present on top-most VC
                    var top = root
                    while let presented = top.presentedViewController { top = presented }
                    top.present(alert, animated: true)
                }

            default:
                break
            }
        }
    }


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        window?.overrideUserInterfaceStyle = resolvedInterfaceStyle()
        // Uygulama ilk açıldığında giriş yapılmamışsa login göster
        DispatchQueue.main.async { [weak self] in
            self?.presentLoginIfNeeded(animated: false)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        window?.overrideUserInterfaceStyle = resolvedInterfaceStyle()

        // Ask notification permission on app open (only if needed)
        requestNotificationPermissionOnAppOpenIfNeeded()

        presentLoginIfNeeded(animated: true)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        window?.overrideUserInterfaceStyle = resolvedInterfaceStyle()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    private func resolvedInterfaceStyle() -> UIUserInterfaceStyle {
        // Desteklenen anahtarlar (eski/yeni):
        //  - "theme.option" (tercih edilen)
        //  - "settings.theme.option" (eski)
        //  - "ThemeOption" (muhtemel farklı ad)
        // Değer haritası: 0 = System, 1 = Light, 2 = Dark
        let defaults = UserDefaults.standard
        let raw = (
            defaults.object(forKey: "theme.option") as? Int ??
            defaults.object(forKey: "settings.theme.option") as? Int ??
            defaults.object(forKey: "ThemeOption") as? Int ??
            0 // varsayılan: System (cihazı takip et)
        )
        switch raw {
        case 1: return .light
        case 2: return .dark
        default: return .unspecified
        }
    }

    // Login ekranını gerektiğinde sun
    private func presentLoginIfNeeded(animated: Bool) {
        // Eğer kullanıcı giriş yapmamışsa Login ekranını tam ekran göster
        #if canImport(FirebaseAuth)
        let notLoggedIn = (Auth.auth().currentUser == nil)
        #else
        let notLoggedIn = (SettingsViewController.UserSession.shared.currentUser == nil)
        #endif
        guard notLoggedIn, let root = window?.rootViewController else { return }
        // Zaten gösteriliyorsa tekrar açma
        if root.presentedViewController is LoginViewController { return }
        let login = LoginViewController()
        login.modalPresentationStyle = .fullScreen
        root.present(login, animated: animated)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        #if canImport(GoogleSignIn)
        guard let url = URLContexts.first?.url else { return }
        GIDSignIn.sharedInstance.handle(url)
        #endif
    }
}
