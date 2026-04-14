import Foundation

/// Persists match results between pool orders (design.md 4.5: "persist matches")
struct CarpoolMatch: Equatable {
    let id: UUID
    var requestOrderId: UUID
    var offerOrderId: UUID
    var matchScore: Double
    var detourMiles: Double
    var timeOverlapMinutes: Double
    var accepted: Bool
    var createdAt: Date
}
