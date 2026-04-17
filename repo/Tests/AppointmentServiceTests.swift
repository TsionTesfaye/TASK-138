import Foundation

final class AppointmentServiceTests {

    private let testSite = "lot-a"
    private let otherSite = "lot-b"

    private func makeServices() -> (
        AppointmentService,
        InMemoryAppointmentRepository,
        InMemoryLeadRepository,
        InMemoryPermissionScopeRepository
    ) {
        let apptRepo = InMemoryAppointmentRepository()
        let leadRepo = InMemoryLeadRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let slaService = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        let opLogRepo = InMemoryOperationLogRepository()
        let service = AppointmentService(
            appointmentRepo: apptRepo,
            leadRepo: leadRepo,
            permissionService: permService,
            slaService: slaService,
            auditService: auditService,
            operationLogRepo: opLogRepo
        )
        return (service, apptRepo, leadRepo, permScopeRepo)
    }

    private func grantScope(_ user: User, scopeRepo: InMemoryPermissionScopeRepository, site: String? = nil) {
        let s = site ?? testSite
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: s, functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! scopeRepo.save(scope)
    }

    private func makeLead(in leadRepo: InMemoryLeadRepository, siteId: String, assignedTo: UUID? = nil) -> Lead {
        let lead = Lead(
            id: UUID(), siteId: siteId, leadType: .quoteRequest, status: .new,
            customerName: "Test Customer", phone: "415-000-0000",
            vehicleInterest: "Sedan", preferredContactWindow: "Morning",
            consentNotes: "", assignedTo: assignedTo,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! leadRepo.save(lead)
        return lead
    }

    func runAll() {
        print("--- AppointmentServiceTests ---")
        testCreateAppointment()
        testCreateAppointmentPermissionDenied()
        testCreateAppointmentCrossSiteLeadDenied()
        testCreateAppointmentIdempotency()
        testUpdateStatusScheduledToConfirmed()
        testUpdateStatusConfirmedToCompleted()
        testUpdateStatusConfirmedToCanceled()
        testUpdateStatusConfirmedToNoShow()
        testUpdateStatusInvalidTransition()
        testUpdateStatusCrossSiteDenied()
        testFindById()
        testFindByIdCrossSiteDenied()
        testFindByLeadId()
        testFindByLeadIdCrossSiteDenied()
        testGetUnconfirmedWithinSLA()
        testGetUnconfirmedWithinSLAOwnershipFiltering()
        testNonOwnerCannotAccessOtherLeadAppointment()
    }

    func testCreateAppointment() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let startTime = Date().addingTimeInterval(3600)

        let result = service.createAppointment(
            by: user, site: testSite, leadId: lead.id, startTime: startTime, operationId: UUID()
        )
        let appt = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(appt.leadId == lead.id)
        TestHelpers.assert(appt.siteId == testSite)
        TestHelpers.assert(appt.status == .scheduled)
        TestHelpers.assert(apptRepo.findAll().count == 1)
        print("  PASS: testCreateAppointment")
    }

    func testCreateAppointmentPermissionDenied() {
        let (service, _, leadRepo, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        // No scope granted
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)

        let result = service.createAppointment(
            by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testCreateAppointmentPermissionDenied")
    }

    func testCreateAppointmentCrossSiteLeadDenied() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        // Lead belongs to a different site
        let lead = makeLead(in: leadRepo, siteId: otherSite, assignedTo: user.id)

        let result = service.createAppointment(
            by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testCreateAppointmentCrossSiteLeadDenied")
    }

    func testCreateAppointmentIdempotency() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let opId = UUID()

        let r1 = service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: opId)
        TestHelpers.assertSuccess(r1)

