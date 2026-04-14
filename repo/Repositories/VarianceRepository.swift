import Foundation

protocol VarianceRepository {
    func findById(_ id: UUID) -> Variance?
    func findByItemId(_ itemId: UUID) -> [Variance]
    func findPendingApproval() -> [Variance]
    func findAll() -> [Variance]
    func findBySiteId(_ siteId: String) -> [Variance]
    func save(_ variance: Variance) throws
    func delete(_ id: UUID) throws
}

final class InMemoryVarianceRepository: VarianceRepository {
    private var store: [UUID: Variance] = [:]

    func findById(_ id: UUID) -> Variance? { store[id] }

    func findByItemId(_ itemId: UUID) -> [Variance] {
        store.values.filter { $0.itemId == itemId }
    }

    func findPendingApproval() -> [Variance] {
        store.values.filter { $0.requiresApproval && !$0.approved }
    }

    func findAll() -> [Variance] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [Variance] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ variance: Variance) throws { store[variance.id] = variance }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
