#if canImport(CoreData)
import Foundation

final class NegativeUITests {

    private let testSite = "lot-a"

    func runAll() {
        print("--- NegativeUITests ---")
        testLeadLoadPermissionDeniedNoScope()
        testLeadCreatePermissionDenied()
        testLeadTransitionInvalidStateClosedWonToNew()
        testLeadTransitionInvalidStateInvalidToFollowUp()
        testInventoryCreateTaskPermissionDenied()
        testInventoryApproveVarianceNonAdmin()
        testSessionTimeoutLeadCreate()
        testSessionTimeoutLeadLoadSetsErrorState()
        testSessionTimeoutInventoryLoad()
        testSessionTimeoutDashboardLoad()
        testCrossSiteLeadIsolation()
        testCrossSiteInventoryIsolation()
        testNonReviewerCannotStartAppealReview()
        testApproveAppealByNonReviewerDenied()
        testLoginWithWrongPasswordFails()
    }

    func testLeadLoadPermissionDeniedNoScope() {
        let container = ServiceContainer(inMemory: true)
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeads()

        if case .error(_) = vm.state {
            // expected
        } else {
            TestHelpers.assert(false, "Expected error state for no-scope sales associate, got \(vm.state)")
        }
        print("  PASS: testLeadLoadPermissionDeniedNoScope")
    }

    func testLeadCreatePermissionDenied() {
        let container = ServiceContainer(inMemory: true)
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        let input = LeadService.CreateLeadInput(
            leadType: .generalContact,
            customerName: "Test User",
            phone: "415-555-0001",
            vehicleInterest: "Sedan",
            preferredContactWindow: "Morning",
            consentNotes: "OK"
        )
        let result = vm.createLead(input: input)
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testLeadCreatePermissionDenied")
    }

    func testLeadTransitionInvalidStateClosedWonToNew() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let lead = Lead(
            id: UUID(), siteId: testSite, leadType: .quoteRequest, status: .closedWon,
            customerName: "Jane", phone: "415-555-0002", vehicleInterest: "SUV",
            preferredContactWindow: "Afternoon", consentNotes: "", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! container.leadRepo.save(lead)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        let result = vm.transitionLead(id: lead.id, to: .new)
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testLeadTransitionInvalidStateClosedWonToNew")
    }

    func testLeadTransitionInvalidStateInvalidToFollowUp() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(admin)
        try! container.userRepo.save(sales)

