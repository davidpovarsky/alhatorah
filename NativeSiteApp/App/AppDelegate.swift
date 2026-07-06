import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppCrashReporter.install()
        AppLogger.shared.logSync("Application did finish launching")
        SpotlightBackgroundScheduler.shared.register()
        AppLogger.shared.log("Scheduling Spotlight refresh from launch")
        SpotlightBackgroundScheduler.shared.schedule()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.shared.log("Application entered background; scheduling Spotlight refresh")
        SpotlightBackgroundScheduler.shared.schedule()
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        BrowserMenuCoordinator.activeBrowser?.buildNativeMainMenu(with: builder)
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
