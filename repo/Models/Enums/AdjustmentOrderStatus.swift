import Foundation

enum AdjustmentOrderStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case approved = "approved"
    case executed = "executed"
}
