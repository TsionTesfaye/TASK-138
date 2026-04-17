import Foundation

final class NoteServiceTests {

    private let testSite = "lot-a"

    private func makeServices() -> (
        NoteService,
        InMemoryNoteRepository,
        InMemoryTagRepository,
        InMemoryPermissionScopeRepository,
        InMemoryLeadRepository
    ) {
        let noteRepo = InMemoryNoteRepository()
        let tagRepo = InMemoryTagRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let leadRepo = InMemoryLeadRepository()
        let apptRepo = InMemoryAppointmentRepository()
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let slaService = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        let opLogRepo = InMemoryOperationLogRepository()
        let service = NoteService(
            noteRepo: noteRepo,
            tagRepo: tagRepo,
            leadRepo: leadRepo,
            permissionService: permService,
            auditService: auditService,
            slaService: slaService,
            operationLogRepo: opLogRepo
        )
        return (service, noteRepo, tagRepo, permScopeRepo, leadRepo)
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
        print("--- NoteServiceTests ---")
        testAddNote()
        testAddNoteEmptyContentRejected()
        testAddNoteWhitespaceOnlyRejected()
        testAddNotePermissionDenied()
        testAddNoteIdempotency()
        testGetNotesForEntity()
        testGetNotesForEntityPermissionDenied()
        testGetOrCreateTagNew()
        testGetOrCreateTagExistingReturned()
        testGetOrCreateTagNormalized()
        testGetOrCreateTagEmptyRejected()
        testAssignTag()
        testAssignTagPermissionDenied()
        testRemoveTag()
        testGetTagsForEntity()
    }

