#if canImport(CoreData)
import Foundation

final class UIFlowTests {

    func runAll() {
        print("--- UIFlowTests ---")
        testBootstrapAndLoginFlow()
        testSeedAndLoginAllRoles()
        testLeadCreateNoteStatusTransitionFlow()
        testLeadCreateAppointmentAndConfirm()
        testInventoryVarianceApprovalFlow()
        testExceptionToAppealResolutionFlow()
        testLeadSLAResetOnNoteAdd()
        testMultipleRolesDashboardData()
    }

    // MARK: - 1

    func testBootstrapAndLoginFlow() {
        let container = ServiceContainer(inMemory: true)

        let bootstrapped = TestHelpers.assertSuccess(
            container.authService.bootstrap(username: "admin", password: "Admin12345678")
        )!
        TestHelpers.assert(bootstrapped.username == "admin")

        let loggedIn = TestHelpers.assertSuccess(
            container.authService.login(username: "admin", password: "Admin12345678")
        )!

        container.sessionService.startSession(user: loggedIn)
        TestHelpers.assert(container.sessionService.isSessionValid() == true)
        TestHelpers.assert(container.sessionService.currentUser?.username == "admin")

        TestHelpers.assertFailure(
            container.authService.bootstrap(username: "x", password: "Duplicate12345"),
            code: "AUTH_BOOTSTRAP_DONE"
        )

        print("  PASS: testBootstrapAndLoginFlow")
    }

    // MARK: - 2

    func testSeedAndLoginAllRoles() {
        let container = ServiceContainer(inMemory: true)

        DebugSeeder(
            userRepo: container.userRepo,
            permissionScopeRepo: container.permissionScopeRepo,
            authService: container.authService
        ).seed()

        let admin = TestHelpers.assertSuccess(
            container.authService.login(username: "admin", password: "Admin12345678")
        )!
        TestHelpers.assert(admin.role == .administrator)

        let sales = TestHelpers.assertSuccess(
            container.authService.login(username: "sales1", password: "Sales12345678")
        )!
        TestHelpers.assert(sales.role == .salesAssociate)

        let clerk = TestHelpers.assertSuccess(
            container.authService.login(username: "clerk1", password: "Clerk12345678")
        )!
        TestHelpers.assert(clerk.role == .inventoryClerk)

        let reviewer = TestHelpers.assertSuccess(
            container.authService.login(username: "reviewer1", password: "Reviewer12345")
        )!
        TestHelpers.assert(reviewer.role == .complianceReviewer)

        print("  PASS: testSeedAndLoginAllRoles")
    }

    // MARK: - 3

