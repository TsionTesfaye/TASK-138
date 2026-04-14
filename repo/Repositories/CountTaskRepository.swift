import Foundation

protocol CountTaskRepository {
    func findById(_ id: UUID) -> CountTask?
    func findByAssignedTo(_ userId: UUID) -> [CountTask]
    func findByStatus(_ status: CountTaskStatus) -> [CountTask]
    func findAll() -> [CountTask]
    func findBySiteId(_ siteId: String) -> [CountTask]
    func save(_ task: CountTask) throws
    func delete(_ id: UUID) throws
}

final class InMemoryCountTaskRepository: CountTaskRepository {
    private var store: [UUID: CountTask] = [:]

    func findById(_ id: UUID) -> CountTask? { store[id] }

    func findByAssignedTo(_ userId: UUID) -> [CountTask] {
        store.values.filter { $0.assignedTo == userId }
    }

    func findByStatus(_ status: CountTaskStatus) -> [CountTask] {
        store.values.filter { $0.status == status }
    }

    func findAll() -> [CountTask] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [CountTask] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ task: CountTask) throws { store[task.id] = task }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
