import CoreSpotlight
import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let mainView = MainTabView()
        let hostingController = UIHostingController(rootView: mainView)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        self.window = window

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
        guard let incomingURL = contexts.first?.url else { return }
        AppCoordinator.shared.openIncomingURL(incomingURL)
    }

    private func handleUserActivity(_ activity: NSUserActivity) {
        if activity.activityType == CSSearchableItemActionType,
           let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            SpotlightIndexManager.shared.urlForSpotlightIdentifier(identifier) { url in
                DispatchQueue.main.async {
                    guard let url else { return }
                    AppCoordinator.shared.openInReader(url: url)
                }
            }
            return
        }

        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let destination = activity.webpageURL else { return }
        AppCoordinator.shared.openIncomingURL(destination)
    }
}
