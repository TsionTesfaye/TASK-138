import Foundation
import CommonCrypto

/// design.md 4.1, questions.md 1-5
/// Handles bootstrap, login, password validation, lockout, biometric enablement.
final class AuthService {

    private let userRepo: UserRepository
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(userRepo: UserRepository, auditService: AuditService, operationLogRepo: OperationLogRepository) {
        self.userRepo = userRepo
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Bootstrap (questions.md Q1)

    /// Create the first Administrator account. Only works when no users exist.
    /// After creation, bootstrap is permanently disabled (User.count > 0).
    func bootstrap(username: String, password: String) -> ServiceResult<User> {
        guard userRepo.count() == 0 else {
            return .failure(.bootstrapAlreadyComplete)
        }

        // Validate password
        if let error = validatePasswordPolicy(password) {
            return .failure(error)
        }

        let salt = generateSalt()
        let hash = hashPassword(password, salt: salt)

        let user = User(
            id: UUID(),
            username: username,
            passwordHash: hash,
            passwordSalt: salt,
            role: .administrator,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )

        do {
            try userRepo.save(user)
            auditService.log(actorId: user.id, action: "bootstrap_admin_created", entityId: user.id)
            return .success(user)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Login (questions.md Q3)

    /// Authenticate with username + password. Enforces lockout.
    func login(username: String, password: String, now: Date = Date()) -> ServiceResult<User> {
        guard var user = userRepo.findByUsername(username) else {
            return .failure(.invalidCredentials)
        }

        guard user.isActive else {
            auditService.log(actorId: user.id, action: "login_failed_inactive", entityId: user.id)
            return .failure(.accountInactive)
        }

        // Check lockout
        if let lockoutUntil = user.lockoutUntil, now < lockoutUntil {
            auditService.log(actorId: user.id, action: "login_failed_locked", entityId: user.id)
            return .failure(.accountLocked(until: lockoutUntil))
        }

        // If lockout expired, reset
        if let lockoutUntil = user.lockoutUntil, now >= lockoutUntil {
            user.lockoutUntil = nil
            user.failedAttempts = 0
            user.lastFailedAttempt = nil
        }

        // Reset failed attempts if outside the 10-minute rolling window
        if let lastFailed = user.lastFailedAttempt {
            let windowEnd = lastFailed.addingTimeInterval(10 * 60)
            if now > windowEnd {
                user.failedAttempts = 0
                user.lastFailedAttempt = nil
            }
        }

        let hash = hashPassword(password, salt: user.passwordSalt)
        guard hash == user.passwordHash else {
            // Failed login
            user.failedAttempts += 1
            user.lastFailedAttempt = now

            if user.failedAttempts >= 5 {
                user.lockoutUntil = now.addingTimeInterval(10 * 60) // 10 min lock
                auditService.log(actorId: user.id, action: "account_locked", entityId: user.id)
            }

            do { try userRepo.save(user) } catch { ServiceLogger.persistenceError(ServiceLogger.auth, operation: "save_failed_login", error: error) }
            auditService.log(actorId: user.id, action: "login_failed", entityId: user.id)
            return .failure(.invalidCredentials)
        }

        // Successful login — reset counters
        user.failedAttempts = 0
        user.lastFailedAttempt = nil
        user.lockoutUntil = nil
        do { try userRepo.save(user) } catch { ServiceLogger.persistenceError(ServiceLogger.auth, operation: "save_login_success", error: error) }
        auditService.log(actorId: user.id, action: "login_success", entityId: user.id)
        return .success(user)
    }

    // MARK: - Biometric (questions.md Q4)

    /// Enable biometric authentication. Requires password re-entry.
    func enableBiometric(userId: UUID, password: String) -> ServiceResult<Void> {
        guard var user = userRepo.findById(userId) else {
            return .failure(.entityNotFound)
        }
        let hash = hashPassword(password, salt: user.passwordSalt)
        guard hash == user.passwordHash else {
            return .failure(.passwordReEntryRequired)
        }
        user.biometricEnabled = true
        do {
            try userRepo.save(user)
            auditService.log(actorId: userId, action: "biometric_enabled", entityId: userId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    /// Disable biometric authentication. Requires password re-entry.
    func disableBiometric(userId: UUID, password: String) -> ServiceResult<Void> {
        guard var user = userRepo.findById(userId) else {
            return .failure(.entityNotFound)
        }
        let hash = hashPassword(password, salt: user.passwordSalt)
        guard hash == user.passwordHash else {
            return .failure(.passwordReEntryRequired)
        }
        user.biometricEnabled = false
        do {
            try userRepo.save(user)
            auditService.log(actorId: userId, action: "biometric_disabled", entityId: userId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Password Policy (questions.md Q2)

    /// Validate password against policy. Returns nil if valid, ServiceError if invalid.
    /// Rules: min 12 chars, 1 uppercase, 1 lowercase, 1 number
    func validatePasswordPolicy(_ password: String) -> ServiceError? {
        if password.count < 12 {
            return .passwordTooShort
        }
        if password.rangeOfCharacter(from: .uppercaseLetters) == nil {
            return .passwordMissingUppercase
        }
        if password.rangeOfCharacter(from: .lowercaseLetters) == nil {
            return .passwordMissingLowercase
        }
        if password.rangeOfCharacter(from: .decimalDigits) == nil {
            return .passwordMissingNumber
        }
        return nil
    }

    // MARK: - Hashing (PBKDF2-HMAC-SHA256)

    /// PBKDF2 iteration count. 100,000 minimum per NIST SP 800-132.
    static let pbkdf2Iterations: UInt32 = 100_000
    static let derivedKeyLength = 32 // 256 bits

    func generateSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes).base64EncodedString()
    }

    func hashPassword(_ password: String, salt: String) -> String {
        guard let passwordData = password.data(using: .utf8),
              let saltData = Data(base64Encoded: salt) else { return "" }

        var derivedKey = [UInt8](repeating: 0, count: AuthService.derivedKeyLength)

        let status = passwordData.withUnsafeBytes { passwordPtr in
            saltData.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                    passwordData.count,
                    saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    saltData.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    AuthService.pbkdf2Iterations,
                    &derivedKey,
                    AuthService.derivedKeyLength
                )
            }
        }

        guard status == kCCSuccess else { return "" }
        return Data(derivedKey).base64EncodedString()
    }
}
