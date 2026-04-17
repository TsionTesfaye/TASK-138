import Foundation

struct CheckIn: Equatable {
    let id: UUID
    var siteId: String
    var userId: UUID
    var timestamp: Date
    var locationLat: Double
    var locationLng: Double
}
