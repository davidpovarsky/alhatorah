import CoreSpotlight
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var browserViewController: BrowserViewController?
    private var settingsStore: SettingsStore?
    private var siteID: String?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let settingsStore = SettingsStore()
        let launchRequest = SceneLaunchRequest.from(connectionOptions: connectionOptions)
        let siteID = launchRequest?.resolvedSiteID(settings: settingsStore.settings) ?? settingsStore.settings.defaultSiteID
        let initialURL = launchRequest?.resolvedURL(settings: settingsStore.settings)

        self.settingsStore = settingsStore
        self.siteID = siteID
        SiteSceneRegistry.shared.register(siteID: siteID, session: session)
        updateWindowSceneTitle(windowScene, siteID: siteID, settings: settingsStore.settings)

        let tabStore = TabStore(settings: settingsStore.settings, siteID: siteID, sceneID: session.persistentIdentifier)
        let historyStore = HistoryStore()
        let browser = BrowserViewController(
            settingsStore: settingsStore,
            tabStore: tabStore,
            historyStore: historyStore,
            siteID: siteID,
            initialURL: initialURL
        )
        let navigationController = UINavigationController(rootViewController: browser)
        navigationController.setNavigationBarHidden(true, animated: false)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
        self.browserViewController = browser
        updateWindowSceneTitle(windowScene, siteID: siteID, settings: settingsStore.settings)

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

    func sceneDidBecomeActive(_ scene: UIScene) {
        if let siteID {
            SiteSceneRegistry.shared.register(siteID: siteID, session: scene.session)
        }
        if let windowScene = scene as? UIWindowScene,
           let siteID,
           let settings = settingsStore?.settings {
            updateWindowSceneTitle(windowScene, siteID: siteID, settings: settings)
        }
        if let settings = settingsStore?.settings {
            AppShortcutManager.updateQuickActions(settings: settings)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        SiteSceneRegistry.shared.unregister(session: scene.session)
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

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let request = AppShortcutManager.launchRequest(from: shortcutItem),
              let settings = settingsStore?.settings else {
            completionHandler(false)
            return
        }

        let resolvedSiteID = request.resolvedSiteID(settings: settings)
        let url = request.resolvedURL(settings: settings)
        browserViewController?.openIncomingURL(
            url,
            preferredSiteID: resolvedSiteID,
            forceNewWindow: true
        )
        completionHandler(true)
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

        guard let request = SceneLaunchRequest.from(userActivity: activity),
              let settings = settingsStore?.settings else { return }

        let resolvedSiteID = request.resolvedSiteID(settings: settings)
        let url = request.resolvedURL(settings: settings)
        browserViewController?.openIncomingURL(
            url,
            preferredSiteID: resolvedSiteID,
            forceNewWindow: false
        )
    }

    private func updateWindowSceneTitle(_ windowScene: UIWindowScene, siteID: String, settings: AppSettings) {
        windowScene.title = settings.siteProfile(withID: siteID)?.name ?? settings.defaultSite.name
    }
}
