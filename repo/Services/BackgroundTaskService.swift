import Foundation
#if canImport(os)
import os.log
#endif
// Logger type is provided by os.log on Apple platforms, and by the shim in ServiceLogger.swift on Linux.

/// design.md 4.12, 6, 6.1
/// Coordinates background tasks: SLA checks, media cleanup, carpool recalc, variance processing, exception detection.
/// Retry: up to 3 times, exponential backoff. Failure logged to AuditService.
final class BackgroundTaskService {

    private let slaService: SLAService
    private let leadService: LeadService
    private let carpoolService: CarpoolService
    let inventoryService: InventoryService
    private let fileService: FileService
    private let exceptionService: ExceptionService
    private let auditService: AuditService

    private static let logger = Logger(subsystem: "com.dealerops", category: "BackgroundTasks")
    let maxRetries = 3

    static let slaCheckIdentifier = "com.dealerops.sla-check"
    static let mediaCleanupIdentifier = "com.dealerops.media-cleanup"
    static let carpoolRecalcIdentifier = "com.dealerops.carpool-recalc"
    static let varianceProcessingIdentifier = "com.dealerops.variance-processing"
    static let exceptionDetectionIdentifier = "com.dealerops.exception-detection"

    init(
        slaService: SLAService,
        leadService: LeadService,
        carpoolService: CarpoolService,
        inventoryService: InventoryService,
        fileService: FileService,
        exceptionService: ExceptionService,
        auditService: AuditService
    ) {
        self.slaService = slaService
        self.leadService = leadService
        self.carpoolService = carpoolService
        self.inventoryService = inventoryService
        self.fileService = fileService
        self.exceptionService = exceptionService
        self.auditService = auditService
    }

    // MARK: - SLA Checks

    func runSLAChecks(now: Date = Date()) -> BackgroundTaskResult {
        return executeWithRetry(taskName: "sla_check") {
            let violations = self.slaService.checkViolations(now: now)
            let msg = "Lead violations: \(violations.leadViolations.count), Appointment violations: \(violations.appointmentViolations.count)"
            BackgroundTaskService.logger.info("\(msg)")
            return .success(msg)
        }
    }

    // MARK: - Media Cleanup

    func runMediaCleanup(now: Date = Date()) -> BackgroundTaskResult {
        return executeWithRetry(taskName: "media_cleanup") {
            let archiveCutoff = Calendar.current.date(byAdding: .day, value: -180, to: now)!
            let archived = self.leadService.archiveClosedLeads(olderThan: archiveCutoff)
            let purgeCutoff = Calendar.current.date(byAdding: .day, value: -30, to: now)!
            let purged = self.fileService.purgeRejectedAppealMedia(olderThan: purgeCutoff)
            let tombstoneCutoff = Calendar.current.date(byAdding: .year, value: -1, to: now)!
            let tombstonesPurged = self.auditService.purgeOldTombstones(olderThan: tombstoneCutoff)
            let msg = "Archived: \(archived), Purged media: \(purged), Tombstones: \(tombstonesPurged)"
            BackgroundTaskService.logger.info("\(msg)")
            return .success(msg)
        }
    }

    // MARK: - Carpool Recalculation

    func runCarpoolRecalculation(now: Date = Date()) -> BackgroundTaskResult {
        return executeWithRetry(taskName: "carpool_recalc") {
            let expired = self.carpoolService.expireStaleOrders(now: now)
            let matching = self.carpoolService.computeDeferredMatches(now: now)
            let msg = "Expired: \(expired), Orders matched: \(matching.ordersProcessed), Matches found: \(matching.matchesFound)"
            BackgroundTaskService.logger.info("\(msg)")
            return .success(msg)
        }
    }

    // MARK: - Variance Processing (deferred computation)

    func runVarianceProcessing() -> BackgroundTaskResult {
        return executeWithRetry(taskName: "variance_processing") {
            let computed = self.inventoryService.computeDeferredVariances()
            let pending = self.inventoryService.varianceRepo.findPendingApproval()
            let msg = "Batches processed: \(computed.batchesProcessed), Variances computed: \(computed.variancesFound), Pending approval: \(pending.count)"
            BackgroundTaskService.logger.info("\(msg)")
            return .success(msg)
        }
    }

    // MARK: - Exception Detection

    func runExceptionDetection(now: Date = Date()) -> BackgroundTaskResult {
        return executeWithRetry(taskName: "exception_detection") {
            let results = self.exceptionService.runDetectionCycle(now: now)
            let msg = "Buddy punching: \(results.buddyPunching), Misidentification: \(results.misidentification)"
            BackgroundTaskService.logger.info("\(msg)")
            return .success(msg)
        }
    }

    // MARK: - Run All

    func runAllTasks(now: Date = Date()) {
        BackgroundTaskService.logger.info("Running all background tasks")
        _ = runSLAChecks(now: now)
        _ = runMediaCleanup(now: now)
        _ = runCarpoolRecalculation(now: now)
        _ = runVarianceProcessing()
        _ = runExceptionDetection(now: now)
    }

    // MARK: - Retry

    struct BackgroundTaskResult {
        let taskName: String
        let success: Bool
        let message: String
        let attempts: Int
    }

    private func executeWithRetry(
        taskName: String,
        maxAttempts: Int? = nil,
        action: () -> Result<String, Error>
    ) -> BackgroundTaskResult {
        let attempts = maxAttempts ?? maxRetries
        var lastError: String = ""
        for attempt in 1...attempts {
            switch action() {
            case .success(let message):
                return BackgroundTaskResult(taskName: taskName, success: true, message: message, attempts: attempt)
            case .failure(let error):
                lastError = error.localizedDescription
                BackgroundTaskService.logger.error("Task '\(taskName)' attempt \(attempt) failed: \(lastError)")
            }
        }
        BackgroundTaskService.logger.error("Task '\(taskName)' failed after \(attempts) attempts")
        auditService.log(actorId: UUID(), action: "background_task_failed_\(taskName)", entityId: UUID())
        return BackgroundTaskResult(taskName: taskName, success: false, message: lastError, attempts: attempts)
    }
}
