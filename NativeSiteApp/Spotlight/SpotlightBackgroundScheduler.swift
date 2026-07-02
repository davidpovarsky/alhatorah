import BackgroundTasks
import Foundation

final class SpotlightBackgroundScheduler {
    static let shared = SpotlightBackgroundScheduler()

    static let taskIdentifier = "com.davidpovarsky.alhatorah.spotlight-refresh"
    private let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private var didRegister = false

    private init() {}

    func register() {
        guard !didRegister else { return }
        didRegister = true
        AppLogger.shared.log("Registering background task: \(Self.taskIdentifier)")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            self.handle(task: task)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
            AppLogger.shared.log("Scheduled background Spotlight refresh")
        } catch {
            AppLogger.shared.log("Could not schedule background Spotlight refresh: \(error.localizedDescription)")
        }
    }

    private func handle(task: BGTask) {
        AppLogger.shared.log("Background Spotlight refresh started")
        schedule()

        var completed = false
        task.expirationHandler = {
            AppLogger.shared.log("Background Spotlight refresh expired")
            if !completed {
                completed = true
                task.setTaskCompleted(success: false)
            }
        }

        SpotlightIndexManager.shared.refreshIfNeeded(force: false) { result in
            if !completed {
                completed = true
                switch result {
                case .success(let summary):
                    AppLogger.shared.log("Background Spotlight refresh succeeded; items=\(summary.itemCount), indexed=\(summary.indexedCount), skipped=\(summary.skipped)")
                    task.setTaskCompleted(success: true)
                case .failure(let error):
                    AppLogger.shared.log("Background Spotlight refresh failed: \(error.localizedDescription)")
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }
}