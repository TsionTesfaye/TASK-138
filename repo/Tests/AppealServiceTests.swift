import Foundation

/// Tests for AppealService: workflow, exception status update, audit trail.
final class AppealServiceTests {

    private let testSite = "lot-a"

    private func makeServices() -> (AppealService, InMemoryAppealRepository, InMemoryExceptionCaseRepository, InMemoryAuditLogRepository, InMemoryPermissionScopeRepository) {
        let appealRepo = InMemoryAppealRepository()
        let exceptionRepo = InMemoryExceptionCaseRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let opLogRepo = InMemoryOperationLogRepository()

        let service = AppealService(
            appealRepo: appealRepo, exceptionCaseRepo: exceptionRepo,
            permissionService: permService, auditService: AuditService(auditLogRepo: auditLogRepo),
            operationLogRepo: opLogRepo
        )
        return (service, appealRepo, exceptionRepo, auditLogRepo, permScopeRepo)
    }

    private func grantScope(_ user: User, functionKey: String, scopeRepo: InMemoryPermissionScopeRepository) {
        let scope = PermissionScope(id: UUID(), userId: user.id, site: testSite, functionKey: functionKey, validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! scopeRepo.save(scope)
    }

    func runAll() {
        print("--- AppealServiceTests ---")
        testSubmitAppeal()
        testSubmitDuplicateAppealDenied()
        testReviewWorkflow()
        testApproveUpdatesExceptionToResolved()
        testDenyUpdatesExceptionToOpen()
        testArchiveAfterApproval()
        testInvalidTransitionDenied()
        testAppealAuditTrail()
        testSalesAssociateCanSubmit()
        testInventoryClerkCannotSubmit()
        testCrossSiteAppealLookupDenied()
        testCrossSiteStartReviewDenied()
    }

    func testSubmitAppeal() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let result = service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID())
        let appeal = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(appeal.status == .submitted)
        TestHelpers.assert(appeal.submittedBy == user.id)
        TestHelpers.assert(appeal.exceptionId == exception.id)

