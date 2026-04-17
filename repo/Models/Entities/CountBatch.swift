import Foundation

struct CountBatch: Equatable {
    let id: UUID
    var siteId: String
    var taskId: UUID
    var createdAt: Date
}
