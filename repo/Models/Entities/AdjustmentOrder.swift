import Foundation

/// design.md 3.14
struct AdjustmentOrder: Equatable {
    let id: UUID
    var siteId: String
    var varianceId: UUID
    var approvedBy: UUID?
    var createdAt: Date
    var status: AdjustmentOrderStatus
}
