import Foundation

/// design.md 3.12
struct CountBatch: Equatable {
    let id: UUID
    var siteId: String
    var taskId: UUID
    var createdAt: Date
}
