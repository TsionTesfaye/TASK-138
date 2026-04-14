import Foundation

protocol AuditLogRepository {
    func findById(_ id: UUID) -> AuditLog?
    func findByEntityId(_ entityId: UUID) -> [AuditLog]
    func findByActorId(_ actorId: UUID) -> [AuditLog]
    func findTombstonesOlderThan(_ date: Date) -> [AuditLog]
    func findAll() -> [AuditLog]
    func save(_ log: AuditLog) throws
    func delete(_ id: UUID) throws
}

final class InMemoryAuditLogRepository: AuditLogRepository {
    private var store: [UUID: AuditLog] = [:]

    func findById(_ id: UUID) -> AuditLog? { store[id] }

    func findByEntityId(_ entityId: UUID) -> [AuditLog] {
        store.values.filter { $0.entityId == entityId && !$0.tombstone }
    }

    func findByActorId(_ actorId: UUID) -> [AuditLog] {
        store.values.filter { $0.actorId == actorId && !$0.tombstone }
    }

    func findTombstonesOlderThan(_ date: Date) -> [AuditLog] {
        store.values.filter { $0.tombstone && ($0.deletedAt.map { $0 < date } ?? false) }
    }

    func findAll() -> [AuditLog] { Array(store.values) }

    func save(_ log: AuditLog) throws { store[log.id] = log }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
