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

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            self.handle(task: task)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh is opportunistic. If iOS rejects scheduling, launch-time refresh still works.
        }
    }

    private func handle(task: BGTask) {
        schedule()

        var completed = false
        task.expirationHandler = {
            if !completed {
                completed = true
                task.setTaskCompleted(success: false)
            }
        }

        SpotlightIndexManager.shared.refreshIfNeeded(force: false) { result in
            if !completed {
                completed = true
                switch result {
                case .success:
                    task.setTaskCompleted(success: true)
                case .failure:
                    task.setTaskCompleted(success: false)
                }
            }
        }
    }
}
