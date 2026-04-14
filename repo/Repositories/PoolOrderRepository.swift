import Foundation

protocol PoolOrderRepository {
    func findById(_ id: UUID) -> PoolOrder?
    func findById(_ id: UUID, siteId: String) -> PoolOrder?
    func findByStatus(_ status: PoolOrderStatus) -> [PoolOrder]
    func findActiveInTimeWindow(start: Date, end: Date) -> [PoolOrder]
    func findActiveInTimeWindow(start: Date, end: Date, siteId: String) -> [PoolOrder]
    func findExpiredBefore(_ date: Date) -> [PoolOrder]
    func findAll() -> [PoolOrder]
    func findBySiteId(_ siteId: String) -> [PoolOrder]
    func save(_ order: PoolOrder) throws
    func delete(_ id: UUID) throws
}

final class InMemoryPoolOrderRepository: PoolOrderRepository {
    private var store: [UUID: PoolOrder] = [:]

    func findById(_ id: UUID) -> PoolOrder? { store[id] }

    func findById(_ id: UUID, siteId: String) -> PoolOrder? {
        guard let order = store[id], order.siteId == siteId else { return nil }
        return order
    }

    func findByStatus(_ status: PoolOrderStatus) -> [PoolOrder] {
        store.values.filter { $0.status == status }
    }

    func findActiveInTimeWindow(start: Date, end: Date) -> [PoolOrder] {
        store.values.filter {
            $0.status == .active &&
            $0.startTime <= end &&
            $0.endTime >= start
        }
    }

    func findActiveInTimeWindow(start: Date, end: Date, siteId: String) -> [PoolOrder] {
        store.values.filter {
            $0.status == .active &&
            $0.startTime <= end &&
            $0.endTime >= start &&
            $0.siteId == siteId
        }
    }

    func findExpiredBefore(_ date: Date) -> [PoolOrder] {
        store.values.filter {
            $0.status == .active && $0.endTime < date
        }
    }

    func findAll() -> [PoolOrder] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [PoolOrder] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ order: PoolOrder) throws { store[order.id] = order }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
