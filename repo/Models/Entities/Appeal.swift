import Foundation

struct Appeal: Equatable {
    let id: UUID
    var siteId: String
    var exceptionId: UUID
    var status: AppealStatus
    var reviewerId: UUID?
    var submittedBy: UUID
    var reason: String
    var resolvedAt: Date?
}
