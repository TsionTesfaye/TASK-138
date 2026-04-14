import Foundation

/// Tests for PermissionService: matrix enforcement, scope validation, default deny.
final class PermissionServiceTests {

    func runAll() {
        print("--- PermissionServiceTests ---")
        testAdminHasFullAccess()
        testSalesAssociateLeadsCRUD()
        testSalesAssociateInventoryDenied()
        testSalesAssociateCarpoolViewOnly()
        testSalesAssociateAppealsCreate()
        testInventoryClerkInventoryCRUD()
        testInventoryClerkLeadsDenied()
        testComplianceReviewerAppealsReview()
        testComplianceReviewerLeadsReadOnly()
        testInactiveUserDenied()
        testScopeValidation()
        testScopeDefaultDeny()
        testAdminBypassesScope()
        testScopeExpiredDenied()
    }

    func testAdminHasFullAccess() {
        let service = makeService()
        let admin = TestHelpers.makeAdmin()
        for module in PermissionModule.allCases {
            for action in ["create", "read", "update", "delete", "approve", "deny", "review"] {
                let result = service.validateAccess(user: admin, action: action, module: module)
                TestHelpers.assertSuccess(result)
            }
        }
        print("  PASS: testAdminHasFullAccess")
    }

    func testSalesAssociateLeadsCRUD() {
        let service = makeService()
        let user = TestHelpers.makeSalesAssociate()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "create", module: .leads))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "read", module: .leads))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "update", module: .leads))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "delete", module: .leads))
        print("  PASS: testSalesAssociateLeadsCRUD")
    }

    func testSalesAssociateInventoryDenied() {
        let service = makeService()
        let user = TestHelpers.makeSalesAssociate()
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "create", module: .inventory), code: "PERM_DENIED")
        print("  PASS: testSalesAssociateInventoryDenied")
    }

    func testSalesAssociateCarpoolViewOnly() {
        let service = makeService()
        let user = TestHelpers.makeSalesAssociate()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "read", module: .carpool))
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "create", module: .carpool), code: "PERM_DENIED")
        print("  PASS: testSalesAssociateCarpoolViewOnly")
    }

    func testSalesAssociateAppealsCreate() {
        let service = makeService()
        let user = TestHelpers.makeSalesAssociate()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "create", module: .appeals))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "read", module: .appeals))
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "approve", module: .appeals), code: "PERM_DENIED")
        print("  PASS: testSalesAssociateAppealsCreate")
    }

    func testInventoryClerkInventoryCRUD() {
        let service = makeService()
        let user = TestHelpers.makeInventoryClerk()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "create", module: .inventory))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "read", module: .inventory))
        print("  PASS: testInventoryClerkInventoryCRUD")
    }

    func testInventoryClerkLeadsDenied() {
        let service = makeService()
        let user = TestHelpers.makeInventoryClerk()
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "create", module: .leads), code: "PERM_DENIED")
        print("  PASS: testInventoryClerkLeadsDenied")
    }

    func testComplianceReviewerAppealsReview() {
        let service = makeService()
        let user = TestHelpers.makeComplianceReviewer()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "review", module: .appeals))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "approve", module: .appeals))
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "deny", module: .appeals))
        print("  PASS: testComplianceReviewerAppealsReview")
    }

    func testComplianceReviewerLeadsReadOnly() {
        let service = makeService()
        let user = TestHelpers.makeComplianceReviewer()
        TestHelpers.assertSuccess(service.validateAccess(user: user, action: "read", module: .leads))
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "create", module: .leads), code: "PERM_DENIED")
        print("  PASS: testComplianceReviewerLeadsReadOnly")
    }

    func testInactiveUserDenied() {
        let service = makeService()
        let user = TestHelpers.makeInactiveUser()
        TestHelpers.assertFailure(service.validateAccess(user: user, action: "read", module: .leads), code: "AUTH_INACTIVE")
        print("  PASS: testInactiveUserDenied")
    }

    func testScopeValidation() {
        let scopeRepo = InMemoryPermissionScopeRepository()
        let service = PermissionService(permissionScopeRepo: scopeRepo)
        let user = TestHelpers.makeSalesAssociate()
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: "lot-a",
            functionKey: "leads", validFrom: Date().addingTimeInterval(-3600),
            validTo: Date().addingTimeInterval(3600)
        )
        try! scopeRepo.save(scope)
        TestHelpers.assertSuccess(service.validateScope(user: user, site: "lot-a", functionKey: "leads"))
        print("  PASS: testScopeValidation")
    }

    func testScopeDefaultDeny() {
        let service = makeService()
        let user = TestHelpers.makeSalesAssociate()
        // No scopes exist → denied
        TestHelpers.assertFailure(service.validateScope(user: user, site: "lot-a", functionKey: "leads"), code: "SCOPE_DENIED")
        print("  PASS: testScopeDefaultDeny")
    }

    func testAdminBypassesScope() {
        let service = makeService()
        let admin = TestHelpers.makeAdmin()
        // Admin should bypass scope even with no scopes defined
        TestHelpers.assertSuccess(service.validateScope(user: admin, site: "any-site", functionKey: "anything"))
        print("  PASS: testAdminBypassesScope")
    }

    func testScopeExpiredDenied() {
        let scopeRepo = InMemoryPermissionScopeRepository()
        let service = PermissionService(permissionScopeRepo: scopeRepo)
        let user = TestHelpers.makeSalesAssociate()
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: "lot-a",
            functionKey: "leads",
            validFrom: Date().addingTimeInterval(-7200),
            validTo: Date().addingTimeInterval(-3600) // expired 1 hour ago
        )
        try! scopeRepo.save(scope)
        TestHelpers.assertFailure(service.validateScope(user: user, site: "lot-a", functionKey: "leads"), code: "SCOPE_DENIED")
        print("  PASS: testScopeExpiredDenied")
    }

    private func makeService() -> PermissionService {
        PermissionService(permissionScopeRepo: InMemoryPermissionScopeRepository())
    }
}
