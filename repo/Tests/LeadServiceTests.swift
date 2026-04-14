import Foundation

/// Tests for LeadService: create, transitions, admin override, SLA reset.
final class LeadServiceTests {

    private let testSite = "lot-a"

    private func makeServices() -> (LeadService, InMemoryLeadRepository, InMemoryAuditLogRepository, InMemoryPermissionScopeRepository) {
        let leadRepo = InMemoryLeadRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let apptRepo = InMemoryAppointmentRepository()
        let slaService = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        let reminderRepo = InMemoryReminderRepository()
        let opLogRepo = InMemoryOperationLogRepository()
        let service = LeadService(
            leadRepo: leadRepo, permissionService: permService, slaService: slaService,
            auditService: auditService, operationLogRepo: opLogRepo, reminderRepo: reminderRepo
        )
        return (service, leadRepo, auditLogRepo, permScopeRepo)
    }

    private func grantScope(_ user: User, scopeRepo: InMemoryPermissionScopeRepository) {
        let scope = PermissionScope(id: UUID(), userId: user.id, site: testSite, functionKey: "leads", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! scopeRepo.save(scope)
    }

    func runAll() {
        print("--- LeadServiceTests ---")
        testCreateLead()
        testCreateLeadSetsDeadline()
        testTransitionNewToFollowUp()
        testTransitionFollowUpToClosedWon()
        testTransitionFollowUpToInvalid()
        testAdminOnlyReopenFromInvalid()
        testAdminOnlyReopenFromClosedWon()
        testNonAdminCannotReopen()
        testInvalidTransitionRejected()
        testCreateLeadPermissionDenied()
        testIdempotency()
        testPhoneMasking()
        testStatusChangeResetseSLA()
    }

    func testCreateLead() {
        let (service, repo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest, customerName: "John", phone: "415-555-0123",
            vehicleInterest: "Sedan", preferredContactWindow: "Morning", consentNotes: "OK"
        )
        let result = service.createLead(by: user, site: testSite, input: input, operationId: UUID())
        let lead = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(lead.status == .new)
        TestHelpers.assert(lead.customerName == "John")
        TestHelpers.assert(repo.findAll().count == 1)
        print("  PASS: testCreateLead")
    }

    func testCreateLeadSetsDeadline() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let input = LeadService.CreateLeadInput(
            leadType: .appointment, customerName: "Jane", phone: "415-555-0123",
            vehicleInterest: "SUV", preferredContactWindow: "Afternoon", consentNotes: ""
        )
        let lead = TestHelpers.assertSuccess(service.createLead(by: user, site: testSite, input: input, operationId: UUID()))!
        TestHelpers.assert(lead.slaDeadline != nil, "SLA deadline should be set")
        TestHelpers.assert(lead.lastQualifyingAction != nil, "Last qualifying action should be set")
        print("  PASS: testCreateLeadSetsDeadline")
    }

    func testTransitionNewToFollowUp() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: user)
        let result = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        let updated = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(updated.status == .followUp)
        print("  PASS: testTransitionNewToFollowUp")
    }

    func testTransitionFollowUpToClosedWon() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: user)
        _ = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        let result = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .closedWon, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .closedWon)
        print("  PASS: testTransitionFollowUpToClosedWon")
    }

    func testTransitionFollowUpToInvalid() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: user)
        _ = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        let result = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .invalid, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .invalid)
        print("  PASS: testTransitionFollowUpToInvalid")
    }

    func testAdminOnlyReopenFromInvalid() {
        let (service, _, _, scopeRepo) = makeServices()
        let sales = TestHelpers.makeSalesAssociate()
        let admin = TestHelpers.makeAdmin()
        grantScope(sales, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: sales)
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .invalid, operationId: UUID())
        let result = service.updateLeadStatus(by: admin, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .followUp)
        print("  PASS: testAdminOnlyReopenFromInvalid")
    }

    func testAdminOnlyReopenFromClosedWon() {
        let (service, _, _, scopeRepo) = makeServices()
        let sales = TestHelpers.makeSalesAssociate()
        let admin = TestHelpers.makeAdmin()
        grantScope(sales, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: sales)
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .closedWon, operationId: UUID())
        let result = service.updateLeadStatus(by: admin, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .followUp)
        print("  PASS: testAdminOnlyReopenFromClosedWon")
    }

    func testNonAdminCannotReopen() {
        let (service, _, _, scopeRepo) = makeServices()
        let sales = TestHelpers.makeSalesAssociate()
        grantScope(sales, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: sales)
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        _ = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .invalid, operationId: UUID())
        let result = service.updateLeadStatus(by: sales, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testNonAdminCannotReopen")
    }

    func testInvalidTransitionRejected() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: user)
        // new → closedWon is not allowed
        let result = service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .closedWon, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testInvalidTransitionRejected")
    }

    func testCreateLeadPermissionDenied() {
        let (service, _, _, _) = makeServices()
        let clerk = TestHelpers.makeInventoryClerk()
        let input = LeadService.CreateLeadInput(
            leadType: .generalContact, customerName: "Test", phone: "415-555-0000",
            vehicleInterest: "", preferredContactWindow: "", consentNotes: ""
        )
        let result = service.createLead(by: clerk, site: testSite, input: input, operationId: UUID())
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testCreateLeadPermissionDenied")
    }

    func testIdempotency() {
        let (service, _, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let opId = UUID()
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest, customerName: "Test", phone: "415-555-0000",
            vehicleInterest: "", preferredContactWindow: "", consentNotes: ""
        )
        _ = service.createLead(by: user, site: testSite, input: input, operationId: opId)
        let result = service.createLead(by: user, site: testSite, input: input, operationId: opId)
        TestHelpers.assertFailure(result, code: "OP_DUPLICATE")
        print("  PASS: testIdempotency")
    }

    func testPhoneMasking() {
        TestHelpers.assert(LeadService.maskPhone("415-555-0123") == "***-***-0123")
        TestHelpers.assert(LeadService.maskPhone("5550123") == "***-***-0123")
        TestHelpers.assert(LeadService.maskPhone("12") == "***-***-****")
        print("  PASS: testPhoneMasking")
    }

    func testStatusChangeResetseSLA() {
        let (service, repo, _, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = createTestLead(service: service, user: user)
        let originalDeadline = lead.slaDeadline!
        let updated = TestHelpers.assertSuccess(
            service.updateLeadStatus(by: user, site: testSite, leadId: lead.id, newStatus: .followUp, operationId: UUID())
        )!
        TestHelpers.assert(updated.slaDeadline != nil)
        TestHelpers.assert(updated.lastQualifyingAction! >= lead.lastQualifyingAction!)
        print("  PASS: testStatusChangeResetseSLA")
    }

    private func createTestLead(service: LeadService, user: User) -> Lead {
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest, customerName: "Test", phone: "415-555-0000",
            vehicleInterest: "", preferredContactWindow: "", consentNotes: ""
        )
        return TestHelpers.assertSuccess(service.createLead(by: user, site: testSite, input: input, operationId: UUID()))!
    }
}
