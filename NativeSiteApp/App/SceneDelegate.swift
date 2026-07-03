import CoreSpotlight
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var browserViewController: BrowserViewController?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let settingsStore = SettingsStore()
        let launchRequest = SceneLaunchRequest.from(connectionOptions: connectionOptions)
        let siteID = launchRequest?.resolvedSiteID(settings: settingsStore.settings) ?? settingsStore.settings.defaultSiteID

        let tabStore = TabStore(settings: settingsStore.settings, siteID: siteID, sceneID: session.persistentIdentifier)
        let historyStore = HistoryStore()
        let browser = BrowserViewController(
            settingsStore: settingsStore,
            tabStore: tabStore,
            historyStore: historyStore,
            siteID: siteID,
            initialURL: launchRequest?.url
        )
        let navigationController = UINavigationController(rootViewController: browser)
        navigationController.setNavigationBarHidden(true, animated: false)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        self.browserViewController = browser

        if launchRequest == nil {
            handleURLContexts(connectionOptions.urlContexts)
            if let activity = connectionOptions.userActivities.first {
                handleUserActivity(activity)
            }
        } else {
            for activity in connectionOptions.userActivities where activity.activityType == CSSearchableItemActionType {
                handleUserActivity(activity)
            }
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
              let destination = DeepLinkParser.destination(from: incomingURL) else { return }
        browserViewController?.openIncomingURL(
            destination.url,
            preferredSiteID: destination.siteID,
            forceNewWindow: destination.prefersNewWindow
        )
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

        if let request = SceneLaunchRequest.from(userActivity: activity), let url = request.url {
            browserViewController?.openIncomingURL(
                url,
                preferredSiteID: request.siteID,
                forceNewWindow: false
            )
            return
        }
    }
}
