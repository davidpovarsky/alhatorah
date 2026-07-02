import CoreSpotlight
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var browserViewController: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let settingsStore = SettingsStore()
        let tabStore = TabStore(settings: settingsStore.settings)
        let historyStore = HistoryStore()
        let browser = BrowserViewController(settingsStore: settingsStore, tabStore: tabStore, historyStore: historyStore)
        let navigationController = UINavigationController(rootViewController: browser)
        navigationController.setNavigationBarHidden(true, animated: false)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        self.browserViewController = browser

        handleURLContexts(connectionOptions.urlContexts)
        if let activity = connectionOptions.userActivities.first {
            handleUserActivity(activity)
        }

        SpotlightIndexManager.shared.refreshIfNeeded(force: false)
        SpotlightBackgroundScheduler.shared.schedule()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        SpotlightBackgroundScheduler.shared.schedule()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleURLContexts(URLContexts)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }

    private func handleURLContexts(_ contexts: Set<UIOpenURLContext>) {
        guard let incomingURL = contexts.first?.url,
              let destination = DeepLinkParser.destinationURL(from: incomingURL) else { return }
        browserViewController?.openIncomingURL(destination)
    }

    private func handleUserActivity(_ activity: NSUserActivity) {
        if activity.activityType == CSSearchableItemActionType,
           let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            SpotlightIndexManager.shared.urlForSpotlightIdentifier(identifier) { [weak self] url in
                DispatchQueue.main.async {
                    guard let url else { return }
                    self?.browserViewController?.openIncomingURLInNewTab(url)
                }
            }
            return
        }

        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let destination = activity.webpageURL else { return }
        browserViewController?.openIncomingURL(destination)
    }
}
