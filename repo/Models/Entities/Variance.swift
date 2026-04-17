import Foundation

struct Variance: Equatable {
    let id: UUID
    var siteId: String
    var itemId: UUID
    var expectedQty: Int
    var countedQty: Int
    var type: VarianceType
    var requiresApproval: Bool
    var approved: Bool
}
