import Foundation
import CoreData

/// Real Core Data integration tests using PersistenceController(inMemory: true).
/// No mocks. No fake repositories. Real Core Data stack with in-memory store.
final class CoreDataIntegrationTests {

    private func makeContext() -> NSManagedObjectContext {
        let pc = PersistenceController(inMemory: true)
        return pc.viewContext
    }

    func runAll() {
        print("--- CoreDataIntegrationTests ---")
        testUserSaveFetchUpdateDelete()
        testLeadSaveFetchUpdateDelete()
        testInventoryItemSaveFetchUpdateDelete()
        testAppointmentPersistence()
        testAuditLogPersistence()
        testVariancePersistence()
        testAppealPersistence()
        testExceptionCasePersistence()
        testCountEntryPersistence()
        testEvidenceFilePersistence()
        testAdjustmentOrderPersistence()
        testNotePersistence()
        testReminderPersistence()
        testPoolOrderPersistence()
        testCheckInPersistence()
        testOperationLogPersistence()
        testTagAndAssignmentPersistence()
        testBusinessHoursConfigPersistence()
        testCarpoolMatchPersistence()
        testPermissionScopePersistence()
        testFullFlowBootstrapToLead()
        testFullFlowInventoryVarianceApproval()
        testFullFlowExceptionAppealResolution()
    }

    // MARK: - User CRUD

    func testUserSaveFetchUpdateDelete() {
        let ctx = makeContext()
        let repo = CoreDataUserRepository(context: ctx)

        // Save
        let user = User(
            id: UUID(), username: "testuser", passwordHash: "hash", passwordSalt: "salt",
            role: .salesAssociate, biometricEnabled: false, failedAttempts: 0,
            lastFailedAttempt: nil, lockoutUntil: nil, createdAt: Date(), isActive: true
        )
        try! repo.save(user)

        // Fetch
        let fetched = repo.findById(user.id)
        TestHelpers.assert(fetched != nil, "User should be fetchable")
        TestHelpers.assert(fetched!.username == "testuser")
        TestHelpers.assert(fetched!.role == .salesAssociate)

        // Fetch by username
        let byName = repo.findByUsername("testuser")
        TestHelpers.assert(byName != nil, "Should find by username")

        // Update
        var updated = fetched!
        updated.failedAttempts = 3
        updated.biometricEnabled = true
        try! repo.save(updated)
        let refetched = repo.findById(user.id)!
        TestHelpers.assert(refetched.failedAttempts == 3)
        TestHelpers.assert(refetched.biometricEnabled == true)

        // Delete
        try! repo.delete(user.id)
        TestHelpers.assert(repo.findById(user.id) == nil, "User should be deleted")
        TestHelpers.assert(repo.count() == 0)
        print("  PASS: testUserSaveFetchUpdateDelete")
    }

    // MARK: - Lead CRUD

    func testLeadSaveFetchUpdateDelete() {
        let ctx = makeContext()
        let repo = CoreDataLeadRepository(context: ctx)

        let lead = Lead(
            id: UUID(), siteId: "lot-a", leadType: .quoteRequest, status: .new,
            customerName: "Jane", phone: "415-555-0123",
            vehicleInterest: "Sedan", preferredContactWindow: "Morning",
            consentNotes: "OK", assignedTo: nil, createdAt: Date(), updatedAt: Date(),
            slaDeadline: Date().addingTimeInterval(7200), lastQualifyingAction: Date(), archivedAt: nil
        )
        try! repo.save(lead)

        let fetched = repo.findById(lead.id)!
        TestHelpers.assert(fetched.customerName == "Jane")
        TestHelpers.assert(fetched.status == .new)
        TestHelpers.assert(fetched.phone == "415-555-0123")
        TestHelpers.assert(fetched.slaDeadline != nil)

        // Update status
        var updated = fetched
        updated.status = .followUp
        updated.updatedAt = Date()
        try! repo.save(updated)
        TestHelpers.assert(repo.findById(lead.id)!.status == .followUp)

        // Query by status
        let followUps = repo.findByStatus(.followUp)
        TestHelpers.assert(followUps.count == 1)

        // Delete
        try! repo.delete(lead.id)
        TestHelpers.assert(repo.findById(lead.id) == nil)
        print("  PASS: testLeadSaveFetchUpdateDelete")
    }