        // Exception should be marked as underAppeal
        let updatedException = exceptionRepo.findById(exception.id)!
        TestHelpers.assert(updatedException.status == .underAppeal)
        print("  PASS: testSubmitAppeal")
    }

    func testSubmitDuplicateAppealDenied() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        _ = service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "First", operationId: UUID())
        let result = service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Second", operationId: UUID())
        TestHelpers.assertFailure(result, code: "ENTITY_DUPLICATE")
        print("  PASS: testSubmitDuplicateAppealDenied")
    }

    func testReviewWorkflow() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!
        let reviewed = TestHelpers.assertSuccess(service.startReview(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID()))!
        TestHelpers.assert(reviewed.status == .underReview)
        TestHelpers.assert(reviewed.reviewerId == reviewer.id)
        print("  PASS: testReviewWorkflow")
    }

    func testApproveUpdatesExceptionToResolved() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!
        _ = service.startReview(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        let approved = TestHelpers.assertSuccess(service.approveAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID()))!

        TestHelpers.assert(approved.status == .approved)
        TestHelpers.assert(approved.resolvedAt != nil)

        let updatedException = exceptionRepo.findById(exception.id)!
        TestHelpers.assert(updatedException.status == .resolved, "Exception should be resolved")
        print("  PASS: testApproveUpdatesExceptionToResolved")
    }

    func testDenyUpdatesExceptionToOpen() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!
        _ = service.startReview(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        let denied = TestHelpers.assertSuccess(service.denyAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID()))!

        TestHelpers.assert(denied.status == .denied)

        let updatedException = exceptionRepo.findById(exception.id)!
        TestHelpers.assert(updatedException.status == .open, "Exception should revert to open")
        print("  PASS: testDenyUpdatesExceptionToOpen")
    }

    func testArchiveAfterApproval() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!
        _ = service.startReview(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        _ = service.approveAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        let archived = TestHelpers.assertSuccess(service.archiveAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID()))!
        TestHelpers.assert(archived.status == .archived)
        print("  PASS: testArchiveAfterApproval")
    }

    func testInvalidTransitionDenied() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let reviewer = TestHelpers.makeComplianceReviewer()
        let sales = TestHelpers.makeSalesAssociate()
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(sales, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: sales, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!
        // Try to approve without first starting review — reviewer is not assigned yet
        let result = service.approveAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "APPEAL_NOT_ASSIGNED")
        print("  PASS: testInvalidTransitionDenied")
    }

    func testAppealAuditTrail() {
        let (service, _, exceptionRepo, auditLogRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)

        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "Test", operationId: UUID()))!
        _ = service.startReview(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())
        _ = service.approveAppeal(by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID())

        let logs = auditLogRepo.findAll()
        TestHelpers.assert(logs.contains { $0.action == "appeal_submitted" }, "Should log submission")
        TestHelpers.assert(logs.contains { $0.action == "appeal_review_started" }, "Should log review start")
        TestHelpers.assert(logs.contains { $0.action == "appeal_approved" }, "Should log approval")
        TestHelpers.assert(logs.contains { $0.action == "exception_resolved_via_appeal" }, "Should log exception resolution")
        print("  PASS: testAppealAuditTrail")
    }

    func testSalesAssociateCanSubmit() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)
        let result = service.submitAppeal(by: user, site: testSite, exceptionId: exception.id, reason: "OK", operationId: UUID())
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testSalesAssociateCanSubmit")
    }

    func testInventoryClerkCannotSubmit() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        grantScope(clerk, functionKey: "appeals", scopeRepo: scopeRepo)
        let exception = makeException(repo: exceptionRepo)
        let result = service.submitAppeal(by: clerk, site: testSite, exceptionId: exception.id, reason: "Try", operationId: UUID())
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testInventoryClerkCannotSubmit")
    }

    private func makeException(repo: InMemoryExceptionCaseRepository, siteId: String? = nil) -> ExceptionCase {
        let e = ExceptionCase(
            id: UUID(), siteId: siteId ?? testSite, type: .missedCheckIn, sourceId: UUID(),
            reason: "Test exception", status: .open, createdAt: Date()
        )
        try! repo.save(e)
        return e
    }

    // MARK: - Cross-Site Isolation Tests

    func testCrossSiteAppealLookupDenied() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)

        // Create exception and appeal on lot-a
        let exception = makeException(repo: exceptionRepo, siteId: "lot-a")
        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: "lot-a", exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!

        // Grant scope for lot-b
        let scopeB = PermissionScope(id: UUID(), userId: reviewer.id, site: "lot-b", functionKey: "appeals", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! scopeRepo.save(scopeB)

        // Attempt to read appeal from lot-b — should return nil (entity not found for that site)
        let result = service.findById(by: reviewer, site: "lot-b", appeal.id)
        let found = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(found == nil, "Cross-site appeal lookup should return nil")
        print("  PASS: testCrossSiteAppealLookupDenied")
    }

    func testCrossSiteStartReviewDenied() {
        let (service, _, exceptionRepo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()
        grantScope(user, functionKey: "appeals", scopeRepo: scopeRepo)
        grantScope(reviewer, functionKey: "appeals", scopeRepo: scopeRepo)

        let exception = makeException(repo: exceptionRepo, siteId: "lot-a")
        let appeal = TestHelpers.assertSuccess(service.submitAppeal(by: user, site: "lot-a", exceptionId: exception.id, reason: "Dispute", operationId: UUID()))!

        let scopeB = PermissionScope(id: UUID(), userId: reviewer.id, site: "lot-b", functionKey: "appeals", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! scopeRepo.save(scopeB)

        // Attempt to start review from lot-b — should fail
        let result = service.startReview(by: reviewer, site: "lot-b", appealId: appeal.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "ENTITY_NOT_FOUND")
        print("  PASS: testCrossSiteStartReviewDenied")
    }
}