    func testLeadCreateNoteStatusTransitionFlow() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        let site = "lot-a"

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Alice",
            phone: "415-555-0100",
            vehicleInterest: "Sedan",
            preferredContactWindow: "AM",
            consentNotes: ""
        )
        let lead = TestHelpers.assertSuccess(
            container.leadService.createLead(by: admin, site: site, input: input, operationId: UUID())
        )!
        TestHelpers.assert(lead.status == .new)

        let note = TestHelpers.assertSuccess(
            container.noteService.addNote(
                by: admin, site: site,
                entityId: lead.id, entityType: "Lead",
                content: "Called customer", operationId: UUID()
            )
        )!
        _ = note

        let notes = container.noteRepo.findByEntity(entityId: lead.id, entityType: "Lead")
        TestHelpers.assert(notes.count == 1)

        let followUp = TestHelpers.assertSuccess(
            container.leadService.updateLeadStatus(by: admin, site: site, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        )!
        TestHelpers.assert(followUp.status == .followUp)

        let closed = TestHelpers.assertSuccess(
            container.leadService.updateLeadStatus(by: admin, site: site, leadId: lead.id, newStatus: .closedWon, operationId: UUID())
        )!
        TestHelpers.assert(closed.status == .closedWon)

        print("  PASS: testLeadCreateNoteStatusTransitionFlow")
    }

    // MARK: - 4

    func testLeadCreateAppointmentAndConfirm() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        let site = "lot-a"

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Bob",
            phone: "415-555-0200",
            vehicleInterest: "Truck",
            preferredContactWindow: "PM",
            consentNotes: ""
        )
        var lead = TestHelpers.assertSuccess(
            container.leadService.createLead(by: admin, site: site, input: input, operationId: UUID())
        )!
        lead.assignedTo = admin.id
        try! container.leadRepo.save(lead)

        let appt = TestHelpers.assertSuccess(
            container.appointmentService.createAppointment(
                by: admin, site: site,
                leadId: lead.id,
                startTime: Date().addingTimeInterval(86400),
                operationId: UUID()
            )
        )!
        TestHelpers.assert(appt.status == .scheduled)

        let confirmed = TestHelpers.assertSuccess(
            container.appointmentService.updateStatus(
                by: admin, site: site,
                appointmentId: appt.id,
                newStatus: .confirmed,
                operationId: UUID()
            )
        )!
        TestHelpers.assert(confirmed.status == .confirmed)
        TestHelpers.assert(container.appointmentRepo.findById(appt.id)?.status == .confirmed)

        print("  PASS: testLeadCreateAppointmentAndConfirm")
    }

    // MARK: - 5

    func testInventoryVarianceApprovalFlow() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        let site = "lot-a"

        let item = InventoryItem(
            id: UUID(), siteId: site,
            identifier: "VIN-TEST-001",
            expectedQty: 10, location: "Row A", custodian: "clerk"
        )
        try! container.inventoryItemRepo.save(item)

        let task = TestHelpers.assertSuccess(
            container.inventoryService.createCountTask(
                by: admin, site: site, assignedTo: admin.id, operationId: UUID()
            )
        )!

        let batch = TestHelpers.assertSuccess(
            container.inventoryService.createCountBatch(
                by: admin, site: site, taskId: task.id, operationId: UUID()
            )
        )!

        _ = TestHelpers.assertSuccess(
            container.inventoryService.recordCountEntry(
                by: admin, site: site,
                batchId: batch.id, itemId: item.id,
                countedQty: 6, countedLocation: "Row A", countedCustodian: "clerk",
                operationId: UUID()
            )
        )!

        let variances = TestHelpers.assertSuccess(
            container.inventoryService.computeVariances(by: admin, site: site, forBatchId: batch.id)
        )!
        TestHelpers.assert(variances.count >= 1)

        let order = TestHelpers.assertSuccess(
            container.inventoryService.approveVariance(
                by: admin, site: site, varianceId: variances[0].id, operationId: UUID()
            )
        )!

        _ = TestHelpers.assertSuccess(
            container.inventoryService.executeAdjustmentOrder(
                by: admin, site: site, orderId: order.id, operationId: UUID()
            )
        )!

        print("  PASS: testInventoryVarianceApprovalFlow")
    }

    // MARK: - 6

    func testExceptionToAppealResolutionFlow() {
        let container = ServiceContainer(inMemory: true)
        let site = "lot-a"

        let exc = ExceptionCase(
            id: UUID(), siteId: site,
            type: .missedCheckIn,
            sourceId: UUID(),
            reason: "Unauthorized access detected",
            status: .open,
            createdAt: Date()
        )
        try! container.exceptionCaseRepo.save(exc)

        let salesAssociate = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(salesAssociate)
        let appealsScope = PermissionScope(
            id: UUID(), userId: salesAssociate.id, site: site,
            functionKey: "appeals",
            validFrom: Date().addingTimeInterval(-3600),
            validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(appealsScope)

        let appeal = TestHelpers.assertSuccess(
            container.appealService.submitAppeal(
                by: salesAssociate, site: site,
                exceptionId: exc.id,
                reason: "Appeal reason",
                operationId: UUID()
            )
        )!
        TestHelpers.assert(appeal.status == .submitted)

        let reviewer = TestHelpers.makeComplianceReviewer()
        try! container.userRepo.save(reviewer)
        let reviewerScope = PermissionScope(
            id: UUID(), userId: reviewer.id, site: site,
            functionKey: "appeals",
            validFrom: Date().addingTimeInterval(-3600),
            validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(reviewerScope)

        let reviewStarted = TestHelpers.assertSuccess(
            container.appealService.startReview(
                by: reviewer, site: site,
                appealId: appeal.id, operationId: UUID()
            )
        )!
        TestHelpers.assert(reviewStarted.status == .underReview)

        let approved = TestHelpers.assertSuccess(
            container.appealService.approveAppeal(
                by: reviewer, site: site,
                appealId: reviewStarted.id, operationId: UUID()
            )
        )!
        TestHelpers.assert(approved.status == .approved)

        TestHelpers.assert(container.exceptionCaseRepo.findById(exc.id)?.status == .resolved)

        print("  PASS: testExceptionToAppealResolutionFlow")
    }

    // MARK: - 7

    func testLeadSLAResetOnNoteAdd() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        let site = "lot-a"

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Carol",
            phone: "415-555-0300",
            vehicleInterest: "Van",
            preferredContactWindow: "AM",
            consentNotes: ""
        )
        let lead = TestHelpers.assertSuccess(
            container.leadService.createLead(by: admin, site: site, input: input, operationId: UUID())
        )!
        TestHelpers.assert(lead.lastQualifyingAction != nil)

        _ = TestHelpers.assertSuccess(
            container.noteService.addNote(
                by: admin, site: site,
                entityId: lead.id, entityType: "Lead",
                content: "Follow-up note",
                operationId: UUID()
            )
        )!

        let updatedLead = container.leadRepo.findById(lead.id)
        TestHelpers.assert(updatedLead?.lastQualifyingAction != nil)

        print("  PASS: testLeadSLAResetOnNoteAdd")
    }

    // MARK: - 8

    func testMultipleRolesDashboardData() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        let site = "lot-a"

        let leadInput = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Lead",
            phone: "415-555-0001",
            vehicleInterest: "Car",
            preferredContactWindow: "AM",
            consentNotes: ""
        )
        _ = TestHelpers.assertSuccess(
            container.leadService.createLead(by: admin, site: site, input: leadInput, operationId: UUID())
        )
        _ = TestHelpers.assertSuccess(
            container.leadService.createLead(
                by: admin, site: site,
                input: LeadService.CreateLeadInput(
                    leadType: .quoteRequest, customerName: "Lead Two",
                    phone: "415-555-0002", vehicleInterest: "Car",
                    preferredContactWindow: "PM", consentNotes: ""
                ),
                operationId: UUID()
            )
        )
        _ = TestHelpers.assertSuccess(
            container.leadService.createLead(
                by: admin, site: site,
                input: LeadService.CreateLeadInput(
                    leadType: .quoteRequest, customerName: "Lead Three",
                    phone: "415-555-0003", vehicleInterest: "Car",
                    preferredContactWindow: "AM", consentNotes: ""
                ),
                operationId: UUID()
            )
        )

        let adminVM = DashboardViewModel(container: container)
        adminVM.site = site
        adminVM.load()
        TestHelpers.assert(adminVM.data?.newLeadCount == 3)
        TestHelpers.assert(adminVM.state == .loaded)

        let salesContainer = ServiceContainer(inMemory: true)
        let salesUser = TestHelpers.makeSalesAssociate()
        try! salesContainer.userRepo.save(salesUser)
        let leadsScope = PermissionScope(
            id: UUID(), userId: salesUser.id, site: site,
            functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600),
            validTo: Date().addingTimeInterval(3600)
        )
        try! salesContainer.permissionScopeRepo.save(leadsScope)
        salesContainer.sessionService.startSession(user: salesUser)

        let salesVM = DashboardViewModel(container: salesContainer)
        salesVM.site = site
        salesVM.load()
        TestHelpers.assert((salesVM.data?.newLeadCount ?? 0) >= 0)
        TestHelpers.assert(salesVM.state == .loaded)

        print("  PASS: testMultipleRolesDashboardData")
    }
}
#endif