        let scope = PermissionScope(
            id: UUID(), userId: sales.id, site: testSite, functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(scope)

        let lead = Lead(
            id: UUID(), siteId: testSite, leadType: .quoteRequest, status: .invalid,
            customerName: "Bob", phone: "415-555-0003", vehicleInterest: "Truck",
            preferredContactWindow: "Evening", consentNotes: "", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! container.leadRepo.save(lead)

        container.sessionService.startSession(user: sales)
        let vm = LeadViewModel(container: container)
        vm.site = testSite

        let result = vm.transitionLead(id: lead.id, to: .followUp)
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testLeadTransitionInvalidStateInvalidToFollowUp")
    }

    func testInventoryCreateTaskPermissionDenied() {
        let container = ServiceContainer(inMemory: true)
        let clerk = TestHelpers.makeInventoryClerk()
        try! container.userRepo.save(clerk)
        container.sessionService.startSession(user: clerk)

        let vm = InventoryViewModel(container: container)
        vm.site = testSite

        let result = vm.createTask(assignedTo: clerk.id)
        switch result {
        case .failure(_):
            break
        case .success(_):
            TestHelpers.assert(false, "Expected failure for clerk with no inventory scope")
        }
        print("  PASS: testInventoryCreateTaskPermissionDenied")
    }

    func testInventoryApproveVarianceNonAdmin() {
        let container = ServiceContainer(inMemory: true)
        let clerk = TestHelpers.makeInventoryClerk()
        try! container.userRepo.save(clerk)

        let scope = PermissionScope(
            id: UUID(), userId: clerk.id, site: testSite, functionKey: "inventory",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(scope)
        container.sessionService.startSession(user: clerk)

        let vm = InventoryViewModel(container: container)
        vm.site = testSite

        let result = vm.approveVariance(varianceId: UUID())
        switch result {
        case .failure(_):
            break
        case .success(_):
            TestHelpers.assert(false, "Expected failure for non-admin approving variance")
        }
        print("  PASS: testInventoryApproveVarianceNonAdmin")
    }

    func testSessionTimeoutLeadCreate() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)

        let startTime = Date()
        container.sessionService.now = { startTime }
        container.sessionService.startSession(user: admin)
        container.sessionService.now = { startTime.addingTimeInterval(6 * 60) }

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Alice",
            phone: "415-555-0004",
            vehicleInterest: "Coupe",
            preferredContactWindow: "Morning",
            consentNotes: "OK"
        )
        let result = vm.createLead(input: input)
        TestHelpers.assertFailure(result, code: "SESSION_EXPIRED")
        print("  PASS: testSessionTimeoutLeadCreate")
    }

    func testSessionTimeoutLeadLoadSetsErrorState() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)

        let startTime = Date()
        container.sessionService.now = { startTime }
        container.sessionService.startSession(user: admin)
        container.sessionService.now = { startTime.addingTimeInterval(6 * 60) }

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeads()

        if case .error(_) = vm.state {
            // expected
        } else {
            TestHelpers.assert(false, "Expected error state after session timeout, got \(vm.state)")
        }
        print("  PASS: testSessionTimeoutLeadLoadSetsErrorState")
    }

    func testSessionTimeoutInventoryLoad() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)

        let startTime = Date()
        container.sessionService.now = { startTime }
        container.sessionService.startSession(user: admin)
        container.sessionService.now = { startTime.addingTimeInterval(6 * 60) }

        let vm = InventoryViewModel(container: container)
        vm.site = testSite
        vm.loadTasks()

        if case .error(_) = vm.state {
            // expected
        } else {
            TestHelpers.assert(false, "Expected error state after session timeout on inventory, got \(vm.state)")
        }
        print("  PASS: testSessionTimeoutInventoryLoad")
    }

    func testSessionTimeoutDashboardLoad() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)

        let startTime = Date()
        container.sessionService.now = { startTime }
        container.sessionService.startSession(user: admin)
        container.sessionService.now = { startTime.addingTimeInterval(6 * 60) }

        let vm = DashboardViewModel(container: container)
        vm.site = testSite
        vm.load()

        if case .error(_) = vm.state {
            // expected
        } else {
            TestHelpers.assert(false, "Expected error state after session timeout on dashboard, got \(vm.state)")
        }
        print("  PASS: testSessionTimeoutDashboardLoad")
    }

    func testCrossSiteLeadIsolation() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let lead = Lead(
            id: UUID(), siteId: "lot-b", leadType: .generalContact, status: .new,
            customerName: "CrossSite", phone: "415-555-0005", vehicleInterest: "Van",
            preferredContactWindow: "Morning", consentNotes: "", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! container.leadRepo.save(lead)

        let result = container.leadService.findById(by: admin, site: "lot-a", lead.id)
        switch result {
        case .success(let found):
            TestHelpers.assert(found == nil, "Cross-site lead must not be returned for lot-a query")
        case .failure(_):
            break
        }
        print("  PASS: testCrossSiteLeadIsolation")
    }

    func testCrossSiteInventoryIsolation() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let task = CountTask(id: UUID(), siteId: "lot-b", assignedTo: admin.id, status: .pending)
        try! container.countTaskRepo.save(task)

        let vm = InventoryViewModel(container: container)
        vm.site = "lot-a"
        vm.loadTasks()

        TestHelpers.assert(vm.tasks.isEmpty, "Tasks from lot-b must not appear in lot-a query")
        print("  PASS: testCrossSiteInventoryIsolation")
    }

    func testNonReviewerCannotStartAppealReview() {
        let container = ServiceContainer(inMemory: true)
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)

        let salesScope = PermissionScope(
            id: UUID(), userId: sales.id, site: testSite, functionKey: "appeals",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(salesScope)

        let exception = ExceptionCase(
            id: UUID(), siteId: testSite, type: .missedCheckIn, sourceId: UUID(),
            reason: "Test", status: .open, createdAt: Date()
        )
        try! container.exceptionCaseRepo.save(exception)

        container.sessionService.startSession(user: sales)

        let appealResult = container.appealService.submitAppeal(
            by: sales, site: testSite, exceptionId: exception.id, reason: "Dispute", operationId: UUID()
        )
        let appeal = TestHelpers.assertSuccess(appealResult)!

        container.sessionService.startSession(user: sales)
        let result = container.appealService.startReview(
            by: sales, site: testSite, appealId: appeal.id, operationId: UUID()
        )
        switch result {
        case .failure(_):
            break
        case .success(_):
            TestHelpers.assert(false, "Sales associate must not be able to start appeal review")
        }
        print("  PASS: testNonReviewerCannotStartAppealReview")
    }

    func testApproveAppealByNonReviewerDenied() {
        let container = ServiceContainer(inMemory: true)
        let reviewer = TestHelpers.makeComplianceReviewer()
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(reviewer)
        try! container.userRepo.save(sales)

        let reviewerScope = PermissionScope(
            id: UUID(), userId: reviewer.id, site: testSite, functionKey: "appeals",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        let salesScope = PermissionScope(
            id: UUID(), userId: sales.id, site: testSite, functionKey: "appeals",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(reviewerScope)
        try! container.permissionScopeRepo.save(salesScope)

        let exception = ExceptionCase(
            id: UUID(), siteId: testSite, type: .missedCheckIn, sourceId: UUID(),
            reason: "Test", status: .open, createdAt: Date()
        )
        try! container.exceptionCaseRepo.save(exception)

        container.sessionService.startSession(user: sales)
        let appeal = TestHelpers.assertSuccess(
            container.appealService.submitAppeal(
                by: sales, site: testSite, exceptionId: exception.id, reason: "Appeal reason", operationId: UUID()
            )
        )!

        container.sessionService.startSession(user: reviewer)
        _ = container.appealService.startReview(
            by: reviewer, site: testSite, appealId: appeal.id, operationId: UUID()
        )

        container.sessionService.startSession(user: sales)
        let result = container.appealService.approveAppeal(
            by: sales, site: testSite, appealId: appeal.id, operationId: UUID()
        )
        switch result {
        case .failure(_):
            break
        case .success(_):
            TestHelpers.assert(false, "Sales associate must not be able to approve an appeal")
        }
        print("  PASS: testApproveAppealByNonReviewerDenied")
    }

    func testLoginWithWrongPasswordFails() {
        let container = ServiceContainer(inMemory: true)
        _ = container.authService.bootstrap(username: "admin", password: "SecurePass123")
        let result = container.authService.login(username: "admin", password: "WrongPassword12")
        TestHelpers.assertFailure(result, code: "AUTH_INVALID")
        print("  PASS: testLoginWithWrongPasswordFails")
    }
}
#endif
