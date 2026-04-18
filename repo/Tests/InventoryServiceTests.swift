import Foundation

/// Tests for InventoryService: count entries, variance detection, threshold, approval, adjustment.
final class InventoryServiceTests {

    private let testSite = "lot-a"

    private func makeServices() -> (InventoryService, InMemoryInventoryItemRepository, InMemoryVarianceRepository, InMemoryAdjustmentOrderRepository, InMemoryPermissionScopeRepository) {
        let itemRepo = InMemoryInventoryItemRepository()
        let taskRepo = InMemoryCountTaskRepository()
        let batchRepo = InMemoryCountBatchRepository()
        let entryRepo = InMemoryCountEntryRepository()
        let varianceRepo = InMemoryVarianceRepository()
        let adjRepo = InMemoryAdjustmentOrderRepository()
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let auditService = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let opLogRepo = InMemoryOperationLogRepository()

        let service = InventoryService(
            inventoryItemRepo: itemRepo, countTaskRepo: taskRepo, countBatchRepo: batchRepo,
            countEntryRepo: entryRepo, varianceRepo: varianceRepo, adjustmentOrderRepo: adjRepo,
            permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo
        )
        return (service, itemRepo, varianceRepo, adjRepo, permScopeRepo)
    }

    private func grantScope(_ user: User, scopeRepo: InMemoryPermissionScopeRepository) {
        let scope = PermissionScope(id: UUID(), userId: user.id, site: testSite, functionKey: "inventory", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! scopeRepo.save(scope)
    }

    func runAll() {
        print("--- InventoryServiceTests ---")
        testScannerLookupValid()
        testScannerLookupInvalid()
        testVarianceSurplus()
        testVarianceShortage()
        testVarianceLocationMismatch()
        testVarianceCustodianMismatch()
        testVarianceThresholdNoApproval()
        testVarianceThresholdRequiresApproval()
        testVarianceThresholdPercent()
        testApproveVarianceAdmin()
        testApproveVarianceNonAdminDenied()
        testExecuteAdjustmentUpdatesQty()
        testCountEntryViaService()
        testBelowThresholdVarianceAutoAdjusted()
        testAboveThresholdVarianceRequiresApproval()
    }

    func testScannerLookupValid() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "VIN-12345", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)
        let result = service.lookupByScanner(by: clerk, site: testSite, identifier: "VIN-12345")
        let found = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(found.id == item.id)
        print("  PASS: testScannerLookupValid")
    }

    func testScannerLookupInvalid() {
        let (service, _, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let result = service.lookupByScanner(by: clerk, site: testSite, identifier: "NONEXISTENT")
        TestHelpers.assertFailure(result, code: "INV_SCAN_INVALID")
        print("  PASS: testScannerLookupInvalid")
    }

    func testVarianceSurplus() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "A1", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 15, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        TestHelpers.assert(variances.contains { $0.type == .surplus }, "Should detect surplus")
        print("  PASS: testVarianceSurplus")
    }

    func testVarianceShortage() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "A2", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 5, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        TestHelpers.assert(variances.contains { $0.type == .shortage }, "Should detect shortage")
        print("  PASS: testVarianceShortage")
    }

    func testVarianceLocationMismatch() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "A3", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 10, countedLocation: "Lot B", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        TestHelpers.assert(variances.contains { $0.type == .locationMismatch }, "Should detect location mismatch")
        print("  PASS: testVarianceLocationMismatch")
    }

    func testVarianceCustodianMismatch() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "A4", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 10, countedLocation: "Lot A", countedCustodian: "Alice", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        TestHelpers.assert(variances.contains { $0.type == .custodianMismatch }, "Should detect custodian mismatch")
        print("  PASS: testVarianceCustodianMismatch")
    }

    func testVarianceThresholdNoApproval() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "B1", expectedQty: 100, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 102, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let surplus = variances.first { $0.type == .surplus }!
        TestHelpers.assert(!surplus.requiresApproval, "Small variance should not require approval")
        print("  PASS: testVarianceThresholdNoApproval")
    }

    func testVarianceThresholdRequiresApproval() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "B2", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 15, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let surplus = variances.first { $0.type == .surplus }!
        TestHelpers.assert(surplus.requiresApproval, "Large variance should require approval")
        print("  PASS: testVarianceThresholdRequiresApproval")
    }

    func testVarianceThresholdPercent() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "B3", expectedQty: 500, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 515, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let surplus = variances.first { $0.type == .surplus }!
        TestHelpers.assert(surplus.requiresApproval, "Should require approval at 2% threshold")
        print("  PASS: testVarianceThresholdPercent")
    }

    func testApproveVarianceAdmin() {
        let (service, itemRepo, varianceRepo, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        let admin = TestHelpers.makeAdmin()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "C1", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 20, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!

        let result = service.approveVariance(by: admin, site: testSite, varianceId: v.id, operationId: UUID())
        let order = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(order.status == .approved)
        TestHelpers.assert(order.approvedBy == admin.id)
        print("  PASS: testApproveVarianceAdmin")
    }

    func testApproveVarianceNonAdminDenied() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "C2", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 20, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!

        let result = service.approveVariance(by: clerk, site: testSite, varianceId: v.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "PERM_ADMIN_REQ")
        print("  PASS: testApproveVarianceNonAdminDenied")
    }

    func testExecuteAdjustmentUpdatesQty() {
        let (service, itemRepo, _, adjRepo, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        let admin = TestHelpers.makeAdmin()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "D1", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 20, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!
        let order = TestHelpers.assertSuccess(service.approveVariance(by: admin, site: testSite, varianceId: v.id, operationId: UUID()))!

        let execResult = service.executeAdjustmentOrder(by: admin, site: testSite, orderId: order.id, operationId: UUID())
        let executed = TestHelpers.assertSuccess(execResult)!
        TestHelpers.assert(executed.status == .executed)

        let updatedItem = itemRepo.findById(item.id)!
        TestHelpers.assert(updatedItem.expectedQty == 20, "Expected qty should be updated to counted (20)")
        print("  PASS: testExecuteAdjustmentUpdatesQty")
    }

    func testCountEntryViaService() {
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "E1", expectedQty: 5, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        let entry = TestHelpers.assertSuccess(
            service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 5, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())
        )!
        TestHelpers.assert(entry.countedQty == 5)
        TestHelpers.assert(entry.batchId == batch.id)
        print("  PASS: testCountEntryViaService")
    }

    func testBelowThresholdVarianceAutoAdjusted() {
        // expectedQty=100, countedQty=102 → diff=2, threshold=max(3,2)=3 → 2<=3 → requiresApproval=false
        // Auto-processing happens inline during computeVariances — no manual processVariance call needed
        let (service, itemRepo, _, adjRepo, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: testSite, identifier: "F1", expectedQty: 100, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 102, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!
        TestHelpers.assert(!v.requiresApproval, "Should be below threshold")
        TestHelpers.assert(v.approved, "Below-threshold variance should be auto-approved during computeVariances")
        TestHelpers.assert(itemRepo.findById(item.id)!.expectedQty == 102, "Item qty should be updated to counted qty during computeVariances")
        let autoOrder = adjRepo.findByVarianceId(v.id)
        TestHelpers.assert(autoOrder?.status == .executed, "Auto-adjustment order should be created with executed status")
        print("  PASS: testBelowThresholdVarianceAutoAdjusted")
    }

    func testAboveThresholdVarianceRequiresApproval() {
        // expectedQty=10, countedQty=15 → diff=5, threshold=max(3,0.2)=3 → 5>3 → requiresApproval=true
        let (service, itemRepo, _, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, scopeRepo: scopeRepo)
        let item = InventoryItem(id: UUID(), siteId: testSite, identifier: "F2", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        let task = TestHelpers.assertSuccess(service.createCountTask(by: clerk, site: testSite, assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(service.createCountBatch(by: clerk, site: testSite, taskId: task.id, operationId: UUID()))!
        _ = service.recordCountEntry(by: clerk, site: testSite, batchId: batch.id, itemId: item.id, countedQty: 15, countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID())

        let variances = TestHelpers.assertSuccess(service.computeVariances(by: clerk, site: testSite, forBatchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!
        TestHelpers.assert(v.requiresApproval, "Should be above threshold")

        let result = service.processVariance(by: clerk, site: testSite, varianceId: v.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "INV_APPROVAL_REQ")
        print("  PASS: testAboveThresholdVarianceRequiresApproval")
    }
}
