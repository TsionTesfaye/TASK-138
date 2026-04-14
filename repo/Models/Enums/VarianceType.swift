import Foundation

enum VarianceType: String, CaseIterable, Codable {
    case surplus = "surplus"
    case shortage = "shortage"
    case locationMismatch = "location_mismatch"
    case custodianMismatch = "custodian_mismatch"
}
