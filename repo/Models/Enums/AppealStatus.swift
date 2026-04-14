import Foundation

enum AppealStatus: String, CaseIterable, Codable {
    case submitted = "submitted"
    case underReview = "under_review"
    case approved = "approved"
    case denied = "denied"
    case archived = "archived"

    func canTransition(to target: AppealStatus) -> Bool {
        switch (self, target) {
        case (.submitted, .underReview):
            return true
        case (.underReview, .approved):
            return true
        case (.underReview, .denied):
            return true
        case (.approved, .archived):
            return true
        case (.denied, .archived):
            return true
        default:
            return false
        }
    }
}
