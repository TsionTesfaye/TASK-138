import Foundation

final class ReminderServiceTests {

    private let testSite = "lot-a"

    private func makeServices() -> (
        ReminderService,
        InMemoryReminderRepository,
        InMemoryPermissionScopeRepository,
        InMemoryLeadRepository
    ) {
        let reminderRepo = InMemoryReminderRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let opLogRepo = InMemoryOperationLogRepository()
        let leadRepo = InMemoryLeadRepository()
        let service = ReminderService(
            reminderRepo: reminderRepo,
            leadRepo: leadRepo,
            permissionService: permService,
            auditService: auditService,
            operationLogRepo: opLogRepo
        )
        return (service, reminderRepo, permScopeRepo, leadRepo)
    }

    private func grantScope(_ user: User, scopeRepo: InMemoryPermissionScopeRepository) {
        let scope = PermissionScope(
            id: UUID(), userId: user.id, site: testSite, functionKey: "leads",
            validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
        )
        try! scopeRepo.save(scope)
    }

    @discardableResult
    private func makeLead(id: UUID = UUID(), in leadRepo: InMemoryLeadRepository) -> Lead {
        let lead = Lead(
            id: id, siteId: testSite, leadType: .generalContact, status: .new,
            customerName: "Test Customer", phone: "5550000000",
            vehicleInterest: "SUV", preferredContactWindow: "morning",
            consentNotes: "", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(),
            slaDeadline: nil, lastQualifyingAction: nil, archivedAt: nil
        )
        try! leadRepo.save(lead)
        return lead
    }

    func runAll() {
        print("--- ReminderServiceTests ---")
        testCreateReminder()
        testCreateReminderPermissionDenied()
        testCreateReminderIdempotency()
        testCompleteReminder()
        testCompleteReminderNotFound()
        testCompleteAlreadyCompletedRejected()
        testCancelReminder()
        testCancelAlreadyCanceledRejected()
        testCancelCompletedRejected()
        testGetDueReminders()
        testGetDueRemindersExcludesCompleted()
        testFindByEntity()
        testFindByEntityPermissionDenied()
    }

    func testCreateReminder() {
        let (service, reminderRepo, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let dueAt = Date().addingTimeInterval(3600)

        let result = service.createReminder(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            dueAt: dueAt, operationId: UUID()
        )
        let reminder = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(reminder.entityId == entityId)
        TestHelpers.assert(reminder.entityType == "Lead")
        TestHelpers.assert(reminder.status == .pending)
        TestHelpers.assert(reminder.createdBy == user.id)
        TestHelpers.assert(reminderRepo.findAll().count == 1)
        print("  PASS: testCreateReminder")
    }

    func testCreateReminderPermissionDenied() {
        let (service, _, _, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        // No scope granted

        let result = service.createReminder(
            by: user, site: testSite, entityId: UUID(), entityType: "Lead",
            dueAt: Date(), operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testCreateReminderPermissionDenied")
    }

    func testCreateReminderIdempotency() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let opId = UUID()
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        let r1 = service.createReminder(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            dueAt: Date(), operationId: opId
        )
        TestHelpers.assertSuccess(r1)

        let r2 = service.createReminder(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            dueAt: Date(), operationId: opId
        )
        TestHelpers.assertFailure(r2, code: "OP_DUPLICATE")
        print("  PASS: testCreateReminderIdempotency")
    }

    func testCompleteReminder() {
        let (service, reminderRepo, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )!

        let result = service.completeReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID())
        let completed = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(completed.status == .completed)
        TestHelpers.assert(reminderRepo.findById(reminder.id)?.status == .completed)
        print("  PASS: testCompleteReminder")
    }

    func testCompleteReminderNotFound() {
        let (service, _, scopeRepo, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)

        let result = service.completeReminder(by: user, site: testSite, reminderId: UUID(), operationId: UUID())
        TestHelpers.assertFailure(result, code: "ENTITY_NOT_FOUND")
        print("  PASS: testCompleteReminderNotFound")
    }

    func testCompleteAlreadyCompletedRejected() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(service.completeReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID()))

        // Attempting to complete again should be rejected
        let result = service.completeReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testCompleteAlreadyCompletedRejected")
    }

    func testCancelReminder() {
        let (service, reminderRepo, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )!

        let result = service.cancelReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID())
        let canceled = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(canceled.status == .canceled)
        TestHelpers.assert(reminderRepo.findById(reminder.id)?.status == .canceled)
        print("  PASS: testCancelReminder")
    }

    func testCancelAlreadyCanceledRejected() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(service.cancelReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID()))

        let result = service.cancelReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testCancelAlreadyCanceledRejected")
    }

    func testCancelCompletedRejected() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )!
        TestHelpers.assertSuccess(service.completeReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID()))

        let result = service.cancelReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID())
        TestHelpers.assertFailure(result, code: "STATE_INVALID")
        print("  PASS: testCancelCompletedRejected")
    }

    func testGetDueReminders() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        // Due 1 hour ago — should appear
        TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead",
                                   dueAt: Date().addingTimeInterval(-3600), operationId: UUID())
        )
        // Due 1 hour from now — should NOT appear
        TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead",
                                   dueAt: Date().addingTimeInterval(3600), operationId: UUID())
        )

        let due = service.getDueReminders(now: Date())
        TestHelpers.assert(due.count == 1)
        print("  PASS: testGetDueReminders")
    }

    func testGetDueRemindersExcludesCompleted() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        let reminder = TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead",
                                   dueAt: Date().addingTimeInterval(-3600), operationId: UUID())
        )!
        TestHelpers.assertSuccess(service.completeReminder(by: user, site: testSite, reminderId: reminder.id, operationId: UUID()))

        let due = service.getDueReminders(now: Date())
        TestHelpers.assert(due.isEmpty, "Completed reminders must not appear in due list")
        print("  PASS: testGetDueRemindersExcludesCompleted")
    }

    func testFindByEntity() {
        let (service, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        let otherEntityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        makeLead(id: otherEntityId, in: leadRepo)

        TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )
        TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: entityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )
        // Different entity — should not appear
        TestHelpers.assertSuccess(
            service.createReminder(by: user, site: testSite, entityId: otherEntityId, entityType: "Lead", dueAt: Date(), operationId: UUID())
        )

        let result = service.findByEntity(by: user, site: testSite, entityId: entityId, entityType: "Lead")
        let reminders = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(reminders.count == 2)
        print("  PASS: testFindByEntity")
    }

    func testFindByEntityPermissionDenied() {
        let (service, _, _, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()

        let result = service.findByEntity(by: user, site: testSite, entityId: UUID(), entityType: "Lead")
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testFindByEntityPermissionDenied")
    }
}
