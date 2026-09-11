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
        if let browser = BrowserMenuCoordinator.activeBrowser {
            browser.buildNativeMainMenu(with: builder)
        } else if let browser = PersistentBrowserHolder.shared.controller {
            BrowserMenuCoordinator.activeBrowser = browser
            browser.buildNativeMainMenu(with: builder)
        }
    }

    // MARK: - App-Wide Menu Action Handlers via Responder Chain

    @objc func menuGoHome(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuGoHome(sender)
    }

    @objc func menuCopyCurrentLink(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuCopyCurrentLink(sender)
    }

    @objc func menuOpenCurrentPageInSafari(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuOpenCurrentPageInSafari(sender)
    }

    @objc func menuOpenCurrentPageInSafariView(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuOpenCurrentPageInSafariView(sender)
    }

    @objc func menuShareCurrentPage(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuShareCurrentPage(sender)
    }

    @objc func menuReload(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuReload(sender)
    }

    @objc func menuShowHistory(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .history
    }

    @objc func menuClearHistory(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuClearHistory(sender)
    }

    @objc func menuAddBookmark(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuAddBookmark(sender)
    }

    @objc func menuOpenURLCommand(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuOpenURLCommand(sender)
    }

    @objc func menuOpenAlHaTorahIndexSearch(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .search
    }

    @objc func menuRefreshAlHaTorahIndex(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuRefreshAlHaTorahIndex(sender)
    }

    @objc func menuOpenNewTab(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuOpenNewTab(sender)
    }

    @objc func menuShowTabs(_ sender: Any?) {
        AppCoordinator.shared.selectedTab = .reader
        BrowserMenuCoordinator.activeBrowser?.menuShowTabs(sender)
    }

    @objc func menuCopyLogFilePath(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuCopyLogFilePath(sender)
    }

    @objc func menuClearDiagnosticLog(_ sender: Any?) {
        BrowserMenuCoordinator.activeBrowser?.menuClearDiagnosticLog(sender)
    }

    @objc func menuNoOp(_ sender: Any?) {}
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