    func testAddNote() {
        let (service, noteRepo, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        let result = service.addNote(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            content: "Follow-up scheduled", operationId: UUID()
        )
        let note = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(note.entityId == entityId)
        TestHelpers.assert(note.entityType == "Lead")
        TestHelpers.assert(note.content == "Follow-up scheduled")
        TestHelpers.assert(note.createdBy == user.id)
        TestHelpers.assert(noteRepo.findAll().count == 1)
        print("  PASS: testAddNote")
    }

    func testAddNoteEmptyContentRejected() {
        let (service, _, _, scopeRepo, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)

        let result = service.addNote(
            by: user, site: testSite, entityId: UUID(), entityType: "Lead",
            content: "", operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "VAL_FAILED")
        print("  PASS: testAddNoteEmptyContentRejected")
    }

    func testAddNoteWhitespaceOnlyRejected() {
        let (service, _, _, scopeRepo, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)

        let result = service.addNote(
            by: user, site: testSite, entityId: UUID(), entityType: "Lead",
            content: "   ", operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "VAL_FAILED")
        print("  PASS: testAddNoteWhitespaceOnlyRejected")
    }

    func testAddNotePermissionDenied() {
        let (service, _, _, _, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        // No scope granted

        let result = service.addNote(
            by: user, site: testSite, entityId: UUID(), entityType: "Lead",
            content: "Some note", operationId: UUID()
        )
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testAddNotePermissionDenied")
    }

    func testAddNoteIdempotency() {
        let (service, _, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let opId = UUID()
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        let r1 = service.addNote(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            content: "First note", operationId: opId
        )
        TestHelpers.assertSuccess(r1)

        let r2 = service.addNote(
            by: user, site: testSite, entityId: entityId, entityType: "Lead",
            content: "Duplicate note", operationId: opId
        )
        TestHelpers.assertFailure(r2, code: "OP_DUPLICATE")
        print("  PASS: testAddNoteIdempotency")
    }

    func testGetNotesForEntity() {
        let (service, _, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        TestHelpers.assertSuccess(service.addNote(by: user, site: testSite, entityId: entityId, entityType: "Lead", content: "Note 1", operationId: UUID()))
        TestHelpers.assertSuccess(service.addNote(by: user, site: testSite, entityId: entityId, entityType: "Lead", content: "Note 2", operationId: UUID()))

        let result = service.getNotesForEntity(by: user, site: testSite, entityId: entityId, entityType: "Lead")
        let notes = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(notes.count == 2)
        print("  PASS: testGetNotesForEntity")
    }

    func testGetNotesForEntityPermissionDenied() {
        let (service, _, _, _, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()

        let result = service.getNotesForEntity(by: user, site: testSite, entityId: UUID(), entityType: "Lead")
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testGetNotesForEntityPermissionDenied")
    }

    func testGetOrCreateTagNew() {
        let (service, _, tagRepo, _, _) = makeServices()

        let result = service.getOrCreateTag(name: "urgent")
        let tag = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(tag.name == "urgent")
        TestHelpers.assert(tagRepo.findAll().count == 1)
        print("  PASS: testGetOrCreateTagNew")
    }

    func testGetOrCreateTagExistingReturned() {
        let (service, _, tagRepo, _, _) = makeServices()

        let t1 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "hot-lead"))!
        let t2 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "hot-lead"))!
        TestHelpers.assert(t1.id == t2.id)
        TestHelpers.assert(tagRepo.findAll().count == 1)
        print("  PASS: testGetOrCreateTagExistingReturned")
    }

    func testGetOrCreateTagNormalized() {
        let (service, _, _, _, _) = makeServices()

        let t1 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "  HOT  "))!
        let t2 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "hot"))!
        TestHelpers.assert(t1.id == t2.id, "Tags with same normalized name should be identical")
        print("  PASS: testGetOrCreateTagNormalized")
    }

    func testGetOrCreateTagEmptyRejected() {
        let (service, _, _, _, _) = makeServices()

        let result = service.getOrCreateTag(name: "   ")
        TestHelpers.assertFailure(result, code: "VAL_FAILED")
        print("  PASS: testGetOrCreateTagEmptyRejected")
    }

    func testAssignTag() {
        let (service, _, tagRepo, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let tag = TestHelpers.assertSuccess(service.getOrCreateTag(name: "follow-up"))!
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        let result = service.assignTag(by: user, site: testSite, tagId: tag.id, entityId: entityId, entityType: "Lead")
        TestHelpers.assertSuccess(result)
        TestHelpers.assert(tagRepo.findAssignments(entityId: entityId, entityType: "Lead").count == 1)
        print("  PASS: testAssignTag")
    }

    func testAssignTagPermissionDenied() {
        let (service, _, _, _, _) = makeServices()
        let user = TestHelpers.makeSalesAssociate()

        let result = service.assignTag(by: user, site: testSite, tagId: UUID(), entityId: UUID(), entityType: "Lead")
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testAssignTagPermissionDenied")
    }

    func testRemoveTag() {
        let (service, _, tagRepo, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let tag = TestHelpers.assertSuccess(service.getOrCreateTag(name: "stale"))!
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)

        TestHelpers.assertSuccess(service.assignTag(by: user, site: testSite, tagId: tag.id, entityId: entityId, entityType: "Lead"))
        TestHelpers.assert(tagRepo.findAssignments(entityId: entityId, entityType: "Lead").count == 1)

        let result = service.removeTag(by: user, site: testSite, tagId: tag.id, entityId: entityId, entityType: "Lead")
        TestHelpers.assertSuccess(result)
        TestHelpers.assert(tagRepo.findAssignments(entityId: entityId, entityType: "Lead").isEmpty)
        print("  PASS: testRemoveTag")
    }

    func testGetTagsForEntity() {
        let (service, _, _, scopeRepo, leadRepo) = makeServices()
        let user = TestHelpers.makeSalesAssociate()
        grantScope(user, scopeRepo: scopeRepo)
        let entityId = UUID()
        makeLead(id: entityId, in: leadRepo)
        let t1 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "vip"))!
        let t2 = TestHelpers.assertSuccess(service.getOrCreateTag(name: "trade-in"))!
        TestHelpers.assertSuccess(service.assignTag(by: user, site: testSite, tagId: t1.id, entityId: entityId, entityType: "Lead"))
        TestHelpers.assertSuccess(service.assignTag(by: user, site: testSite, tagId: t2.id, entityId: entityId, entityType: "Lead"))

        let result = service.getTagsForEntity(by: user, site: testSite, entityId: entityId, entityType: "Lead")
        let assignments = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(assignments.count == 2)
        print("  PASS: testGetTagsForEntity")
    }
}
