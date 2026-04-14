import Foundation

/// design.md 3.15.1
struct CheckIn: Equatable {
    let id: UUID
    var siteId: String
    var userId: UUID
    var timestamp: Date
    var locationLat: Double
    var locationLng: Double
}
