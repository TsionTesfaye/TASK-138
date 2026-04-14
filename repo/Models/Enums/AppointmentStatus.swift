import Foundation

enum AppointmentStatus: String, CaseIterable, Codable {
    case scheduled = "scheduled"
    case confirmed = "confirmed"
    case completed = "completed"
    case canceled = "canceled"
    case noShow = "no_show"

    func canTransition(to target: AppointmentStatus) -> Bool {
        switch (self, target) {
        case (.scheduled, .confirmed):
            return true
        case (.scheduled, .canceled):
            return true
        case (.confirmed, .completed):
            return true
        case (.confirmed, .canceled):
            return true
        case (.confirmed, .noShow):
            return true
        case (.scheduled, .noShow):
            return true
        default:
            return false
        }
    }
}
