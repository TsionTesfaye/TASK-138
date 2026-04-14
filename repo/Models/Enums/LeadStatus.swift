import Foundation

enum LeadStatus: String, CaseIterable, Codable {
    case new = "new"
    case followUp = "follow_up"
    case closedWon = "closed_won"
    case invalid = "invalid"

    /// Returns whether a transition from self to the target status is valid.
    /// Admin-only transitions return true here; callers must separately enforce the admin check.
    func canTransition(to target: LeadStatus, isAdmin: Bool) -> Bool {
        switch (self, target) {
        case (.new, .followUp):
            return true
        case (.followUp, .closedWon):
            return true
        case (.followUp, .invalid):
            return true
        case (.invalid, .followUp):
            return isAdmin
        case (.closedWon, .followUp):
            return isAdmin
        default:
            return false
        }
    }

    func requiresAdminForTransition(to target: LeadStatus) -> Bool {
        switch (self, target) {
        case (.invalid, .followUp), (.closedWon, .followUp):
            return true
        default:
            return false
        }
    }
}
