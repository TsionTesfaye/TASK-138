import Foundation

enum CountTaskStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case canceled = "canceled"
}
