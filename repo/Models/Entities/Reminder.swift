import Foundation

/// design.md 3.7
struct Reminder: Equatable {
    let id: UUID
    var entityId: UUID
    var entityType: String
    var createdBy: UUID
    var dueAt: Date
    var status: ReminderStatus
}
