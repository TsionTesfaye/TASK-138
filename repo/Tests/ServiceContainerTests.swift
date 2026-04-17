import Foundation

/// Tests for ServiceContainer.resolvedSite(for:) — admin site-resolution fallback behavior.
final class ServiceContainerTests {

    func runAll() {
        print("--- ServiceContainerTests ---")
        testResolvedSiteUsesUserScope()
        testAdminWithNoScopesGetsSystemFallback()
        testAdminWithNoScopesAndNoSystemScopesGetsMain()
        testExpiredScopeIsIgnored()
    }

    func testResolvedSiteUsesUserScope() {
        let container = ServiceContainer(inMemory: true)
        let user = TestHelpers.makeSalesAssociate()
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: "lot-b", functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(scope)

        let site = container.resolvedSite(for: user)
        TestHelpers.assert(site == "lot-b", "Should return the user's own scope site")
        print("  PASS: testResolvedSiteUsesUserScope")
    }

    func testAdminWithNoScopesGetsSystemFallback() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        // Seed a scope for another user so there's an active site in the system
        let otherUser = TestHelpers.makeSalesAssociate()
        let scope = PermissionScope(
            id: UUID(), userId: otherUser.id, site: "lot-a", functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(scope)

        let site = container.resolvedSite(for: admin)
        TestHelpers.assert(!site.isEmpty, "Admin should get a non-empty site")
        TestHelpers.assert(site == "lot-a", "Admin should fall back to the system's first valid site")
        print("  PASS: testAdminWithNoScopesGetsSystemFallback")
    }

    func testAdminWithNoScopesAndNoSystemScopesGetsMain() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        // No scopes at all in the system

        let site = container.resolvedSite(for: admin)
        TestHelpers.assert(site == "main", "Should fall back to 'main' when no scopes exist")
        print("  PASS: testAdminWithNoScopesAndNoSystemScopesGetsMain")
    }

    func testExpiredScopeIsIgnored() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        // Only an expired scope exists
        let scope = PermissionScope(
            id: UUID(), userId: UUID(), site: "old-lot", functionKey: "leads",
            validFrom: Date().addingTimeInterval(-7200), validTo: Date().addingTimeInterval(-3600)
        )
        try! container.permissionScopeRepo.save(scope)

        let site = container.resolvedSite(for: admin)
        TestHelpers.assert(site == "main", "Expired scopes must be ignored; fallback to 'main'")
        print("  PASS: testExpiredScopeIsIgnored")
    }
}
