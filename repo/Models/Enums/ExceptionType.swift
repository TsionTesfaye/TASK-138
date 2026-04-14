import Foundation

enum ExceptionType: String, CaseIterable, Codable {
    case missedCheckIn = "missed_check_in"
    case buddyPunching = "buddy_punching"
    case misidentification = "misidentification"
}
