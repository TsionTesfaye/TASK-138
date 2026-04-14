import Foundation

enum PoolOrderStatus: String, CaseIterable, Codable {
    case draft = "draft"
    case active = "active"
    case matched = "matched"
    case completed = "completed"
    case canceled = "canceled"
    case expired = "expired"

    func canTransition(to target: PoolOrderStatus) -> Bool {
        switch (self, target) {
        case (.draft, .active):
            return true
        case (.active, .matched):
            return true
        case (.matched, .completed):
            return true
        case (.active, .canceled):
            return true
        case (_, .expired):
            // any → expired (background task)
            return true
        default:
            return false
        }
    }
}
