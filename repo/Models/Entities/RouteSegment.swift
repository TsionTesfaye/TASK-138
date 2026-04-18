import Foundation

struct RouteSegment: Equatable {
    let id: UUID
    let matchId: UUID
    let originLat: Double
    let originLng: Double
    let destinationLat: Double
    let destinationLng: Double
    let distanceMiles: Double
    let estimatedDurationMinutes: Double
    let createdAt: Date
}
