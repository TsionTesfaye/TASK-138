import Foundation

struct PermissionScope: Equatable {
    let id: UUID
    var userId: UUID
    var site: String
    var functionKey: String
    var validFrom: Date
    var validTo: Date
}
