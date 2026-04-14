import Foundation

/// design.md 3.1
struct User: Equatable {
    let id: UUID
    var username: String
    var passwordHash: String
    var passwordSalt: String
    var role: UserRole
    var biometricEnabled: Bool
    var failedAttempts: Int
    var lastFailedAttempt: Date?
    var lockoutUntil: Date?
    var createdAt: Date
    var isActive: Bool
}
