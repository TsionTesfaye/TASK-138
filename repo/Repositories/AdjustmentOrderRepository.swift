import Foundation

protocol AdjustmentOrderRepository {
    func findById(_ id: UUID) -> AdjustmentOrder?
    func findByVarianceId(_ varianceId: UUID) -> AdjustmentOrder?
    func findByStatus(_ status: AdjustmentOrderStatus) -> [AdjustmentOrder]
    func findAll() -> [AdjustmentOrder]
    func findBySiteId(_ siteId: String) -> [AdjustmentOrder]
    func save(_ order: AdjustmentOrder) throws
    func delete(_ id: UUID) throws
}

final class InMemoryAdjustmentOrderRepository: AdjustmentOrderRepository {
    private var store: [UUID: AdjustmentOrder] = [:]

    func findById(_ id: UUID) -> AdjustmentOrder? { store[id] }

    func findByVarianceId(_ varianceId: UUID) -> AdjustmentOrder? {
        store.values.first { $0.varianceId == varianceId }
    }

    func findByStatus(_ status: AdjustmentOrderStatus) -> [AdjustmentOrder] {
        store.values.filter { $0.status == status }
    }

    func findAll() -> [AdjustmentOrder] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [AdjustmentOrder] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ order: AdjustmentOrder) throws { store[order.id] = order }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
