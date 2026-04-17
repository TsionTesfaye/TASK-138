import Foundation

struct CountTask: Equatable {
    let id: UUID
    var siteId: String
    var assignedTo: UUID
    var status: CountTaskStatus
}
