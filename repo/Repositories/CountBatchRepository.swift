import Foundation

protocol CountBatchRepository {
    func findById(_ id: UUID) -> CountBatch?
    func findByTaskId(_ taskId: UUID) -> [CountBatch]
    func findBySiteId(_ siteId: String) -> [CountBatch]
    func save(_ batch: CountBatch) throws
    func delete(_ id: UUID) throws
}

final class InMemoryCountBatchRepository: CountBatchRepository {
    private var store: [UUID: CountBatch] = [:]

    func findById(_ id: UUID) -> CountBatch? { store[id] }

    func findByTaskId(_ taskId: UUID) -> [CountBatch] {
        store.values.filter { $0.taskId == taskId }
    }

    func findBySiteId(_ siteId: String) -> [CountBatch] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ batch: CountBatch) throws { store[batch.id] = batch }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
