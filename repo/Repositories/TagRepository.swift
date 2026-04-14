import Foundation

protocol TagRepository {
    func findById(_ id: UUID) -> Tag?
    func findByName(_ name: String) -> Tag?
    func findAll() -> [Tag]
    func save(_ tag: Tag) throws
    func delete(_ id: UUID) throws

    func findAssignments(entityId: UUID, entityType: String) -> [TagAssignment]
    func findAssignmentsByTag(_ tagId: UUID) -> [TagAssignment]
    func saveAssignment(_ assignment: TagAssignment) throws
    func deleteAssignment(tagId: UUID, entityId: UUID, entityType: String) throws
}

final class InMemoryTagRepository: TagRepository {
    private var tagStore: [UUID: Tag] = [:]
    private var assignments: [TagAssignment] = []

    func findById(_ id: UUID) -> Tag? { tagStore[id] }

    func findByName(_ name: String) -> Tag? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return tagStore.values.first { $0.name == normalized }
    }

    func findAll() -> [Tag] { Array(tagStore.values) }

    func save(_ tag: Tag) throws { tagStore[tag.id] = tag }

    func delete(_ id: UUID) throws { tagStore.removeValue(forKey: id) }

    func findAssignments(entityId: UUID, entityType: String) -> [TagAssignment] {
        assignments.filter { $0.entityId == entityId && $0.entityType == entityType }
    }

    func findAssignmentsByTag(_ tagId: UUID) -> [TagAssignment] {
        assignments.filter { $0.tagId == tagId }
    }

    func saveAssignment(_ assignment: TagAssignment) throws {
        // Prevent duplicates
        if !assignments.contains(where: {
            $0.tagId == assignment.tagId &&
            $0.entityId == assignment.entityId &&
            $0.entityType == assignment.entityType
        }) {
            assignments.append(assignment)
        }
    }

    func deleteAssignment(tagId: UUID, entityId: UUID, entityType: String) throws {
        assignments.removeAll {
            $0.tagId == tagId && $0.entityId == entityId && $0.entityType == entityType
        }
    }
}
