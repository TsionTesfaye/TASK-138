import Foundation

/// design.md 4.6, questions.md Q18-Q21
/// Manages inventory counts, variance detection, and adjustment orders.
/// Uses CountEntry (NOT CountBatch directly) for count data.
final class InventoryService {

    private let inventoryItemRepo: InventoryItemRepository
    private let countTaskRepo: CountTaskRepository
    private let countBatchRepo: CountBatchRepository
    private let countEntryRepo: CountEntryRepository
    let varianceRepo: VarianceRepository
    private let adjustmentOrderRepo: AdjustmentOrderRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        inventoryItemRepo: InventoryItemRepository,
        countTaskRepo: CountTaskRepository,
        countBatchRepo: CountBatchRepository,
        countEntryRepo: CountEntryRepository,
        varianceRepo: VarianceRepository,
        adjustmentOrderRepo: AdjustmentOrderRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.inventoryItemRepo = inventoryItemRepo
        self.countTaskRepo = countTaskRepo
        self.countBatchRepo = countBatchRepo
        self.countEntryRepo = countEntryRepo
        self.varianceRepo = varianceRepo
        self.adjustmentOrderRepo = adjustmentOrderRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Count Task

    func createCountTask(
        by user: User,
        site: String,
        assignedTo: UUID,
        operationId: UUID
    ) -> ServiceResult<CountTask> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }

        let task = CountTask(id: UUID(), siteId: site, assignedTo: assignedTo, status: .pending)

        do {
            try countTaskRepo.save(task)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "count_task_created", entityId: task.id)
            return .success(task)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Count Batch

    func createCountBatch(
        by user: User,
        site: String,
        taskId: UUID,
        operationId: UUID
    ) -> ServiceResult<CountBatch> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }

        guard let task = countTaskRepo.findById(taskId) else {
            return .failure(.entityNotFound)
        }
        guard task.siteId == site else { return .failure(.permissionDenied) }

        guard task.status == .pending || task.status == .inProgress else {
            return .failure(.invalidTransition)
        }

        let batch = CountBatch(id: UUID(), siteId: site, taskId: taskId, createdAt: Date())

        do {
            try countBatchRepo.save(batch)
            try operationLogRepo.save(operationId)

            // Move task to in-progress if pending
            if task.status == .pending {
                var updatedTask = task
                updatedTask.status = .inProgress
                try countTaskRepo.save(updatedTask)
            }

            auditService.log(actorId: user.id, action: "count_batch_created", entityId: batch.id)
            return .success(batch)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Count Entry (uses CountEntry, NOT CountBatch)

    func recordCountEntry(
        by user: User,
        site: String,
        batchId: UUID,
        itemId: UUID,
        countedQty: Int,
        countedLocation: String,
        countedCustodian: String,
        operationId: UUID
    ) -> ServiceResult<CountEntry> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }

        guard let batch = countBatchRepo.findById(batchId) else {
            return .failure(.entityNotFound)
        }
        guard batch.siteId == site else { return .failure(.permissionDenied) }

        guard let item = inventoryItemRepo.findById(itemId) else {
            return .failure(.entityNotFound)
        }
        guard item.siteId == site else { return .failure(.permissionDenied) }

        let entry = CountEntry(
            id: UUID(),
            siteId: site,
            batchId: batchId,
            itemId: itemId,
            countedQty: countedQty,
            countedLocation: countedLocation,
            countedCustodian: countedCustodian
        )

        do {
            try countEntryRepo.save(entry)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "count_entry_recorded", entityId: entry.id)
            return .success(entry)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Scanner Input (questions.md Q21)

    /// Accept plain text identifier and look up inventory item.
    /// Invalid scans rejected.
    func lookupByScanner(by user: User, site: String, identifier: String) -> ServiceResult<InventoryItem> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }

        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.invalidScanInput)
        }
        guard let item = inventoryItemRepo.findByIdentifier(trimmed) else {
            return .failure(.invalidScanInput)
        }
        guard item.siteId == site else { return .failure(.permissionDenied) }
        return .success(item)
    }

    // MARK: - Variance Computation (questions.md Q19, Q20)

    /// Compute variances for all entries in a batch.
    /// Detects: surplus, shortage, location mismatch, custodian mismatch.
    /// Threshold: max(3 units, 2% of expected) → requires admin approval.
    func computeVariances(by user: User, site: String, forBatchId batchId: UUID) -> ServiceResult<[Variance]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }

        let entries = countEntryRepo.findByBatchId(batchId)
        var variances: [Variance] = []

        for entry in entries {
            guard let item = inventoryItemRepo.findById(entry.itemId) else { continue }

            let diff = entry.countedQty - item.expectedQty

            // Detect quantity variance
            if diff != 0 {
                let varianceType: VarianceType = diff > 0 ? .surplus : .shortage
                let absDiff = abs(diff)
                let percentThreshold = max(Double(item.expectedQty) * 0.02, 0)
                let unitThreshold = 3
                let threshold = max(unitThreshold, Int(ceil(percentThreshold)))
                let requiresApproval = absDiff > threshold

                let variance = Variance(
                    id: UUID(),
                    siteId: site,
                    itemId: item.id,
                    expectedQty: item.expectedQty,
                    countedQty: entry.countedQty,
                    type: varianceType,
                    requiresApproval: requiresApproval,
                    approved: false
                )
                do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_variance", error: error) }
                variances.append(variance)
            }

            // Detect location mismatch
            if entry.countedLocation != item.location {
                let variance = Variance(
                    id: UUID(),
                    siteId: site,
                    itemId: item.id,
                    expectedQty: item.expectedQty,
                    countedQty: entry.countedQty,
                    type: .locationMismatch,
                    requiresApproval: true,
                    approved: false
                )
                do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_variance", error: error) }
                variances.append(variance)
            }

            // Detect custodian mismatch
            if entry.countedCustodian != item.custodian {
                let variance = Variance(
                    id: UUID(),
                    siteId: site,
                    itemId: item.id,
                    expectedQty: item.expectedQty,
                    countedQty: entry.countedQty,
                    type: .custodianMismatch,
                    requiresApproval: true,
                    approved: false
                )
                do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_variance", error: error) }
                variances.append(variance)
            }
        }

        return .success(variances)
    }

    // MARK: - Approve Variance (admin only)

    func approveVariance(
        by user: User,
        site: String,
        varianceId: UUID,
        operationId: UUID
    ) -> ServiceResult<AdjustmentOrder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.requireAdmin(user: user) {
            return .failure(err)
        }

        guard var variance = varianceRepo.findById(varianceId) else {
            return .failure(.entityNotFound)
        }
        guard variance.siteId == site else { return .failure(.permissionDenied) }

        guard variance.requiresApproval else {
            return .failure(ServiceError(code: "INV_NO_APPROVAL", message: "Variance does not require approval"))
        }

        variance.approved = true
        do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_variance", error: error) }

        // Create adjustment order
        let order = AdjustmentOrder(
            id: UUID(),
            siteId: site,
            varianceId: varianceId,
            approvedBy: user.id,
            createdAt: Date(),
            status: .approved
        )

        do {
            try adjustmentOrderRepo.save(order)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "variance_approved", entityId: varianceId)
            auditService.log(actorId: user.id, action: "adjustment_order_created", entityId: order.id)
            return .success(order)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Execute Adjustment Order

    /// Executing an approved adjustment updates InventoryItem.expectedQty.
    /// design.md 3.14: when executed → update InventoryItem.expectedQty
    func executeAdjustmentOrder(
        by user: User,
        site: String,
        orderId: UUID,
        operationId: UUID
    ) -> ServiceResult<AdjustmentOrder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.requireAdmin(user: user) {
            return .failure(err)
        }

        guard var order = adjustmentOrderRepo.findById(orderId) else {
            return .failure(.entityNotFound)
        }
        guard order.siteId == site else { return .failure(.permissionDenied) }

        guard order.status == .approved else {
            return .failure(.invalidTransition)
        }

        guard let variance = varianceRepo.findById(order.varianceId) else {
            return .failure(.entityNotFound)
        }

        guard var item = inventoryItemRepo.findById(variance.itemId) else {
            return .failure(.entityNotFound)
        }

        // Update inventory item quantity to match counted
        item.expectedQty = variance.countedQty
        order.status = .executed

        do {
            try inventoryItemRepo.save(item)
            try adjustmentOrderRepo.save(order)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "adjustment_order_executed", entityId: orderId)
            return .success(order)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Query

    func findAllTasks(by user: User, site: String) -> ServiceResult<[CountTask]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }
        let all = countTaskRepo.findAll().filter { $0.siteId == site }
        // Admins see all tasks; clerks see only tasks assigned to them
        if user.role == .administrator { return .success(all) }
        return .success(all.filter { $0.assignedTo == user.id })
    }

    func findAllItems(by user: User, site: String) -> ServiceResult<[InventoryItem]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }
        return .success(inventoryItemRepo.findAll().filter { $0.siteId == site })
    }

    func findPendingVariances(by user: User, site: String) -> ServiceResult<[Variance]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }
        return .success(varianceRepo.findPendingApproval().filter { $0.siteId == site })
    }

    func findApprovedOrders(by user: User, site: String) -> ServiceResult<[AdjustmentOrder]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .inventory,
            site: site, functionKey: "inventory"
        ) {
            return .failure(err)
        }
        return .success(adjustmentOrderRepo.findByStatus(.approved).filter { $0.siteId == site })
    }

    // MARK: - Deferred Variance Processing (background task)

    /// System-initiated variance computation for in-progress count tasks.
    /// Finds all in-progress tasks, iterates their batches, and computes variances
    /// for any batch that has entries but no variances yet.
    /// Returns (batchesProcessed, variancesFound).
    func computeDeferredVariances() -> (batchesProcessed: Int, variancesFound: Int) {
        let inProgressTasks = countTaskRepo.findByStatus(.inProgress)
        var batchesProcessed = 0
        var totalVariances = 0

        for task in inProgressTasks {
            let batches = countBatchRepo.findByTaskId(task.id)

            for batch in batches {
                let entries = countEntryRepo.findByBatchId(batch.id)
                guard !entries.isEmpty else { continue }

                // Skip batches that already have variances computed
                let existingVariances = entries.flatMap { varianceRepo.findByItemId($0.itemId) }
                if !existingVariances.isEmpty { continue }

                // Compute variances for this batch (same algorithm as user-initiated)
                for entry in entries {
                    guard let item = inventoryItemRepo.findById(entry.itemId) else { continue }

                    let diff = entry.countedQty - item.expectedQty

                    if diff != 0 {
                        let varianceType: VarianceType = diff > 0 ? .surplus : .shortage
                        let absDiff = abs(diff)
                        let percentThreshold = max(Double(item.expectedQty) * 0.02, 0)
                        let unitThreshold = 3
                        let threshold = max(unitThreshold, Int(ceil(percentThreshold)))
                        let requiresApproval = absDiff > threshold

                        let variance = Variance(
                            id: UUID(), siteId: task.siteId, itemId: item.id,
                            expectedQty: item.expectedQty, countedQty: entry.countedQty,
                            type: varianceType, requiresApproval: requiresApproval, approved: false
                        )
                        do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_deferred_variance", error: error) }
                        totalVariances += 1
                    }

                    if entry.countedLocation != item.location {
                        let variance = Variance(
                            id: UUID(), siteId: task.siteId, itemId: item.id,
                            expectedQty: item.expectedQty, countedQty: entry.countedQty,
                            type: .locationMismatch, requiresApproval: true, approved: false
                        )
                        do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_deferred_variance", error: error) }
                        totalVariances += 1
                    }

                    if entry.countedCustodian != item.custodian {
                        let variance = Variance(
                            id: UUID(), siteId: task.siteId, itemId: item.id,
                            expectedQty: item.expectedQty, countedQty: entry.countedQty,
                            type: .custodianMismatch, requiresApproval: true, approved: false
                        )
                        do { try varianceRepo.save(variance) } catch { ServiceLogger.persistenceError(ServiceLogger.inventory, operation: "save_deferred_variance", error: error) }
                        totalVariances += 1
                    }
                }

                batchesProcessed += 1
            }
        }

        return (batchesProcessed: batchesProcessed, variancesFound: totalVariances)
    }
}
