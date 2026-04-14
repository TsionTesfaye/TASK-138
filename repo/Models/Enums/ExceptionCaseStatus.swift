import Foundation

enum ExceptionCaseStatus: String, CaseIterable, Codable {
    case open = "open"
    case underAppeal = "under_appeal"
    case resolved = "resolved"
    case dismissed = "dismissed"
}
