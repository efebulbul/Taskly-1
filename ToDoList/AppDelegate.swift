import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
#endif
        // ---- Tema rengi (#8C52B4)
        let appPurple = UIColor(named: "AppPurple")
            ?? UIColor(red: 140/255, green: 82/255, blue: 180/255, alpha: 1)

        // ---- UINavigationBar (başlıklar sistem rengi, butonlar mor)
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = .systemBackground
        nav.titleTextAttributes = [.foregroundColor: UIColor.label]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = appPurple

        // ---- UITabBar (seçili = mor, seçili olmayan = gri) — iOS 15+ tüm layout'lar
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = .systemBackground

        let unselected = UIColor.secondaryLabel

        // normal (unselected)
        tab.stackedLayoutAppearance.normal.iconColor = unselected
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        tab.inlineLayoutAppearance.normal.iconColor = unselected
        tab.inlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        tab.compactInlineLayoutAppearance.normal.iconColor = unselected
        tab.compactInlineLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]

        // selected
        tab.stackedLayoutAppearance.selected.iconColor = appPurple
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appPurple]
        tab.inlineLayoutAppearance.selected.iconColor = appPurple
        tab.inlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appPurple]
        tab.compactInlineLayoutAppearance.selected.iconColor = appPurple
        tab.compactInlineLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: appPurple]

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Eski API’lerle uyum için emniyet kemeri:
        UITabBar.appearance().tintColor = appPurple
        UITabBar.appearance().unselectedItemTintColor = unselected

        // Bildirimler (görünürlük)
        UNUserNotificationCenter.current().delegate = self


        return true
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: - UNUserNotificationCenterDelegate (foreground gösterimi)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

}

