import Foundation

/// design.md 3.12.1
struct CountEntry: Equatable {
    let id: UUID
    var siteId: String
    var batchId: UUID
    var itemId: UUID
    var countedQty: Int
    var countedLocation: String
    var countedCustodian: String
}
