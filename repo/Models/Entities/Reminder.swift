import Foundation

struct Reminder: Equatable {
    let id: UUID
    var siteId: String
    var entityId: UUID
    var entityType: String
    var createdBy: UUID
    var dueAt: Date
    var status: ReminderStatus
}
