import Foundation

/// design.md 3.11
struct CountTask: Equatable {
    let id: UUID
    var siteId: String
    var assignedTo: UUID
    var status: CountTaskStatus
}
