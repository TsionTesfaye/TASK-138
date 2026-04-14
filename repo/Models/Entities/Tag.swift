import Foundation

/// design.md 3.6
struct Tag: Equatable {
    let id: UUID
    var name: String // normalized, unique
}

/// design.md 3.6.1
struct TagAssignment: Equatable {
    var tagId: UUID
    var entityId: UUID
    var entityType: String
}
