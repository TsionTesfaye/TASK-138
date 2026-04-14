import Foundation

/// design.md 4.17, questions.md Q5
/// Manages active session and background re-authentication.
/// Session state stored in memory. Last authenticated user ID persisted via UserDefaults
/// for biometric re-authentication after app restart.
final class SessionService {

    /// In-memory session state
    private(set) var currentUser: User?
    private(set) var lastActiveTimestamp: Date?
    private let backgroundTimeoutSeconds: TimeInterval = 5 * 60 // 5 minutes

    /// User repository for biometric re-auth lookup
    let userRepo: UserRepository?

    /// Time provider for testability
    var now: () -> Date = { Date() }

    private static let lastAuthenticatedUserIdKey = "com.dealerops.lastAuthenticatedUserId"

    init(userRepo: UserRepository? = nil) {
        self.userRepo = userRepo
    }

    // MARK: - Session Management

    func startSession(user: User) {
        currentUser = user
        lastActiveTimestamp = now()
        // Persist user ID for biometric re-auth after restart
        UserDefaults.standard.set(user.id.uuidString, forKey: SessionService.lastAuthenticatedUserIdKey)
    }

    func recordActivity() {
        lastActiveTimestamp = now()
    }

    /// Check if the session is still valid (not expired).
    /// Returns false if idle > 5 minutes or no session exists.
    func isSessionValid() -> Bool {
        guard currentUser != nil, let lastActive = lastActiveTimestamp else {
            return false
        }
        let elapsed = now().timeIntervalSince(lastActive)
        return elapsed <= backgroundTimeoutSeconds
    }

    /// Check if re-authentication is required.
    /// Returns true if session has expired (idle > 5 minutes).
    func requiresReAuthentication() -> Bool {
        return !isSessionValid()
    }

    func endSession() {
        currentUser = nil
        lastActiveTimestamp = nil
    }

    /// Call when app returns to foreground. Returns whether re-auth is needed.
    func onAppForeground() -> Bool {
        return requiresReAuthentication()
    }

    /// Call when app enters background. Records the timestamp.
    func onAppBackground() {
        // lastActiveTimestamp already set from last recordActivity
        // No additional action needed — the check happens on foreground
    }

    // MARK: - Biometric Re-authentication

    /// Retrieve the last authenticated user for biometric login.
    /// Returns the user only if biometricEnabled is true and the account is active.
    func biometricUser() -> User? {
        guard let userRepo = userRepo else { return nil }
        guard let idString = UserDefaults.standard.string(forKey: SessionService.lastAuthenticatedUserIdKey),
              let userId = UUID(uuidString: idString) else { return nil }
        guard let user = userRepo.findById(userId) else { return nil }
        guard user.isActive && user.biometricEnabled else { return nil }
        return user
    }

    /// Clear the persisted biometric user ID (e.g., on explicit logout).
    func clearBiometricUser() {
        UserDefaults.standard.removeObject(forKey: SessionService.lastAuthenticatedUserIdKey)
    }
}
