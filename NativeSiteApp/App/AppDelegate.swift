import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppCrashReporter.install()
        AppLogger.shared.logSync("Application did finish launching; documentsLog=\(AppLogger.shared.logFileURL.path)")
        SpotlightBackgroundScheduler.shared.register()
        AppLogger.shared.log("Scheduling Spotlight refresh from launch")
        SpotlightBackgroundScheduler.shared.schedule()
        AppShortcutManager.updateQuickActions(settings: SettingsStore().settings)
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppLogger.shared.log("Application did become active")
        AppShortcutManager.updateQuickActions(settings: SettingsStore().settings)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.shared.log("Application entered background; scheduling Spotlight refresh")
        SpotlightBackgroundScheduler.shared.schedule()
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        AppLogger.shared.log("Configuring scene session role=\(connectingSceneSession.role.rawValue) persistentID=\(connectingSceneSession.persistentIdentifier)")
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else {
            AppLogger.shared.logSync("AppDelegate buildMenu ignored non-main builder")
            return
        }

        let hasBrowser = BrowserMenuCoordinator.activeBrowser != nil
        AppLogger.shared.logSync("AppDelegate buildMenu main started; hasActiveBrowser=\(hasBrowser)")
        BrowserMenuCoordinator.activeBrowser?.buildNativeMainMenu(with: builder)
        AppLogger.shared.logSync("AppDelegate buildMenu main finished")
    }
}

enum AppCrashReporter {
    static func install() {
        NSSetUncaughtExceptionHandler { exception in
            AppLogger.shared.logSync(
                "UNCAUGHT NSException name=\(exception.name.rawValue) reason=\(exception.reason ?? "nil") stack=\(exception.callStackSymbols.joined(separator: " | "))"
            )
        }
        AppLogger.shared.logSync("Crash reporter installed")
    }
}
