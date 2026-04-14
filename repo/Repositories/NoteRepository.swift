import Foundation

protocol NoteRepository {
    func findById(_ id: UUID) -> Note?
    func findByEntity(entityId: UUID, entityType: String) -> [Note]
    func findAll() -> [Note]
    func save(_ note: Note) throws
    func delete(_ id: UUID) throws
}

final class InMemoryNoteRepository: NoteRepository {
    private var store: [UUID: Note] = [:]

    func findById(_ id: UUID) -> Note? { store[id] }

    func findByEntity(entityId: UUID, entityType: String) -> [Note] {
        store.values.filter { $0.entityId == entityId && $0.entityType == entityType }
    }

    func findAll() -> [Note] { Array(store.values) }

    func save(_ note: Note) throws { store[note.id] = note }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
