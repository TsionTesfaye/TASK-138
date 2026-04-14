import Foundation

protocol CountEntryRepository {
    func findById(_ id: UUID) -> CountEntry?
    func findByBatchId(_ batchId: UUID) -> [CountEntry]
    func findByItemId(_ itemId: UUID) -> [CountEntry]
    func findBySiteId(_ siteId: String) -> [CountEntry]
    func save(_ entry: CountEntry) throws
    func delete(_ id: UUID) throws
}

final class InMemoryCountEntryRepository: CountEntryRepository {
    private var store: [UUID: CountEntry] = [:]

    func findById(_ id: UUID) -> CountEntry? { store[id] }

    func findByBatchId(_ batchId: UUID) -> [CountEntry] {
        store.values.filter { $0.batchId == batchId }
    }

    func findByItemId(_ itemId: UUID) -> [CountEntry] {
        store.values.filter { $0.itemId == itemId }
    }

    func findBySiteId(_ siteId: String) -> [CountEntry] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ entry: CountEntry) throws { store[entry.id] = entry }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
