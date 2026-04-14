import Foundation

/// design.md 3.18
struct AuditLog: Equatable {
    let id: UUID
    var actorId: UUID
    var action: String
    var entityId: UUID
    var timestamp: Date
    var tombstone: Bool
    var deletedAt: Date?
    var deletedBy: UUID?
}
