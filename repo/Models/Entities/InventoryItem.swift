import Foundation

/// design.md 3.10
struct InventoryItem: Equatable {
    let id: UUID
    var siteId: String
    var identifier: String
    var expectedQty: Int
    var location: String
    var custodian: String
}
