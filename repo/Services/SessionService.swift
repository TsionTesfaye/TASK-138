import Foundation

/// Manages active session and background re-authentication.
/// Session state stored in memory. Last authenticated user ID persisted via UserDefaults
/// for biometric re-authentication after app restart.
final class SessionService {

    /// In-memory session state
    private(set) var currentUser: User?
    private(set) var lastActiveTimestamp: Date?
    /// Recorded when the app enters background; re-auth triggered if background exceeds timeout.
    private(set) var backgroundEnteredAt: Date?
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

    /// Check if the session is still valid.
    /// Returns false if the app was in background for > 5 minutes, or no session exists.
    func isSessionValid() -> Bool {
        guard currentUser != nil else { return false }
        // Primary check: how long was the app in background?
        if let enteredBackground = backgroundEnteredAt {
            let backgroundDuration = now().timeIntervalSince(enteredBackground)
            return backgroundDuration <= backgroundTimeoutSeconds
        }
        // Fallback: idle time (applies before first background entry)
        guard let lastActive = lastActiveTimestamp else { return false }
        return now().timeIntervalSince(lastActive) <= backgroundTimeoutSeconds
    }

    /// Check if re-authentication is required.
    func requiresReAuthentication() -> Bool {
        return !isSessionValid()
    }

    func endSession() {
        currentUser = nil
        lastActiveTimestamp = nil
        backgroundEnteredAt = nil
    }

    /// Call when app returns to foreground. Clears background timestamp. Returns whether re-auth is needed.
    func onAppForeground() -> Bool {
        let needsReAuth = requiresReAuthentication()
        backgroundEnteredAt = nil
        return needsReAuth
    }

    /// Call when app enters background. Records the moment the app left foreground.
    func onAppBackground() {
        backgroundEnteredAt = now()
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
