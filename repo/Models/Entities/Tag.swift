import Foundation

struct Tag: Equatable {
    let id: UUID
    var name: String // normalized, unique
}

struct TagAssignment: Equatable {
    var tagId: UUID
    var entityId: UUID
    var entityType: String
}