    // MARK: - InventoryItem CRUD

    func testInventoryItemSaveFetchUpdateDelete() {
        let ctx = makeContext()
        let repo = CoreDataInventoryItemRepository(context: ctx)

        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "VIN-999", expectedQty: 50, location: "Lot B", custodian: "Alice")
        try! repo.save(item)

        let fetched = repo.findById(item.id)!
        TestHelpers.assert(fetched.identifier == "VIN-999")
        TestHelpers.assert(fetched.expectedQty == 50)

        let byIdent = repo.findByIdentifier("VIN-999")
        TestHelpers.assert(byIdent != nil)

        var updated = fetched
        updated.expectedQty = 55
        try! repo.save(updated)
        TestHelpers.assert(repo.findById(item.id)!.expectedQty == 55)

        try! repo.delete(item.id)
        TestHelpers.assert(repo.findById(item.id) == nil)
        print("  PASS: testInventoryItemSaveFetchUpdateDelete")
    }

    // MARK: - Other Entity Persistence

    func testAppointmentPersistence() {
        let ctx = makeContext()
        let repo = CoreDataAppointmentRepository(context: ctx)
        let appt = Appointment(id: UUID(), siteId: "lot-a", leadId: UUID(), startTime: Date(), status: .scheduled)
        try! repo.save(appt)
        let f = repo.findById(appt.id)!
        TestHelpers.assert(f.status == .scheduled)
        TestHelpers.assert(f.leadId == appt.leadId)
        print("  PASS: testAppointmentPersistence")
    }

    func testAuditLogPersistence() {
        let ctx = makeContext()
        let repo = CoreDataAuditLogRepository(context: ctx)
        let log = AuditLog(id: UUID(), actorId: UUID(), action: "test", entityId: UUID(), timestamp: Date(), tombstone: false, deletedAt: nil, deletedBy: nil)
        try! repo.save(log)
        let f = repo.findById(log.id)!
        TestHelpers.assert(f.action == "test")
        TestHelpers.assert(!f.tombstone)
        print("  PASS: testAuditLogPersistence")
    }

    func testVariancePersistence() {
        let ctx = makeContext()
        let repo = CoreDataVarianceRepository(context: ctx)
        let v = Variance(id: UUID(), siteId: "lot-a", itemId: UUID(), expectedQty: 10, countedQty: 15, type: .surplus, requiresApproval: true, approved: false)
        try! repo.save(v)
        let f = repo.findById(v.id)!
        TestHelpers.assert(f.type == .surplus)
        TestHelpers.assert(f.requiresApproval)
        TestHelpers.assert(!f.approved)
        print("  PASS: testVariancePersistence")
    }

    func testAppealPersistence() {
        let ctx = makeContext()
        let repo = CoreDataAppealRepository(context: ctx)
        let a = Appeal(id: UUID(), siteId: "lot-a", exceptionId: UUID(), status: .submitted, reviewerId: nil, submittedBy: UUID(), reason: "test reason", resolvedAt: nil)
        try! repo.save(a)
        let f = repo.findById(a.id)!
        TestHelpers.assert(f.status == .submitted)
        TestHelpers.assert(f.reason == "test reason")
        print("  PASS: testAppealPersistence")
    }

    func testExceptionCasePersistence() {
        let ctx = makeContext()
        let repo = CoreDataExceptionCaseRepository(context: ctx)
        let e = ExceptionCase(id: UUID(), siteId: "lot-a", type: .missedCheckIn, sourceId: UUID(), reason: "no show", status: .open, createdAt: Date())
        try! repo.save(e)
        let f = repo.findById(e.id)!
        TestHelpers.assert(f.type == .missedCheckIn)
        TestHelpers.assert(f.status == .open)
        print("  PASS: testExceptionCasePersistence")
    }

    func testCountEntryPersistence() {
        let ctx = makeContext()
        let repo = CoreDataCountEntryRepository(context: ctx)
        let ce = CountEntry(id: UUID(), siteId: "lot-a", batchId: UUID(), itemId: UUID(), countedQty: 7, countedLocation: "A1", countedCustodian: "Bob")
        try! repo.save(ce)
        let f = repo.findById(ce.id)!
        TestHelpers.assert(f.countedQty == 7)
        TestHelpers.assert(f.countedLocation == "A1")
        print("  PASS: testCountEntryPersistence")
    }

    func testEvidenceFilePersistence() {
        let ctx = makeContext()
        let repo = CoreDataEvidenceFileRepository(context: ctx)
        let ef = EvidenceFile(id: UUID(), siteId: "lot-a", entityId: UUID(), entityType: "Appeal", filePath: "/tmp/x.jpg", fileType: .jpg, fileSize: 1024, hash: "abc123", createdAt: Date(), pinnedByAdmin: false)
        try! repo.save(ef)
        let f = repo.findById(ef.id)!
        TestHelpers.assert(f.fileType == .jpg)
        TestHelpers.assert(f.fileSize == 1024)
        print("  PASS: testEvidenceFilePersistence")
    }

    func testAdjustmentOrderPersistence() {
        let ctx = makeContext()
        let repo = CoreDataAdjustmentOrderRepository(context: ctx)
        let ao = AdjustmentOrder(id: UUID(), siteId: "lot-a", varianceId: UUID(), approvedBy: UUID(), createdAt: Date(), status: .pending)
        try! repo.save(ao)
        let f = repo.findById(ao.id)!
        TestHelpers.assert(f.status == .pending)
        print("  PASS: testAdjustmentOrderPersistence")
    }

    func testNotePersistence() {
        let ctx = makeContext()
        let repo = CoreDataNoteRepository(context: ctx)
        let n = Note(id: UUID(), siteId: "lot-a", entityId: UUID(), entityType: "Lead", content: "Follow up call", createdAt: Date(), createdBy: UUID())
        try! repo.save(n)
        let f = repo.findById(n.id)!
        TestHelpers.assert(f.content == "Follow up call")
        TestHelpers.assert(f.entityType == "Lead")
        print("  PASS: testNotePersistence")
    }

    func testReminderPersistence() {
        let ctx = makeContext()
        let repo = CoreDataReminderRepository(context: ctx)
        let r = Reminder(id: UUID(), siteId: "lot-a", entityId: UUID(), entityType: "Lead", createdBy: UUID(), dueAt: Date(), status: .pending)
        try! repo.save(r)
        let f = repo.findById(r.id)!
        TestHelpers.assert(f.status == .pending)
        print("  PASS: testReminderPersistence")
    }

    func testPoolOrderPersistence() {
        let ctx = makeContext()
        let repo = CoreDataPoolOrderRepository(context: ctx)
        let po = PoolOrder(id: UUID(), siteId: "lot-a", originLat: 37.77, originLng: -122.41, destinationLat: 37.80, destinationLng: -122.27, startTime: Date(), endTime: Date().addingTimeInterval(3600), seatsAvailable: 3, vehicleType: "Sedan", createdBy: UUID(), status: .draft)
        try! repo.save(po)
        let f = repo.findById(po.id)!
        TestHelpers.assert(f.status == .draft)
        TestHelpers.assert(f.seatsAvailable == 3)
        TestHelpers.assert(abs(f.originLat - 37.77) < 0.001)
        print("  PASS: testPoolOrderPersistence")
    }

    func testCheckInPersistence() {
        let ctx = makeContext()
        let repo = CoreDataCheckInRepository(context: ctx)
        let ci = CheckIn(id: UUID(), siteId: "lot-a", userId: UUID(), timestamp: Date(), locationLat: 37.77, locationLng: -122.41)
        try! repo.save(ci)
        let f = repo.findById(ci.id)!
        TestHelpers.assert(f.userId == ci.userId)
        print("  PASS: testCheckInPersistence")
    }

    func testOperationLogPersistence() {
        let ctx = makeContext()
        let repo = CoreDataOperationLogRepository(context: ctx)
        let opId = UUID()
        TestHelpers.assert(!repo.exists(opId), "Should not exist yet")
        try! repo.save(opId)
        TestHelpers.assert(repo.exists(opId), "Should exist after save")
        print("  PASS: testOperationLogPersistence")
    }

    func testTagAndAssignmentPersistence() {
        let ctx = makeContext()
        let repo = CoreDataTagRepository(context: ctx)
        let tag = Tag(id: UUID(), name: "urgent")
        try! repo.save(tag)
        TestHelpers.assert(repo.findByName("urgent") != nil)

        let entityId = UUID()
        let assignment = TagAssignment(tagId: tag.id, entityId: entityId, entityType: "Lead")
        try! repo.saveAssignment(assignment)
        let found = repo.findAssignments(entityId: entityId, entityType: "Lead")
        TestHelpers.assert(found.count == 1)
        TestHelpers.assert(found[0].tagId == tag.id)

        try! repo.deleteAssignment(tagId: tag.id, entityId: entityId, entityType: "Lead")
        TestHelpers.assert(repo.findAssignments(entityId: entityId, entityType: "Lead").isEmpty)
        print("  PASS: testTagAndAssignmentPersistence")
    }

    func testBusinessHoursConfigPersistence() {
        let ctx = makeContext()
        let repo = CoreDataBusinessHoursConfigRepository(context: ctx)
        // Default should be returned when nothing saved
        let def = repo.get()
        TestHelpers.assert(def.startHour == 9)

        // Save custom
        let custom = BusinessHoursConfig(id: UUID(), startHour: 8, endHour: 18, workingDays: [2, 3, 4, 5, 6])
        try! repo.save(custom)
        let fetched = repo.get()
        TestHelpers.assert(fetched.startHour == 8)
        TestHelpers.assert(fetched.endHour == 18)
        print("  PASS: testBusinessHoursConfigPersistence")
    }

    func testCarpoolMatchPersistence() {
        let ctx = makeContext()
        let repo = CoreDataCarpoolMatchRepository(context: ctx)
        let m = CarpoolMatch(id: UUID(), requestOrderId: UUID(), offerOrderId: UUID(), matchScore: 0.85, detourMiles: 0.3, timeOverlapMinutes: 45, accepted: false, createdAt: Date())
        try! repo.save(m)
        let f = repo.findById(m.id)!
        TestHelpers.assert(abs(f.matchScore - 0.85) < 0.001)
        TestHelpers.assert(!f.accepted)
        print("  PASS: testCarpoolMatchPersistence")
    }

    func testPermissionScopePersistence() {
        let ctx = makeContext()
        let repo = CoreDataPermissionScopeRepository(context: ctx)
        let userId = UUID()
        let scope = PermissionScope(id: UUID(), userId: userId, site: "lot-a", functionKey: "leads", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! repo.save(scope)
        let found = repo.findByUserIdAndSiteAndFunction(userId: userId, site: "lot-a", functionKey: "leads", at: Date())
        TestHelpers.assert(found.count == 1)
        print("  PASS: testPermissionScopePersistence")
    }

    // MARK: - Full Flow: Bootstrap → Login → Create Lead → Core Data → Retrieve

    func testFullFlowBootstrapToLead() {
        let ctx = makeContext()
        let userRepo = CoreDataUserRepository(context: ctx)
        let leadRepo = CoreDataLeadRepository(context: ctx)
        let auditLogRepo = CoreDataAuditLogRepository(context: ctx)
        let opLogRepo = CoreDataOperationLogRepository(context: ctx)
        let permScopeRepo = CoreDataPermissionScopeRepository(context: ctx)
        let bhRepo = CoreDataBusinessHoursConfigRepository(context: ctx)
        let apptRepo = CoreDataAppointmentRepository(context: ctx)
        let reminderRepo = CoreDataReminderRepository(context: ctx)

        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let authService = AuthService(userRepo: userRepo, auditService: auditService, operationLogRepo: opLogRepo)
        let slaService = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        let leadService = LeadService(leadRepo: leadRepo, permissionService: permService, slaService: slaService, auditService: auditService, operationLogRepo: opLogRepo, reminderRepo: reminderRepo)

        // 1. Bootstrap admin
        let bootstrapResult = authService.bootstrap(username: "admin", password: "SecurePass123")
        let admin = TestHelpers.assertSuccess(bootstrapResult)!
        TestHelpers.assert(admin.role == .administrator)

        // Verify persisted in Core Data
        let persistedAdmin = userRepo.findByUsername("admin")
        TestHelpers.assert(persistedAdmin != nil, "Admin must persist in Core Data")

        // 2. Login
        let loginResult = authService.login(username: "admin", password: "SecurePass123")
        let loggedIn = TestHelpers.assertSuccess(loginResult)!
        TestHelpers.assert(loggedIn.id == admin.id)

        // 3. Create lead
        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest, customerName: "Jane Doe", phone: "415-555-0123",
            vehicleInterest: "Accord", preferredContactWindow: "AM", consentNotes: "Yes"
        )
        let leadResult = leadService.createLead(by: loggedIn, site: "lot-a", input: input, operationId: UUID())
        let lead = TestHelpers.assertSuccess(leadResult)!

        // 4. Verify persisted in Core Data
        let persistedLead = leadRepo.findById(lead.id)
        TestHelpers.assert(persistedLead != nil, "Lead must persist in Core Data")
        TestHelpers.assert(persistedLead!.customerName == "Jane Doe")
        TestHelpers.assert(persistedLead!.status == .new)
        TestHelpers.assert(persistedLead!.slaDeadline != nil)

        // 5. Verify audit logs persisted
        let allLogs = auditLogRepo.findAll()
        TestHelpers.assert(allLogs.contains { $0.action == "bootstrap_admin_created" })
        TestHelpers.assert(allLogs.contains { $0.action == "login_success" })
        TestHelpers.assert(allLogs.contains { $0.action == "lead_created" })

        print("  PASS: testFullFlowBootstrapToLead")
    }

    // MARK: - Full Flow: Inventory Count → Variance → Approval → Adjustment

    func testFullFlowInventoryVarianceApproval() {
        let ctx = makeContext()
        let itemRepo = CoreDataInventoryItemRepository(context: ctx)
        let taskRepo = CoreDataCountTaskRepository(context: ctx)
        let batchRepo = CoreDataCountBatchRepository(context: ctx)
        let entryRepo = CoreDataCountEntryRepository(context: ctx)
        let varianceRepo = CoreDataVarianceRepository(context: ctx)
        let adjRepo = CoreDataAdjustmentOrderRepository(context: ctx)
        let auditLogRepo = CoreDataAuditLogRepository(context: ctx)
        let opLogRepo = CoreDataOperationLogRepository(context: ctx)
        let permScopeRepo = CoreDataPermissionScopeRepository(context: ctx)

        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let inventoryService = InventoryService(
            inventoryItemRepo: itemRepo, countTaskRepo: taskRepo, countBatchRepo: batchRepo,
            countEntryRepo: entryRepo, varianceRepo: varianceRepo, adjustmentOrderRepo: adjRepo,
            permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo
        )

        let admin = TestHelpers.makeAdmin()
        let clerk = TestHelpers.makeInventoryClerk()

        // 1. Create inventory item
        let item = InventoryItem(id: UUID(), siteId: "lot-a", identifier: "VIN-001", expectedQty: 10, location: "Lot A", custodian: "Bob")
        try! itemRepo.save(item)

        // 2. Create count task and batch
        // Create scope for clerk
        let clerkScope = PermissionScope(id: UUID(), userId: clerk.id, site: "lot-a", functionKey: "inventory", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! permScopeRepo.save(clerkScope)

        let task = TestHelpers.assertSuccess(inventoryService.createCountTask(by: clerk, site: "lot-a", assignedTo: clerk.id, operationId: UUID()))!
        let batch = TestHelpers.assertSuccess(inventoryService.createCountBatch(by: clerk, site: "lot-a", taskId: task.id, operationId: UUID()))!

        // 3. Record count entry (surplus: counted 20 vs expected 10)
        _ = TestHelpers.assertSuccess(inventoryService.recordCountEntry(
            by: clerk, site: "lot-a", batchId: batch.id, itemId: item.id, countedQty: 20,
            countedLocation: "Lot A", countedCustodian: "Bob", operationId: UUID()))

        // 4. Compute variances
        let variancesResult = inventoryService.computeVariances(by: clerk, site: "lot-a", forBatchId: batch.id)
        let variances = TestHelpers.assertSuccess(variancesResult)!
        TestHelpers.assert(!variances.isEmpty, "Should detect variance")
        let surplus = variances.first { $0.type == .surplus }!
        TestHelpers.assert(surplus.requiresApproval, "Large variance requires approval")

        // Verify variance persisted
        TestHelpers.assert(varianceRepo.findById(surplus.id) != nil, "Variance must persist")

        // 5. Admin approves variance
        let order = TestHelpers.assertSuccess(inventoryService.approveVariance(by: admin, site: "lot-a", varianceId: surplus.id, operationId: UUID()))!
        TestHelpers.assert(order.status == .approved)

        // 6. Execute adjustment
        let executed = TestHelpers.assertSuccess(inventoryService.executeAdjustmentOrder(by: admin, site: "lot-a", orderId: order.id, operationId: UUID()))!
        TestHelpers.assert(executed.status == .executed)

        // 7. Verify inventory updated
        let updatedItem = itemRepo.findById(item.id)!
        TestHelpers.assert(updatedItem.expectedQty == 20, "Expected qty should be updated to 20")

        print("  PASS: testFullFlowInventoryVarianceApproval")
    }

    // MARK: - Full Flow: Exception → Appeal → Resolution

    func testFullFlowExceptionAppealResolution() {
        let ctx = makeContext()
        let exceptionRepo = CoreDataExceptionCaseRepository(context: ctx)
        let appealRepo = CoreDataAppealRepository(context: ctx)
        let auditLogRepo = CoreDataAuditLogRepository(context: ctx)
        let opLogRepo = CoreDataOperationLogRepository(context: ctx)
        let permScopeRepo = CoreDataPermissionScopeRepository(context: ctx)
        let checkInRepo = CoreDataCheckInRepository(context: ctx)

        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let exceptionService = ExceptionService(exceptionCaseRepo: exceptionRepo, checkInRepo: checkInRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)
        let appealService = AppealService(appealRepo: appealRepo, exceptionCaseRepo: exceptionRepo, permissionService: permService, auditService: auditService, operationLogRepo: opLogRepo)

        let admin = TestHelpers.makeAdmin()
        let sales = TestHelpers.makeSalesAssociate()
        let reviewer = TestHelpers.makeComplianceReviewer()

        // Create scopes for sales and reviewer
        let salesScope = PermissionScope(id: UUID(), userId: sales.id, site: "lot-a", functionKey: "appeals", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! permScopeRepo.save(salesScope)
        let reviewerScope = PermissionScope(id: UUID(), userId: reviewer.id, site: "lot-a", functionKey: "appeals", validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600))
        try! permScopeRepo.save(reviewerScope)

        // 1. Create exception (admin bypasses scope)
        let exception = TestHelpers.assertSuccess(exceptionService.createException(
            by: admin, site: "lot-a", type: .missedCheckIn, sourceId: UUID(), reason: "No check-in at 9 AM", operationId: UUID()))!
        TestHelpers.assert(exception.status == .open)

        // Verify persisted
        TestHelpers.assert(exceptionRepo.findById(exception.id) != nil)

        // 2. Submit appeal
        let appeal = TestHelpers.assertSuccess(appealService.submitAppeal(
            by: sales, site: "lot-a", exceptionId: exception.id, reason: "Was on approved leave", operationId: UUID()))!
        TestHelpers.assert(appeal.status == .submitted)

        // Exception should now be underAppeal
        TestHelpers.assert(exceptionRepo.findById(exception.id)!.status == .underAppeal)

        // 3. Start review
        let reviewed = TestHelpers.assertSuccess(appealService.startReview(by: reviewer, site: "lot-a", appealId: appeal.id, operationId: UUID()))!
        TestHelpers.assert(reviewed.status == .underReview)
        TestHelpers.assert(reviewed.reviewerId == reviewer.id)

        // 4. Approve appeal
        let approved = TestHelpers.assertSuccess(appealService.approveAppeal(by: reviewer, site: "lot-a", appealId: appeal.id, operationId: UUID()))!
        TestHelpers.assert(approved.status == .approved)
        TestHelpers.assert(approved.resolvedAt != nil)

        // Exception should now be resolved
        let resolvedExc = exceptionRepo.findById(exception.id)!
        TestHelpers.assert(resolvedExc.status == .resolved, "Exception must be resolved after appeal approval")

        // 5. Verify audit trail in Core Data
        let logs = auditLogRepo.findAll()
        TestHelpers.assert(logs.contains { $0.action == "appeal_submitted" })
        TestHelpers.assert(logs.contains { $0.action == "appeal_approved" })
        TestHelpers.assert(logs.contains { $0.action == "exception_resolved_via_appeal" })

        print("  PASS: testFullFlowExceptionAppealResolution")
    }
}
