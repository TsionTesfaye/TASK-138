import Foundation

/// Tests for UserManagementService: create, role change, deactivate, admin-only.
final class UserManagementServiceTests {

    private func makeServices() -> (UserManagementService, InMemoryUserRepository, InMemoryAuditLogRepository) {
        let userRepo = InMemoryUserRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permService = PermissionService(permissionScopeRepo: InMemoryPermissionScopeRepository())
        let opLogRepo = InMemoryOperationLogRepository()
        let authService = AuthService(userRepo: userRepo, auditService: auditService, operationLogRepo: opLogRepo)
        let service = UserManagementService(
            userRepo: userRepo, permissionService: permService, authService: authService,
            auditService: auditService, operationLogRepo: opLogRepo
        )
        return (service, userRepo, auditLogRepo)
    }

    func runAll() {
        print("--- UserManagementServiceTests ---")
        testCreateUser()
        testCreateUserDuplicateUsername()
        testCreateUserNonAdminDenied()
        testUpdateRole()
        testDeactivateUser()
        testDeactivateSelfDenied()
        testResetLockout()
        testCreateUserAuditLogged()
    }

    func testCreateUser() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        let result = service.createUser(by: admin, username: "newuser", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.role == .salesAssociate)
        TestHelpers.assert(user.isActive)
        TestHelpers.assert(userRepo.findByUsername("newuser") != nil)
        print("  PASS: testCreateUser")
    }

    func testCreateUserDuplicateUsername() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        _ = service.createUser(by: admin, username: "dup", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        let result = service.createUser(by: admin, username: "dup", password: "AnotherPass123", role: .inventoryClerk, operationId: UUID())
        TestHelpers.assertFailure(result, code: "ENTITY_DUPLICATE")
        print("  PASS: testCreateUserDuplicateUsername")
    }

    func testCreateUserNonAdminDenied() {
        let (service, userRepo, _) = makeServices()
        let sales = TestHelpers.makeSalesAssociate()
        try! userRepo.save(sales)

        let result = service.createUser(by: sales, username: "new", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        TestHelpers.assertFailure(result, code: "PERM_ADMIN_REQ")
        print("  PASS: testCreateUserNonAdminDenied")
    }

    func testUpdateRole() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        let user = TestHelpers.assertSuccess(
            service.createUser(by: admin, username: "staff", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        )!
        let updated = TestHelpers.assertSuccess(
            service.updateRole(by: admin, userId: user.id, newRole: .inventoryClerk, operationId: UUID())
        )!
        TestHelpers.assert(updated.role == .inventoryClerk)
        print("  PASS: testUpdateRole")
    }

    func testDeactivateUser() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        let user = TestHelpers.assertSuccess(
            service.createUser(by: admin, username: "toDeactivate", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        )!
        let result = service.deactivateUser(by: admin, userId: user.id, operationId: UUID())
        _ = TestHelpers.assertSuccess(result)
        let deactivated = userRepo.findById(user.id)!
        TestHelpers.assert(!deactivated.isActive, "User should be inactive")
        print("  PASS: testDeactivateUser")
    }

    func testDeactivateSelfDenied() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        let result = service.deactivateUser(by: admin, userId: admin.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "SELF_DEACTIVATE")
        print("  PASS: testDeactivateSelfDenied")
    }

    func testResetLockout() {
        let (service, userRepo, _) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        var user = TestHelpers.assertSuccess(
            service.createUser(by: admin, username: "locked", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        )!
        user.failedAttempts = 5
        user.lockoutUntil = Date().addingTimeInterval(600)
        user.lastFailedAttempt = Date()
        try! userRepo.save(user)

        let result = service.resetLockout(by: admin, userId: user.id, operationId: UUID())
        _ = TestHelpers.assertSuccess(result)
        let reset = userRepo.findById(user.id)!
        TestHelpers.assert(reset.failedAttempts == 0)
        TestHelpers.assert(reset.lockoutUntil == nil)
        print("  PASS: testResetLockout")
    }

    func testCreateUserAuditLogged() {
        let (service, userRepo, auditLogRepo) = makeServices()
        let admin = TestHelpers.makeAdmin()
        try! userRepo.save(admin)

        _ = service.createUser(by: admin, username: "audited", password: "SecurePass123", role: .salesAssociate, operationId: UUID())
        let logs = auditLogRepo.findAll()
        TestHelpers.assert(logs.contains { $0.action == "user_created" }, "Should log user creation")
        print("  PASS: testCreateUserAuditLogged")
    }
}
