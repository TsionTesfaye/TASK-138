import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var container: ServiceContainer!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Initialize DI container with Core Data persistence
        container = ServiceContainer(inMemory: false)

        // Seed demo accounts when launched with -SeedDemoAccounts (QA / tester builds).
        // Runs synchronously before determineRootViewController so the user count is
        // already > 0 by the time we decide which screen to show — bootstrap is
        // bypassed and the app goes straight to the login screen.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-SeedDemoAccounts") {
            let seeder = DebugSeeder(
                userRepo: container.userRepo,
                permissionScopeRepo: container.permissionScopeRepo,
                authService: container.authService
            )
            seeder.seed()
        }
        #endif

        // Register background tasks
        registerBackgroundTasks()

        // Set up window FIRST for cold-start speed (< 1.5s target)
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootVC = determineRootViewController()
        window?.rootViewController = UINavigationController(rootViewController: rootVC)
        window?.makeKeyAndVisible()

        // Defer non-critical work off main thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.container.backgroundTaskService.runAllTasks()
        }
        NotificationService.shared.requestAuthorization { _ in }

        return true
    }

    /// Determine root screen: bootstrap if no users, login otherwise.
    private func determineRootViewController() -> UIViewController {
        let userCount = container.userRepo.count()
        if userCount == 0 {
            return BootstrapViewController(container: container)
        } else {
            return LoginViewController(container: container)
        }
    }

    /// Transition to the main app after authentication.
    func showMainApp() {
        let main = MainSplitViewController(container: container)
        window?.rootViewController = main
    }

    // MARK: - Background Re-authentication

    func applicationDidEnterBackground(_ application: UIApplication) {
        container.sessionService.onAppBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if container.sessionService.onAppForeground() {
            // Session expired — present re-auth
            let loginVC = LoginViewController(container: container)
            loginVC.isReAuth = true
            window?.rootViewController?.present(
                UINavigationController(rootViewController: loginVC),
                animated: false
            )
        }
        // Run background tasks on foreground
        container.backgroundTaskService.runAllTasks()
    }

    // MARK: - Memory Warning

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // Release media caches as required by performance constraints
        MediaCache.shared.clear()
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Background Tasks Registration

    private func registerBackgroundTasks() {
        // SLA checks — every 15 minutes
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskService.slaCheckIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            let result = self.container.backgroundTaskService.runSLAChecks()
            task.setTaskCompleted(success: result.success)
            self.scheduleTask(identifier: BackgroundTaskService.slaCheckIdentifier, interval: 15 * 60)
        }

        // Media cleanup — every 6 hours
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskService.mediaCleanupIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            let result = self.container.backgroundTaskService.runMediaCleanup()
            task.setTaskCompleted(success: result.success)
            self.scheduleTask(identifier: BackgroundTaskService.mediaCleanupIdentifier, interval: 6 * 3600)
        }

        // Carpool recalculation — every 30 minutes
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskService.carpoolRecalcIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            let result = self.container.backgroundTaskService.runCarpoolRecalculation()
            task.setTaskCompleted(success: result.success)
            self.scheduleTask(identifier: BackgroundTaskService.carpoolRecalcIdentifier, interval: 30 * 60)
        }

        // Variance processing — every hour
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskService.varianceProcessingIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            let result = self.container.backgroundTaskService.runVarianceProcessing()
            task.setTaskCompleted(success: result.success)
            self.scheduleTask(identifier: BackgroundTaskService.varianceProcessingIdentifier, interval: 3600)
        }

        // Exception detection — every 15 minutes
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskService.exceptionDetectionIdentifier,
            using: nil
        ) { [weak self] task in
            guard let self = self else { return }
            let result = self.container.backgroundTaskService.runExceptionDetection()
            task.setTaskCompleted(success: result.success)
            self.scheduleTask(identifier: BackgroundTaskService.exceptionDetectionIdentifier, interval: 15 * 60)
        }

        // Schedule initial runs for all tasks
        scheduleTask(identifier: BackgroundTaskService.slaCheckIdentifier, interval: 15 * 60)
        scheduleTask(identifier: BackgroundTaskService.mediaCleanupIdentifier, interval: 6 * 3600)
        scheduleTask(identifier: BackgroundTaskService.carpoolRecalcIdentifier, interval: 30 * 60)
        scheduleTask(identifier: BackgroundTaskService.varianceProcessingIdentifier, interval: 3600)
        scheduleTask(identifier: BackgroundTaskService.exceptionDetectionIdentifier, interval: 15 * 60)
    }

    private func scheduleTask(identifier: String, interval: TimeInterval) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Non-fatal: background task scheduling may not be available in all contexts
        }
    }
}