        let r2 = service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: opId)
        TestHelpers.assertFailure(r2, code: "OP_DUPLICATE")
        print("  PASS: testCreateAppointmentIdempotency")
    }

    func testUpdateStatusScheduledToConfirmed() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = TestHelpers.assertSuccess(
            service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID())
        )!

        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .confirmed, operationId: UUID())
        let updated = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(updated.status == .confirmed)
        TestHelpers.assert(apptRepo.findById(appt.id)?.status == .confirmed)
        print("  PASS: testUpdateStatusScheduledToConfirmed")
    }

    func testUpdateStatusConfirmedToCompleted() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = TestHelpers.assertSuccess(
            service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(
            service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .confirmed, operationId: UUID())
        )

        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .completed, operationId: UUID())
        let updated = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(updated.status == .completed)
        print("  PASS: testUpdateStatusConfirmedToCompleted")
    }

    func testUpdateStatusConfirmedToCanceled() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = TestHelpers.assertSuccess(
            service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(
            service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .confirmed, operationId: UUID())
        )

        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .canceled, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .canceled)
        print("  PASS: testUpdateStatusConfirmedToCanceled")
    }

    func testUpdateStatusConfirmedToNoShow() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = TestHelpers.assertSuccess(
            service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(
            service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .confirmed, operationId: UUID())
        )

        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .noShow, operationId: UUID())
        TestHelpers.assert(TestHelpers.assertSuccess(result)!.status == .noShow)
        print("  PASS: testUpdateStatusConfirmedToNoShow")
    }

    func testUpdateStatusInvalidTransition() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = TestHelpers.assertSuccess(
            service.createAppointment(by: user, site: testSite, leadId: lead.id, startTime: Date(), operationId: UUID())
        )!
        // scheduled → completed is invalid
        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .completed, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testUpdateStatusInvalidTransition")
    }

    func testUpdateStatusCrossSiteDenied() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = Appointment(id: UUID(), siteId: otherSite, leadId: lead.id, startTime: Date(), status: .scheduled)
        try! apptRepo.save(appt)

        grantScope(user, scopeRepo: scopeRepo, site: otherSite)
        let result = service.updateStatus(by: user, site: testSite, appointmentId: appt.id, newStatus: .confirmed, operationId: UUID())
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testUpdateStatusCrossSiteDenied")
    }

    func testFindById() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = Appointment(id: UUID(), siteId: testSite, leadId: lead.id, startTime: Date(), status: .scheduled)
        try! apptRepo.save(appt)

        let result = service.findById(by: user, site: testSite, appt.id)
        let found = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(found?.id == appt.id)
        print("  PASS: testFindById")
    }

    func testFindByIdCrossSiteDenied() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: otherSite, assignedTo: user.id)
        let appt = Appointment(id: UUID(), siteId: otherSite, leadId: lead.id, startTime: Date(), status: .scheduled)
        try! apptRepo.save(appt)

        let result = service.findById(by: user, site: testSite, appt.id)
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testFindByIdCrossSiteDenied")
    }

    func testFindByLeadId() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        let appt = Appointment(id: UUID(), siteId: testSite, leadId: lead.id, startTime: Date(), status: .scheduled)
        try! apptRepo.save(appt)

        let result = service.findByLeadId(by: user, site: testSite, lead.id)
        let list = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(list.count == 1)
        TestHelpers.assert(list[0].id == appt.id)
        print("  PASS: testFindByLeadId")
    }

    func testFindByLeadIdCrossSiteDenied() {
        let (service, _, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: otherSite, assignedTo: user.id)

        let result = service.findByLeadId(by: user, site: testSite, lead.id)
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testFindByLeadIdCrossSiteDenied")
    }

    func testGetUnconfirmedWithinSLA() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: user.id)
        // Appointment starting in 15 min — within the 30-min SLA window
        let appt = Appointment(id: UUID(), siteId: testSite, leadId: lead.id,
                               startTime: Date().addingTimeInterval(15 * 60), status: .scheduled)
        try! apptRepo.save(appt)

        let result = service.getUnconfirmedWithinSLA(by: user, site: testSite)
        let list = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(list.contains { $0.id == appt.id })
        print("  PASS: testGetUnconfirmedWithinSLA")
    }

    func testGetUnconfirmedWithinSLAOwnershipFiltering() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let owner = TestHelpers.makeSalesAssociate(username: "owner")
        let other = TestHelpers.makeSalesAssociate(username: "other")
        grantScope(owner, scopeRepo: scopeRepo)
        grantScope(other, scopeRepo: scopeRepo)

        // Lead assigned to 'owner', appointment for that lead
        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: owner.id)
        let appt = Appointment(id: UUID(), siteId: testSite, leadId: lead.id,
                               startTime: Date().addingTimeInterval(10 * 60), status: .scheduled)
        try! apptRepo.save(appt)

        // owner sees it
        let ownerResult = service.getUnconfirmedWithinSLA(by: owner, site: testSite)
        TestHelpers.assert(TestHelpers.assertSuccess(ownerResult)!.contains { $0.id == appt.id })

        // other does NOT see it
        let otherResult = service.getUnconfirmedWithinSLA(by: other, site: testSite)
        TestHelpers.assert(!TestHelpers.assertSuccess(otherResult)!.contains { $0.id == appt.id })
        print("  PASS: testGetUnconfirmedWithinSLAOwnershipFiltering")
    }

    func testNonOwnerCannotAccessOtherLeadAppointment() {
        let (service, apptRepo, leadRepo, scopeRepo) = makeServices()
        let owner = TestHelpers.makeSalesAssociate(username: "owner")
        let other = TestHelpers.makeSalesAssociate(username: "other")
        grantScope(other, scopeRepo: scopeRepo)

        let lead = makeLead(in: leadRepo, siteId: testSite, assignedTo: owner.id)
        let appt = Appointment(id: UUID(), siteId: testSite, leadId: lead.id, startTime: Date(), status: .scheduled)
        try! apptRepo.save(appt)

        // 'other' tries findById on an appointment whose lead is assigned to 'owner'
        let result = service.findById(by: other, site: testSite, appt.id)
        TestHelpers.assertFailure(result, code: "PERM_DENIED")
        print("  PASS: testNonOwnerCannotAccessOtherLeadAppointment")
    }
}
