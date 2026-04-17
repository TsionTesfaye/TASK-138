import Foundation

/// Tests for BackgroundTaskService: SLA checks, media cleanup, variance processing, exception detection.
final class BackgroundTaskServiceTests {

    private func makeService() -> BackgroundTaskService {
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permService = PermissionService(permissionScopeRepo: InMemoryPermissionScopeRepository())
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let leadRepo = InMemoryLeadRepository()
        let apptRepo = InMemoryAppointmentRepository()
        let reminderRepo = InMemoryReminderRepository()
        let opLogRepo = InMemoryOperationLogRepository()

        let slaService = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        let leadService = LeadService(leadRepo: leadRepo, permissionService: permService, slaService: slaService, auditService: auditService, operationLogRepo: opLogRepo, reminderRepo: reminderRepo)

        let poolOrderRepo = InMemoryPoolOrderRepository()
        let matchRepo = InMemoryCarpoolMatchRepository()
        let carpoolService = CarpoolService(poolOrderRepo: poolOrderRepo, carpoolMatchRepo: matchRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)

        let itemRepo = InMemoryInventoryItemRepository()
        let taskRepo = InMemoryCountTaskRepository()
        let batchRepo = InMemoryCountBatchRepository()
        let entryRepo = InMemoryCountEntryRepository()
        let varianceRepo = InMemoryVarianceRepository()
        let adjRepo = InMemoryAdjustmentOrderRepository()
        let inventoryService = InventoryService(inventoryItemRepo: itemRepo, countTaskRepo: taskRepo, countBatchRepo: batchRepo, countEntryRepo: entryRepo, varianceRepo: varianceRepo, adjustmentOrderRepo: adjRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)

        let evidenceRepo = InMemoryEvidenceFileRepository()
        let appealRepo = InMemoryAppealRepository()
        let fileService = FileService(evidenceFileRepo: evidenceRepo, appealRepo: appealRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)

        let exceptionCaseRepo = InMemoryExceptionCaseRepository()
        let checkInRepo = InMemoryCheckInRepository()
        let exceptionService = ExceptionService(exceptionCaseRepo: exceptionCaseRepo, checkInRepo: checkInRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)

        return BackgroundTaskService(slaService: slaService, leadService: leadService, carpoolService: carpoolService, inventoryService: inventoryService, fileService: fileService, exceptionService: exceptionService, auditService: auditService)
    }

    func runAll() {
        print("--- BackgroundTaskServiceTests ---")
        testRunSLAChecks()
        testRunMediaCleanup()
        testRunCarpoolRecalculation()
        testRunVarianceProcessing()
        testRunExceptionDetection()
        testRunAllTasks()
    }

    func testRunSLAChecks() {
        let service = makeService()
        let result = service.runSLAChecks()
        TestHelpers.assert(result.success, "SLA check should succeed")
        TestHelpers.assert(result.taskName == "sla_check")
        print("  PASS: testRunSLAChecks")
    }

    func testRunMediaCleanup() {
        let service = makeService()
        let result = service.runMediaCleanup()
        TestHelpers.assert(result.success, "Media cleanup should succeed")
        TestHelpers.assert(result.taskName == "media_cleanup")
        print("  PASS: testRunMediaCleanup")
    }

    func testRunCarpoolRecalculation() {
        let service = makeService()
        let result = service.runCarpoolRecalculation()
        TestHelpers.assert(result.success)
        TestHelpers.assert(result.taskName == "carpool_recalc")
        print("  PASS: testRunCarpoolRecalculation")
    }

    func testRunVarianceProcessing() {
        let service = makeService()
        let result = service.runVarianceProcessing()
        TestHelpers.assert(result.success, "Variance processing should succeed")
        TestHelpers.assert(result.taskName == "variance_processing")
        print("  PASS: testRunVarianceProcessing")
    }

    func testRunExceptionDetection() {
        let service = makeService()
        let result = service.runExceptionDetection()
        TestHelpers.assert(result.success, "Exception detection should succeed")
        TestHelpers.assert(result.taskName == "exception_detection")
        print("  PASS: testRunExceptionDetection")
    }

    func testRunAllTasks() {
        let service = makeService()
        // Should not crash
        service.runAllTasks()
        print("  PASS: testRunAllTasks")
    }
}
