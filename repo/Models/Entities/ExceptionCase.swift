import Foundation

/// design.md 3.15
struct ExceptionCase: Equatable {
    let id: UUID
    var siteId: String
    var type: ExceptionType
    var sourceId: UUID
    var reason: String
    var status: ExceptionCaseStatus
    var createdAt: Date
}
