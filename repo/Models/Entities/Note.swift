import Foundation

struct Note: Equatable {
    let id: UUID
    var siteId: String
    var entityId: UUID
    var entityType: String
    var content: String
    var createdAt: Date
    var createdBy: UUID
}
