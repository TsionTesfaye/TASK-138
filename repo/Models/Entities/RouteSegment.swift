import Foundation

/// design.md 3.9
struct RouteSegment: Equatable {
    let id: UUID
    var poolOrderId: UUID
    var sequence: Int
    var locationLat: Double
    var locationLng: Double
}
