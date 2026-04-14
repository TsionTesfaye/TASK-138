import Foundation

/// design.md 3.8
struct PoolOrder: Equatable {
    let id: UUID
    var siteId: String
    var originLat: Double
    var originLng: Double
    var destinationLat: Double
    var destinationLng: Double
    var startTime: Date
    var endTime: Date
    var seatsAvailable: Int
    var vehicleType: String
    var createdBy: UUID
    var status: PoolOrderStatus
}
