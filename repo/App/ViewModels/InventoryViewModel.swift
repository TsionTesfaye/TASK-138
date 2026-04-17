import Foundation

final class InventoryViewModel: BaseViewModel {

    private(set) var tasks: [CountTask] = []
    private(set) var items: [InventoryItem] = []
    private(set) var variances: [Variance] = []
    private(set) var pendingOrders: [AdjustmentOrder] = []
    var site: String = ""

    override init(container: ServiceContainer) {
        super.init(container: container)
        site = container.currentSite
    }

    func loadTasks() {
        guard let user = currentUser() else { return }
        setState(.loading)
        switch container.inventoryService.findAllTasks(by: user, site: site) {
        case .success(let found):
            tasks = found
            setState(tasks.isEmpty ? .empty("No count tasks") : .loaded)
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
    }

    func loadItems() {
        guard let user = currentUser() else { return }
        switch container.inventoryService.findAllItems(by: user, site: site) {
        case .success(let found):
            items = found
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
    }

    func loadPendingVariances() {
        guard let user = currentUser() else { return }
        switch container.inventoryService.findPendingVariances(by: user, site: site) {
        case .success(let found):
            variances = found
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
        switch container.inventoryService.findApprovedOrders(by: user, site: site) {
        case .success(let found):
            pendingOrders = found
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
    }

    func createTask(assignedTo: UUID) -> ServiceResult<CountTask> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.createCountTask(by: user, site: site, assignedTo: assignedTo, operationId: UUID())
    }

    func createBatch(taskId: UUID) -> ServiceResult<CountBatch> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.createCountBatch(by: user, site: site, taskId: taskId, operationId: UUID())
    }

    func recordEntry(batchId: UUID, itemId: UUID, qty: Int, location: String, custodian: String) -> ServiceResult<CountEntry> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.recordCountEntry(
            by: user, site: site, batchId: batchId, itemId: itemId, countedQty: qty,
            countedLocation: location, countedCustodian: custodian, operationId: UUID()
        )
    }

    func scannerLookup(_ identifier: String) -> ServiceResult<InventoryItem> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.lookupByScanner(by: user, site: site, identifier: identifier)
    }

    func computeVariances(batchId: UUID) -> ServiceResult<[Variance]> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.computeVariances(by: user, site: site, forBatchId: batchId)
    }

    func approveVariance(varianceId: UUID) -> ServiceResult<AdjustmentOrder> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.approveVariance(by: user, site: site, varianceId: varianceId, operationId: UUID())
    }

    func executeAdjustment(orderId: UUID) -> ServiceResult<AdjustmentOrder> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.inventoryService.executeAdjustmentOrder(by: user, site: site, orderId: orderId, operationId: UUID())
    }
}
