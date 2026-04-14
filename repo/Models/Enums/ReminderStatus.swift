import Foundation

enum ReminderStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case completed = "completed"
    case canceled = "canceled"
}
