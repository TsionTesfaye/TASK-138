import Foundation

struct InventoryItem: Equatable {
    let id: UUID
    var siteId: String
    var identifier: String
    var expectedQty: Int
    var location: String
    var custodian: String
}
