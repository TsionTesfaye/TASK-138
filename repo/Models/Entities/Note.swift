import Foundation

/// design.md 3.5
struct Note: Equatable {
    let id: UUID
    var entityId: UUID
    var entityType: String
    var content: String
    var createdAt: Date
    var createdBy: UUID
}
