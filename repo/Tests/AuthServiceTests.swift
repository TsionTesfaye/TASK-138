import Foundation

/// Tests for AuthService: bootstrap, login, lockout, biometric, password validation.
final class AuthServiceTests {

    private var userRepo: InMemoryUserRepository!
    private var auditLogRepo: InMemoryAuditLogRepository!
    private var operationLogRepo: InMemoryOperationLogRepository!
    private var auditService: AuditService!
    private var authService: AuthService!

    func setUp() {
        userRepo = InMemoryUserRepository()
        auditLogRepo = InMemoryAuditLogRepository()
        operationLogRepo = InMemoryOperationLogRepository()
        auditService = AuditService(auditLogRepo: auditLogRepo)
        authService = AuthService(userRepo: userRepo, auditService: auditService, operationLogRepo: operationLogRepo)
    }

    func runAll() {
        let tests: [(String, () -> Void)] = [
            ("testBootstrapCreatesAdmin", testBootstrapCreatesAdmin),
            ("testBootstrapOnlyOnce", testBootstrapOnlyOnce),
            ("testLoginSuccess", testLoginSuccess),
            ("testLoginInvalidPassword", testLoginInvalidPassword),
            ("testLoginInactiveAccount", testLoginInactiveAccount),
            ("testLockoutAfter5Failures", testLockoutAfter5Failures),
            ("testLockoutRollingWindow", testLockoutRollingWindow),
            ("testLockoutExpires", testLockoutExpires),
            ("testPasswordPolicyMinLength", testPasswordPolicyMinLength),
            ("testPasswordPolicyUppercase", testPasswordPolicyUppercase),
            ("testPasswordPolicyLowercase", testPasswordPolicyLowercase),
            ("testPasswordPolicyNumber", testPasswordPolicyNumber),
            ("testPasswordPolicyValid", testPasswordPolicyValid),
            ("testEnableBiometric", testEnableBiometric),
            ("testEnableBiometricRequiresPassword", testEnableBiometricRequiresPassword),
            ("testDisableBiometricRequiresPassword", testDisableBiometricRequiresPassword),
            ("testBootstrapAuditLogged", testBootstrapAuditLogged),
            ("testLoginFailureAuditLogged", testLoginFailureAuditLogged),
        ]

        print("--- AuthServiceTests ---")
        for (name, test) in tests {
            setUp()
            test()
            print("  PASS: \(name)")
        }
    }

    // MARK: - Bootstrap

