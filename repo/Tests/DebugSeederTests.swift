import Foundation

/// Tests for DebugSeeder. Each test builds its own fresh InMemory repositories —
/// completely isolated from every other test suite. No shared state is touched.
///
/// Design constraints verified here (from the tester-onboarding guide):
///   1. Seeding is idempotent — running twice produces no duplicates.
///   2. Seeder never wipes existing data.
///   3. After seeding, userRepo.count() > 0, so BootstrapViewController is unreachable
///      and AppDelegate routes straight to LoginViewController.
///   4. Each seeded account can log in with its documented credentials immediately.
///   5. Non-admin accounts receive permission scopes for the demo site.
///   6. Admin bypasses scope checks; no scope needed for admin role.
final class DebugSeederTests {

    private func makeComponents() -> (DebugSeeder, AuthService, InMemoryUserRepository, InMemoryPermissionScopeRepository) {
        let userRepo = InMemoryUserRepository()
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let auditRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditRepo)
        let opLogRepo = InMemoryOperationLogRepository()
        let authService = AuthService(userRepo: userRepo, auditService: auditService, operationLogRepo: opLogRepo)
        let seeder = DebugSeeder(userRepo: userRepo, permissionScopeRepo: permScopeRepo, authService: authService)
        return (seeder, authService, userRepo, permScopeRepo)
    }

    func runAll() {
        print("--- DebugSeederTests ---")
        testSeedsAllFourAccounts()
        testAdminCanLogin()
        testSalesAssociateCanLogin()
        testInventoryClerkCanLogin()
        testComplianceReviewerCanLogin()
        testCorrectRolesAssigned()
        testSeedingIsIdempotent()
        testSeedReturnsZeroWhenAlreadySeeded()
        testBootstrapBlockedAfterSeeding()
        testSeedDoesNotOverwriteExistingUser()
        testNonAdminScopesSeeded()
        testAdminHasNoScopeNeeded()
    }

    func testSeedsAllFourAccounts() {
        let (seeder, _, userRepo, _) = makeComponents()
        seeder.seed()
        TestHelpers.assert(userRepo.count() == 4, "Expected 4 seeded accounts")
        print("  PASS: testSeedsAllFourAccounts")
    }

    func testAdminCanLogin() {
        let (seeder, authService, _, _) = makeComponents()
        seeder.seed()
        let result = authService.login(username: "admin", password: "Admin12345678")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.username == "admin")
        TestHelpers.assert(user.role == .administrator)
        print("  PASS: testAdminCanLogin")
    }

    func testSalesAssociateCanLogin() {
        let (seeder, authService, _, _) = makeComponents()
        seeder.seed()
        let result = authService.login(username: "sales1", password: "Sales12345678")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.role == .salesAssociate)
        print("  PASS: testSalesAssociateCanLogin")
    }

    func testInventoryClerkCanLogin() {
        let (seeder, authService, _, _) = makeComponents()
        seeder.seed()
        let result = authService.login(username: "clerk1", password: "Clerk12345678")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.role == .inventoryClerk)
        print("  PASS: testInventoryClerkCanLogin")
    }

    func testComplianceReviewerCanLogin() {
        let (seeder, authService, _, _) = makeComponents()
        seeder.seed()
        let result = authService.login(username: "reviewer1", password: "Reviewer12345")
        let user = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(user.role == .complianceReviewer)
        print("  PASS: testComplianceReviewerCanLogin")
    }

    func testCorrectRolesAssigned() {
        let (seeder, _, userRepo, _) = makeComponents()
        seeder.seed()
        let roles: [String: UserRole] = [
            "admin": .administrator,
            "sales1": .salesAssociate,
            "clerk1": .inventoryClerk,
            "reviewer1": .complianceReviewer,
        ]
        for (username, expectedRole) in roles {
            let user = userRepo.findByUsername(username)
            TestHelpers.assert(user != nil, "User \(username) must exist")
            TestHelpers.assert(user!.role == expectedRole, "\(username) role mismatch")
        }
        print("  PASS: testCorrectRolesAssigned")
    }

    func testSeedingIsIdempotent() {
        let (seeder, _, userRepo, permScopeRepo) = makeComponents()
        seeder.seed()
        let countAfterFirst = userRepo.count()

        seeder.seed() // second run — must not duplicate
        TestHelpers.assert(userRepo.count() == countAfterFirst, "Duplicate users created on second seed")

        // Confirm scopes are also not duplicated (by checking sales1's scope count)
        if let sales = userRepo.findByUsername("sales1") {
            let scopes = permScopeRepo.findByUserId(sales.id)
            TestHelpers.assert(scopes.count == 3, "sales1 should have exactly 3 scopes (leads + carpool + checkin), got \(scopes.count)")
        }
        print("  PASS: testSeedingIsIdempotent")
    }

    func testSeedReturnsZeroWhenAlreadySeeded() {
        let (seeder, _, _, _) = makeComponents()
        seeder.seed()
        let secondCount = seeder.seed()
        TestHelpers.assert(secondCount == 0, "Second seed must return 0 (nothing created)")
        print("  PASS: testSeedReturnsZeroWhenAlreadySeeded")
    }

    func testBootstrapBlockedAfterSeeding() {
        let (seeder, authService, _, _) = makeComponents()
        seeder.seed()
        // After seeding, count > 0 → bootstrap must refuse
        let result = authService.bootstrap(username: "newadmin", password: "NewAdmin12345")
        TestHelpers.assertFailure(result, code: "AUTH_BOOTSTRAP_DONE")
        print("  PASS: testBootstrapBlockedAfterSeeding")
    }

    func testSeedDoesNotOverwriteExistingUser() {
        let (seeder, _, userRepo, _) = makeComponents()
        // Pre-create an 'admin' user with a known id
        let existingId = UUID()
        let existingAdmin = User(
            id: existingId, username: "admin", passwordHash: "original-hash",
            passwordSalt: "original-salt", role: .administrator, biometricEnabled: false,
            failedAttempts: 0, lastFailedAttempt: nil, lockoutUntil: nil,
            createdAt: Date(), isActive: true
        )
        try! userRepo.save(existingAdmin)

        seeder.seed()

        // The existing admin must be unchanged (seeder skipped it)
        let found = userRepo.findByUsername("admin")!
        TestHelpers.assert(found.id == existingId, "Seeder must not overwrite an existing user")
        TestHelpers.assert(found.passwordHash == "original-hash")
        // Other accounts should still be created
        TestHelpers.assert(userRepo.count() == 4)
        print("  PASS: testSeedDoesNotOverwriteExistingUser")
    }

    func testNonAdminScopesSeeded() {
        let (seeder, _, userRepo, permScopeRepo) = makeComponents()
        seeder.seed()

        // sales1 → leads + carpool + checkin
        let sales = userRepo.findByUsername("sales1")!
        let salesScopes = permScopeRepo.findByUserId(sales.id)
        let salesKeys = Set(salesScopes.map { $0.functionKey })
        TestHelpers.assert(salesKeys.contains("leads"), "sales1 missing leads scope")
        TestHelpers.assert(salesKeys.contains("carpool"), "sales1 missing carpool scope")
        TestHelpers.assert(salesKeys.contains("checkin"), "sales1 missing checkin scope")
        TestHelpers.assert(salesScopes.allSatisfy { $0.site == DebugSeeder.demoSite }, "Scopes must target demoSite")

        // clerk1 → inventory + checkin
        let clerk = userRepo.findByUsername("clerk1")!
        let clerkKeys = Set(permScopeRepo.findByUserId(clerk.id).map { $0.functionKey })
        TestHelpers.assert(clerkKeys.contains("inventory"), "clerk1 missing inventory scope")
        TestHelpers.assert(clerkKeys.contains("checkin"), "clerk1 missing checkin scope")

        // reviewer1 → exceptions + appeals + checkin
        let reviewer = userRepo.findByUsername("reviewer1")!
        let reviewerKeys = Set(permScopeRepo.findByUserId(reviewer.id).map { $0.functionKey })
        TestHelpers.assert(reviewerKeys.contains("exceptions"), "reviewer1 missing exceptions scope")
        TestHelpers.assert(reviewerKeys.contains("appeals"), "reviewer1 missing appeals scope")
        TestHelpers.assert(reviewerKeys.contains("checkin"), "reviewer1 missing checkin scope")

        print("  PASS: testNonAdminScopesSeeded")
    }

    func testAdminHasNoScopeNeeded() {
        let (seeder, _, userRepo, permScopeRepo) = makeComponents()
        seeder.seed()

        // Admin has no scopes seeded (not needed — PermissionService.validateScope bypasses admins)
        let admin = userRepo.findByUsername("admin")!
        let adminScopes = permScopeRepo.findByUserId(admin.id)
        TestHelpers.assert(adminScopes.isEmpty, "admin should have no scopes (uses role bypass)")

        // Verify admin bypass works via PermissionService directly
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let result = permService.validateScope(user: admin, site: DebugSeeder.demoSite, functionKey: "leads")
        TestHelpers.assertSuccess(result)
        print("  PASS: testAdminHasNoScopeNeeded")
    }
}
