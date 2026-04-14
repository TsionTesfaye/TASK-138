import Foundation

protocol ReminderRepository {
    func findById(_ id: UUID) -> Reminder?
    func findByEntity(entityId: UUID, entityType: String) -> [Reminder]
    func findDueReminders(before date: Date) -> [Reminder]
    func findPendingByEntity(entityId: UUID, entityType: String) -> [Reminder]
    func findAll() -> [Reminder]
    func save(_ reminder: Reminder) throws
    func delete(_ id: UUID) throws
}

final class InMemoryReminderRepository: ReminderRepository {
    private var store: [UUID: Reminder] = [:]

    func findById(_ id: UUID) -> Reminder? { store[id] }

    func findByEntity(entityId: UUID, entityType: String) -> [Reminder] {
        store.values.filter { $0.entityId == entityId && $0.entityType == entityType }
    }

    func findDueReminders(before date: Date) -> [Reminder] {
        store.values.filter { $0.status == .pending && $0.dueAt <= date }
    }

    func findPendingByEntity(entityId: UUID, entityType: String) -> [Reminder] {
        store.values.filter {
            $0.entityId == entityId && $0.entityType == entityType && $0.status == .pending
        }
    }

    func findAll() -> [Reminder] { Array(store.values) }

    func save(_ reminder: Reminder) throws { store[reminder.id] = reminder }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