    func testBootstrapCreatesAdmin() {
        let result = authService.bootstrap(username: "admin", password: "SecurePass123")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.role == .administrator, "Should be admin")
        TestHelpers.assert(user.isActive, "Should be active")
        TestHelpers.assert(userRepo.count() == 1, "Should have 1 user")
    }

    func testBootstrapOnlyOnce() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let result = authService.bootstrap(username: "admin2", password: "AnotherPass123")
        TestHelpers.assertFailure(result, code: "AUTH_BOOTSTRAP_DONE")
    }

    // MARK: - Login

    func testLoginSuccess() {
        let bootstrapResult = authService.bootstrap(username: "admin", password: "SecurePass123")
        _ = TestHelpers.assertSuccess(bootstrapResult)
        let result = authService.login(username: "admin", password: "SecurePass123")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.username == "admin")
    }

    func testLoginInvalidPassword() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let result = authService.login(username: "admin", password: "WrongPassword1")
        TestHelpers.assertFailure(result, code: "AUTH_INVALID")
    }

    func testLoginInactiveAccount() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        var user = userRepo.findByUsername("admin")!
        user.isActive = false
        try! userRepo.save(user)
        let result = authService.login(username: "admin", password: "SecurePass123")
        TestHelpers.assertFailure(result, code: "AUTH_INACTIVE")
    }

    // MARK: - Lockout

    func testLockoutAfter5Failures() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let now = Date()
        for _ in 0..<5 {
            _ = authService.login(username: "admin", password: "Wrong12345abc", now: now)
        }
        let user = userRepo.findByUsername("admin")!
        TestHelpers.assert(user.lockoutUntil != nil, "Should be locked out")
        let result = authService.login(username: "admin", password: "SecurePass123", now: now)
        TestHelpers.assertFailure(result, code: "AUTH_LOCKED")
    }

    func testLockoutRollingWindow() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let baseTime = Date()
        // 3 failures now
        for _ in 0..<3 {
            _ = authService.login(username: "admin", password: "Wrong12345abc", now: baseTime)
        }
        // 11 minutes later (outside window), 2 more failures
        let laterTime = baseTime.addingTimeInterval(11 * 60)
        for _ in 0..<2 {
            _ = authService.login(username: "admin", password: "Wrong12345abc", now: laterTime)
        }
        let user = userRepo.findByUsername("admin")!
        // Should NOT be locked — window reset means only 2 attempts
        TestHelpers.assert(user.lockoutUntil == nil, "Should not be locked (window reset)")
    }

    func testLockoutExpires() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let now = Date()
        for _ in 0..<5 {
            _ = authService.login(username: "admin", password: "Wrong12345abc", now: now)
        }
        // 11 minutes later, lockout should have expired
        let laterTime = now.addingTimeInterval(11 * 60)
        let result = authService.login(username: "admin", password: "SecurePass123", now: laterTime)
        _ = TestHelpers.assertSuccess(result)
    }

    // MARK: - Password Policy

    func testPasswordPolicyMinLength() {
        let err = authService.validatePasswordPolicy("Short1aB")
        TestHelpers.assert(err?.code == "PASS_SHORT")
    }

    func testPasswordPolicyUppercase() {
        let err = authService.validatePasswordPolicy("alllowercase1234")
        TestHelpers.assert(err?.code == "PASS_NO_UPPER")
    }

    func testPasswordPolicyLowercase() {
        let err = authService.validatePasswordPolicy("ALLUPPERCASE1234")
        TestHelpers.assert(err?.code == "PASS_NO_LOWER")
    }

    func testPasswordPolicyNumber() {
        let err = authService.validatePasswordPolicy("NoNumbersHere!!")
        TestHelpers.assert(err?.code == "PASS_NO_NUMBER")
    }

    func testPasswordPolicyValid() {
        let err = authService.validatePasswordPolicy("ValidPass1234")
        TestHelpers.assert(err == nil, "Should be valid")
    }

    // MARK: - Biometric

    func testEnableBiometric() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let user = userRepo.findByUsername("admin")!
        let result = authService.enableBiometric(userId: user.id, password: "SecurePass123")
        _ = TestHelpers.assertSuccess(result)
        let updated = userRepo.findById(user.id)!
        TestHelpers.assert(updated.biometricEnabled, "Biometric should be enabled")
    }

    func testEnableBiometricRequiresPassword() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let user = userRepo.findByUsername("admin")!
        let result = authService.enableBiometric(userId: user.id, password: "WrongPass12345")
        TestHelpers.assertFailure(result, code: "AUTH_PASS_REQUIRED")
    }

    func testDisableBiometricRequiresPassword() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let user = userRepo.findByUsername("admin")!
        _ = authService.enableBiometric(userId: user.id, password: "SecurePass123")
        let result = authService.disableBiometric(userId: user.id, password: "WrongPass12345")
        TestHelpers.assertFailure(result, code: "AUTH_PASS_REQUIRED")
    }

    // MARK: - Audit

    func testBootstrapAuditLogged() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        let logs = auditLogRepo.findAll()
        TestHelpers.assert(logs.contains { $0.action == "bootstrap_admin_created" }, "Bootstrap should be logged")
    }

    func testLoginFailureAuditLogged() {
        _ = authService.bootstrap(username: "admin", password: "SecurePass123")
        _ = authService.login(username: "admin", password: "WrongPass12345")
        let logs = auditLogRepo.findAll()
        TestHelpers.assert(logs.contains { $0.action == "login_failed" }, "Login failure should be logged")
    }
}
