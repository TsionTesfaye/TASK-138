#if canImport(CoreData)
import Foundation

final class ViewModelTests {

    private let site = "lot-a"

    // MARK: - Helpers

    private func makeContainer() -> ServiceContainer {
        ServiceContainer(inMemory: true)
    }

    @discardableResult
    private func startAdmin(in container: ServiceContainer) -> User {
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)
        return admin
    }

    @discardableResult
    private func startSalesAssociate(in container: ServiceContainer, username: String = "sales1") -> User {
        let user = TestHelpers.makeSalesAssociate(username: username)
        try! container.userRepo.save(user)
        container.sessionService.startSession(user: user)
        return user
    }

    @discardableResult
    private func startComplianceReviewer(in container: ServiceContainer) -> User {
        let user = TestHelpers.makeComplianceReviewer()
        try! container.userRepo.save(user)
        container.sessionService.startSession(user: user)
        return user
    }

    private func makeLeadVM(container: ServiceContainer) -> LeadViewModel {
        let vm = LeadViewModel(container: container)
        vm.site = site
        return vm
    }

    private func makeInventoryVM(container: ServiceContainer) -> InventoryViewModel {
        let vm = InventoryViewModel(container: container)
        vm.site = site
        return vm
    }

    private func makeDashboardVM(container: ServiceContainer) -> DashboardViewModel {
        let vm = DashboardViewModel(container: container)
        vm.site = site
        return vm
    }

    private func grantScope(_ user: User, functionKey: String, in container: ServiceContainer) {
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: site, functionKey: functionKey,
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! container.permissionScopeRepo.save(scope)
    }

    private func saveLead(
        in container: ServiceContainer,
        status: LeadStatus = .new,
        assignedTo: UUID? = nil,
        siteId: String? = nil
    ) -> Lead {
        let lead = Lead(
            id: UUID(),
            siteId: siteId ?? site,
            leadType: .quoteRequest,
            status: status,
            customerName: "Test Customer",
            phone: "415-000-0000",
            vehicleInterest: "Sedan",
            preferredContactWindow: "AM",
            consentNotes: "",
            assignedTo: assignedTo,
            createdAt: Date(),
            updatedAt: Date(),
            slaDeadline: nil,
            lastQualifyingAction: nil,
            archivedAt: nil
        )
        try! container.leadRepo.save(lead)
        return lead
    }

    // MARK: - runAll

    func runAll() {
        print("--- ViewModelTests ---")

        // LeadViewModel tests
        testLoadLeadsEmptyState()
        testLoadLeadsLoadedState()
        testLoadLeadsFilterByStatus()
        testLoadLeadsSessionExpired()
        testLoadLeadDetailFound()
        testLoadLeadDetailNotFound()
        testCreateLeadSuccess()
        testCreateLeadNoSession()
        testTransitionLeadNewToFollowUp()
        testTransitionLeadInvalidState()
        testAddNoteToLead()
        testAddReminderToLead()
        testCreateAppointmentForLead()

        // InventoryViewModel tests
        testLoadTasksEmptyState()
        testLoadTasksLoadedState()
        testLoadTasksSessionExpired()
        testCreateTask()
        testCreateTaskNoSession()
        testScannerLookupHit()
        testScannerLookupMiss()
        testComputeVariancesAutoAdjustsBelowThreshold()

        // DashboardViewModel tests
        testDashboardLoadsDataForAdmin()
        testDashboardRoleString()
        testDashboardNewLeadCount()
        testDashboardCountsZeroWhenNoData()
        testDashboardSessionExpired()
        testDashboardSalesAssociateData()
        testDashboardPendingAppealCount()
        testDashboardUnconfirmedAppointmentCount()
    }

    // MARK: - LeadViewModel Tests

    func testLoadLeadsEmptyState() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeLeadVM(container: container)
        vm.loadLeads()
        TestHelpers.assert(vm.state == .empty("No leads found"), "Expected empty state")
        TestHelpers.assert(vm.leads.isEmpty, "Leads should be empty")
        print("  PASS: testLoadLeadsEmptyState")
    }

    func testLoadLeadsLoadedState() {
        let container = makeContainer()
        startAdmin(in: container)
        saveLead(in: container)
        saveLead(in: container)
        let vm = makeLeadVM(container: container)
        vm.loadLeads()
        TestHelpers.assert(vm.state == .loaded, "Expected loaded state")
        TestHelpers.assert(vm.leads.count == 2, "Expected 2 leads")
        print("  PASS: testLoadLeadsLoadedState")
    }

    func testLoadLeadsFilterByStatus() {
        let container = makeContainer()
        startAdmin(in: container)
        saveLead(in: container, status: .new)
        saveLead(in: container, status: .followUp)
        let vm = makeLeadVM(container: container)
        vm.filterStatus = .new
        vm.loadLeads()
        TestHelpers.assert(vm.leads.count == 1, "Expected 1 filtered lead")
        TestHelpers.assert(vm.leads[0].status == .new, "Filtered lead should be .new")
        print("  PASS: testLoadLeadsFilterByStatus")
    }

    func testLoadLeadsSessionExpired() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeLeadVM(container: container)
        container.sessionService.now = { Date().addingTimeInterval(6 * 60) }
        vm.loadLeads()
        if case .error(let msg) = vm.state {
            TestHelpers.assert(
                msg.contains("Session expired") || msg.contains("SESSION_EXPIRED"),
                "Error message should mention session expiry, got: \(msg)"
            )
        } else {
            TestHelpers.assert(false, "Expected error state for expired session")
        }
        print("  PASS: testLoadLeadsSessionExpired")
    }

    func testLoadLeadDetailFound() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        let lead = saveLead(in: container, assignedTo: admin.id)
        let vm = makeLeadVM(container: container)
        vm.loadLeadDetail(id: lead.id)
        TestHelpers.assert(vm.selectedLead?.id == lead.id, "selectedLead id should match")
        TestHelpers.assert(vm.state == .loaded, "Expected loaded state")
        print("  PASS: testLoadLeadDetailFound")
    }

    func testLoadLeadDetailNotFound() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeLeadVM(container: container)
        vm.loadLeadDetail(id: UUID())
        if case .error(let msg) = vm.state {
            TestHelpers.assert(msg.contains("Lead not found"), "Error should say lead not found, got: \(msg)")
        } else {
            TestHelpers.assert(false, "Expected error state for unknown lead id")
        }
        print("  PASS: testLoadLeadDetailNotFound")
    }

    func testCreateLeadSuccess() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeLeadVM(container: container)
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Jane Doe",
            phone: "415-555-0100",
            vehicleInterest: "SUV",
            preferredContactWindow: "AM",
            consentNotes: "OK"
        )
        let result = vm.createLead(input: input)
        let lead = TestHelpers.assertSuccess(result)
        TestHelpers.assert(lead?.status == .new, "New lead should have .new status")
        print("  PASS: testCreateLeadSuccess")
    }

    func testCreateLeadNoSession() {
        let container = makeContainer()
        // No startSession call — session is not valid
        let vm = makeLeadVM(container: container)
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Jane Doe",
            phone: "415-555-0100",
            vehicleInterest: "SUV",
            preferredContactWindow: "AM",
            consentNotes: ""
        )
        let result = vm.createLead(input: input)
        TestHelpers.assertFailure(result, code: "SESSION_EXPIRED")
        print("  PASS: testCreateLeadNoSession")
    }

    func testTransitionLeadNewToFollowUp() {
        let container = makeContainer()
        startAdmin(in: container)
        let lead = saveLead(in: container, status: .new)
        let vm = makeLeadVM(container: container)
        let result = vm.transitionLead(id: lead.id, to: .followUp)
        let updated = TestHelpers.assertSuccess(result)
        TestHelpers.assert(updated?.status == .followUp, "Lead should be .followUp")
        print("  PASS: testTransitionLeadNewToFollowUp")
    }

    func testTransitionLeadInvalidState() {
        // closedWon → followUp is STATE_INVALID for a non-admin
        let container = makeContainer()
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)
        grantScope(sales, functionKey: "leads", in: container)
        let lead = saveLead(in: container, status: .closedWon, assignedTo: sales.id)
        let vm = makeLeadVM(container: container)
        let result = vm.transitionLead(id: lead.id, to: .followUp)
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testTransitionLeadInvalidState")
    }

    func testAddNoteToLead() {
        let container = makeContainer()
        startAdmin(in: container)
        let lead = saveLead(in: container)
        let vm = makeLeadVM(container: container)
        let result = vm.addNote(leadId: lead.id, content: "test note")
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testAddNoteToLead")
    }

    func testAddReminderToLead() {
        let container = makeContainer()
        startAdmin(in: container)
        let lead = saveLead(in: container)
        let vm = makeLeadVM(container: container)
        let result = vm.addReminder(leadId: lead.id, dueAt: Date().addingTimeInterval(3600))
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testAddReminderToLead")
    }

    func testCreateAppointmentForLead() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        let lead = saveLead(in: container, assignedTo: admin.id)
        let vm = makeLeadVM(container: container)
        let result = vm.createAppointment(leadId: lead.id, startTime: Date().addingTimeInterval(3600))
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testCreateAppointmentForLead")
    }

    // MARK: - InventoryViewModel Tests

    func testLoadTasksEmptyState() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeInventoryVM(container: container)
        vm.loadTasks()
        TestHelpers.assert(vm.state == .empty("No count tasks"), "Expected empty state")
        TestHelpers.assert(vm.tasks.isEmpty, "Tasks should be empty")
        print("  PASS: testLoadTasksEmptyState")
    }

    func testLoadTasksLoadedState() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        let task = CountTask(id: UUID(), siteId: site, assignedTo: admin.id, status: .pending)
        try! container.countTaskRepo.save(task)
        let vm = makeInventoryVM(container: container)
        vm.loadTasks()
        TestHelpers.assert(vm.state == .loaded, "Expected loaded state")
        TestHelpers.assert(vm.tasks.count == 1, "Expected 1 task")
        print("  PASS: testLoadTasksLoadedState")
    }

    func testLoadTasksSessionExpired() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeInventoryVM(container: container)
        container.sessionService.now = { Date().addingTimeInterval(6 * 60) }
        vm.loadTasks()
        if case .error = vm.state {
            // Expected
        } else {
            TestHelpers.assert(false, "Expected error state for expired session")
        }
        print("  PASS: testLoadTasksSessionExpired")
    }

    func testCreateTask() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        let vm = makeInventoryVM(container: container)
        let result = vm.createTask(assignedTo: admin.id)
        _ = TestHelpers.assertSuccess(result)
        print("  PASS: testCreateTask")
    }

    func testCreateTaskNoSession() {
        let container = makeContainer()
        // No session started
        let vm = makeInventoryVM(container: container)
        let result = vm.createTask(assignedTo: UUID())
        TestHelpers.assertFailure(result, code: "SESSION_EXPIRED")
        print("  PASS: testCreateTaskNoSession")
    }

    func testScannerLookupHit() {
        let container = makeContainer()
        startAdmin(in: container)
        let item = InventoryItem(
            id: UUID(), siteId: site, identifier: "VIN-001",
            expectedQty: 1, location: "Lot A", custodian: "Bob"
        )
        try! container.inventoryItemRepo.save(item)
        let vm = makeInventoryVM(container: container)
        let result = vm.scannerLookup("VIN-001")
        let found = TestHelpers.assertSuccess(result)
        TestHelpers.assert(found?.identifier == "VIN-001", "Should find item by identifier")
        print("  PASS: testScannerLookupHit")
    }

    func testScannerLookupMiss() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeInventoryVM(container: container)
        let result = vm.scannerLookup("UNKNOWN")
        TestHelpers.assertFailure(result, code: "INV_SCAN_INVALID")
        print("  PASS: testScannerLookupMiss")
    }

    func testComputeVariancesAutoAdjustsBelowThreshold() {
        // expectedQty=100, countedQty=102 → diff=2 ≤ threshold(3) → requiresApproval=false
        // Verifies end-to-end through InventoryViewModel that computeVariances auto-processes below-threshold variances
        let container = makeContainer()
        let admin = startAdmin(in: container)
        grantScope(admin, functionKey: "inventory", in: container)

        let item = InventoryItem(id: UUID(), siteId: site, identifier: "VM-AUTO-1", expectedQty: 100, location: "Lot A", custodian: "Bob")
        try! container.inventoryItemRepo.save(item)

        let vm = makeInventoryVM(container: container)
        let task = TestHelpers.assertSuccess(vm.createTask(assignedTo: admin.id))!
        let batch = TestHelpers.assertSuccess(vm.createBatch(taskId: task.id))!
        _ = TestHelpers.assertSuccess(vm.recordEntry(batchId: batch.id, itemId: item.id, qty: 102, location: "Lot A", custodian: "Bob"))

        let variances = TestHelpers.assertSuccess(vm.computeVariances(batchId: batch.id))!
        let v = variances.first { $0.type == .surplus }!
        TestHelpers.assert(!v.requiresApproval, "Should be below threshold")
        TestHelpers.assert(v.approved, "Below-threshold variance should be auto-approved during computeVariances")
        TestHelpers.assert(container.inventoryItemRepo.findById(item.id)!.expectedQty == 102, "Item qty should be updated to counted qty")
        let autoOrder = container.adjustmentOrderRepo.findByVarianceId(v.id)
        TestHelpers.assert(autoOrder?.status == .executed, "Auto-adjustment order should have executed status")
        print("  PASS: testComputeVariancesAutoAdjustsBelowThreshold")
    }

    // MARK: - DashboardViewModel Tests

    func testDashboardLoadsDataForAdmin() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert(vm.state == .loaded, "Expected loaded state")
        TestHelpers.assert(vm.data != nil, "Data should not be nil")
        TestHelpers.assert(vm.data?.username == admin.username, "Username should match")
        print("  PASS: testDashboardLoadsDataForAdmin")
    }

    func testDashboardRoleString() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeDashboardVM(container: container)
        vm.load()
        let role = vm.data?.role ?? ""
        TestHelpers.assert(
            role.lowercased().contains("administrator"),
            "Role string should contain 'administrator', got: \(role)"
        )
        print("  PASS: testDashboardRoleString")
    }

    func testDashboardNewLeadCount() {
        let container = makeContainer()
        startAdmin(in: container)
        saveLead(in: container, status: .new)
        saveLead(in: container, status: .new)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert(vm.data?.newLeadCount == 2, "Expected 2 new leads, got \(vm.data?.newLeadCount ?? -1)")
        print("  PASS: testDashboardNewLeadCount")
    }

    func testDashboardCountsZeroWhenNoData() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert(vm.data?.newLeadCount == 0, "newLeadCount should be 0")
        TestHelpers.assert(vm.data?.pendingAppealCount == 0, "pendingAppealCount should be 0")
        print("  PASS: testDashboardCountsZeroWhenNoData")
    }

    func testDashboardSessionExpired() {
        let container = makeContainer()
        startAdmin(in: container)
        let vm = makeDashboardVM(container: container)
        container.sessionService.now = { Date().addingTimeInterval(6 * 60) }
        vm.load()
        if case .error = vm.state {
            // Expected
        } else {
            TestHelpers.assert(false, "Expected error state for expired session")
        }
        print("  PASS: testDashboardSessionExpired")
    }

    func testDashboardSalesAssociateData() {
        let container = makeContainer()
        let sales = TestHelpers.makeSalesAssociate(username: "salesuser")
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)
        // Grant leads and carpool scopes so dashboard queries don't fail on scope check
        grantScope(sales, functionKey: "leads", in: container)
        grantScope(sales, functionKey: "carpool", in: container)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert(vm.state == .loaded, "Expected loaded state for sales associate")
        print("  PASS: testDashboardSalesAssociateData")
    }

    func testDashboardPendingAppealCount() {
        let container = makeContainer()
        let reviewer = startComplianceReviewer(in: container)
        grantScope(reviewer, functionKey: "appeals", in: container)
        // Save a submitted appeal directly to the repo
        let exception = ExceptionCase(
            id: UUID(), siteId: site, type: .missedCheckIn,
            sourceId: UUID(), reason: "Test", status: .open, createdAt: Date()
        )
        try! container.exceptionCaseRepo.save(exception)
        let appeal = Appeal(
            id: UUID(), siteId: site, exceptionId: exception.id,
            status: .submitted, reviewerId: nil, submittedBy: reviewer.id,
            reason: "Dispute", resolvedAt: nil
        )
        try! container.appealRepo.save(appeal)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert((vm.data?.pendingAppealCount ?? 0) >= 1, "pendingAppealCount should be >= 1")
        print("  PASS: testDashboardPendingAppealCount")
    }

    func testDashboardUnconfirmedAppointmentCount() {
        let container = makeContainer()
        let admin = startAdmin(in: container)
        // Save a lead and an appointment starting in 15 minutes (within 30 min SLA window)
        let lead = saveLead(in: container, assignedTo: admin.id)
        let appointment = Appointment(
            id: UUID(),
            siteId: site,
            leadId: lead.id,
            startTime: Date().addingTimeInterval(15 * 60),
            status: .scheduled
        )
        try! container.appointmentRepo.save(appointment)
        let vm = makeDashboardVM(container: container)
        vm.load()
        TestHelpers.assert(
            (vm.data?.unconfirmedAppointmentCount ?? 0) >= 1,
            "unconfirmedAppointmentCount should be >= 1"
        )
        print("  PASS: testDashboardUnconfirmedAppointmentCount")
    }
}
#endif
