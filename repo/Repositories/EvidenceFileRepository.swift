import Foundation

protocol EvidenceFileRepository {
    func findById(_ id: UUID) -> EvidenceFile?
    func findById(_ id: UUID, siteId: String) -> EvidenceFile?
    func findByEntity(entityId: UUID, entityType: String) -> [EvidenceFile]
    func findByEntity(entityId: UUID, entityType: String, siteId: String) -> [EvidenceFile]
    func findUnpinnedOlderThan(_ date: Date) -> [EvidenceFile]
    func findBySiteId(_ siteId: String) -> [EvidenceFile]
    func findAll() -> [EvidenceFile]
    func save(_ file: EvidenceFile) throws
    func delete(_ id: UUID) throws
}

final class InMemoryEvidenceFileRepository: EvidenceFileRepository {
    private var store: [UUID: EvidenceFile] = [:]

    func findById(_ id: UUID) -> EvidenceFile? { store[id] }

    func findById(_ id: UUID, siteId: String) -> EvidenceFile? {
        guard let file = store[id], file.siteId == siteId else { return nil }
        return file
    }

    func findByEntity(entityId: UUID, entityType: String) -> [EvidenceFile] {
        store.values.filter { $0.entityId == entityId && $0.entityType == entityType }
    }

    func findByEntity(entityId: UUID, entityType: String, siteId: String) -> [EvidenceFile] {
        store.values.filter { $0.entityId == entityId && $0.entityType == entityType && $0.siteId == siteId }
    }

    func findUnpinnedOlderThan(_ date: Date) -> [EvidenceFile] {
        store.values.filter { !$0.pinnedByAdmin && $0.createdAt < date }
    }

    func findBySiteId(_ siteId: String) -> [EvidenceFile] {
        store.values.filter { $0.siteId == siteId }
    }

    func findAll() -> [EvidenceFile] { Array(store.values) }

    func save(_ file: EvidenceFile) throws { store[file.id] = file }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
