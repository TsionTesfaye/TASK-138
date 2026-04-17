import Foundation

/// Tests for AuditService: append-only, tombstone, retention.
final class AuditServiceTests {

    func runAll() {
        print("--- AuditServiceTests ---")
        testLogCreatesEntry()
        testLogIsAppendOnly()
        testTombstoneDoesNotRemove()
        testTombstoneMarksFields()
        testPurgeOldTombstones()
        testPurgeRespects1YearRetention()
        testQueryByEntity()
        testQueryExcludesTombstones()
        testAllLogsRequiresPrivilegedRole()
        testLogsForEntityRequiresPrivilegedRole()
        testLogsForActorRequiresPrivilegedRole()
        testComplianceReviewerCanReadLogs()
    }

    func testLogCreatesEntry() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        service.log(actorId: UUID(), action: "test_action", entityId: UUID())
        TestHelpers.assert(repo.findAll().count == 1)
        print("  PASS: testLogCreatesEntry")
    }

    func testLogIsAppendOnly() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        service.log(actorId: UUID(), action: "action1", entityId: UUID())
        service.log(actorId: UUID(), action: "action2", entityId: UUID())
        service.log(actorId: UUID(), action: "action3", entityId: UUID())
        TestHelpers.assert(repo.findAll().count == 3, "Should have 3 entries")
        print("  PASS: testLogIsAppendOnly")
    }

    func testTombstoneDoesNotRemove() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        let entityId = UUID()
        service.log(actorId: UUID(), action: "original", entityId: entityId)
        let logEntry = repo.findAll().first { $0.action == "original" }!

        let admin = TestHelpers.makeAdmin()
        _ = service.deleteLog(by: admin, logId: logEntry.id)

        // Entry should still exist but be tombstoned
        let all = repo.findAll()
        TestHelpers.assert(all.contains { $0.id == logEntry.id }, "Entry should still exist")
        let updated = repo.findById(logEntry.id)!
        TestHelpers.assert(updated.tombstone, "Should be tombstoned")
        print("  PASS: testTombstoneDoesNotRemove")
    }

    func testTombstoneMarksFields() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        service.log(actorId: UUID(), action: "original", entityId: UUID())
        let logEntry = repo.findAll().first!
        let admin = TestHelpers.makeAdmin()
        _ = service.deleteLog(by: admin, logId: logEntry.id)

        let updated = repo.findById(logEntry.id)!
        TestHelpers.assert(updated.tombstone)
        TestHelpers.assert(updated.deletedAt != nil)
        TestHelpers.assert(updated.deletedBy == admin.id)
        print("  PASS: testTombstoneMarksFields")
    }

    func testPurgeOldTombstones() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)

        // Create and tombstone an old entry
        let oldEntry = AuditLog(
            id: UUID(), actorId: UUID(), action: "old", entityId: UUID(),
            timestamp: Date().addingTimeInterval(-400 * 86400), // 400 days ago
            tombstone: true,
            deletedAt: Date().addingTimeInterval(-400 * 86400),
            deletedBy: UUID()
        )
        try! repo.save(oldEntry)

        let cutoff = Date().addingTimeInterval(-365 * 86400) // 1 year ago
        let purged = service.purgeOldTombstones(olderThan: cutoff)
        TestHelpers.assert(purged == 1, "Should purge 1 old tombstone")
        print("  PASS: testPurgeOldTombstones")
    }

    func testPurgeRespects1YearRetention() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)

        // Recent tombstone (6 months old)
        let recentEntry = AuditLog(
            id: UUID(), actorId: UUID(), action: "recent", entityId: UUID(),
            timestamp: Date().addingTimeInterval(-180 * 86400),
            tombstone: true,
            deletedAt: Date().addingTimeInterval(-180 * 86400),
            deletedBy: UUID()
        )
        try! repo.save(recentEntry)

        let cutoff = Date().addingTimeInterval(-365 * 86400)
        let purged = service.purgeOldTombstones(olderThan: cutoff)
        TestHelpers.assert(purged == 0, "Should not purge recent tombstones")
        print("  PASS: testPurgeRespects1YearRetention")
    }

    func testQueryByEntity() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        let admin = TestHelpers.makeAdmin()
        let entityId = UUID()
        service.log(actorId: UUID(), action: "action1", entityId: entityId)
        service.log(actorId: UUID(), action: "action2", entityId: entityId)
        service.log(actorId: UUID(), action: "action3", entityId: UUID()) // different entity

        let logs = TestHelpers.assertSuccess(service.logsForEntity(by: admin, entityId))!
        TestHelpers.assert(logs.count == 2, "Should find 2 logs for entity")
        print("  PASS: testQueryByEntity")
    }

    func testQueryExcludesTombstones() {
        let repo = InMemoryAuditLogRepository()
        let service = AuditService(auditLogRepo: repo)
        let admin = TestHelpers.makeAdmin()
        let entityId = UUID()
        service.log(actorId: UUID(), action: "visible", entityId: entityId)
        service.log(actorId: UUID(), action: "hidden", entityId: entityId)

        let hidden = repo.findAll().first { $0.action == "hidden" }!
        _ = service.deleteLog(by: admin, logId: hidden.id)

        let logs = TestHelpers.assertSuccess(service.logsForEntity(by: admin, entityId))!
        TestHelpers.assert(logs.count == 1, "Should exclude tombstoned entries")
        TestHelpers.assert(logs[0].action == "visible")
        print("  PASS: testQueryExcludesTombstones")
    }

    func testAllLogsRequiresPrivilegedRole() {
        let service = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        service.log(actorId: UUID(), action: "action", entityId: UUID())
        let staff = TestHelpers.makeSalesAssociate()
        TestHelpers.assertFailure(service.allLogs(by: staff), code: "PERM_DENIED")
        let clerk = TestHelpers.makeInventoryClerk()
        TestHelpers.assertFailure(service.allLogs(by: clerk), code: "PERM_DENIED")
        print("  PASS: testAllLogsRequiresPrivilegedRole")
    }

    func testLogsForEntityRequiresPrivilegedRole() {
        let service = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let entityId = UUID()
        service.log(actorId: UUID(), action: "action", entityId: entityId)
        let staff = TestHelpers.makeSalesAssociate()
        TestHelpers.assertFailure(service.logsForEntity(by: staff, entityId), code: "PERM_DENIED")
        print("  PASS: testLogsForEntityRequiresPrivilegedRole")
    }

    func testLogsForActorRequiresPrivilegedRole() {
        let service = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let actorId = UUID()
        service.log(actorId: actorId, action: "action", entityId: UUID())
        let staff = TestHelpers.makeSalesAssociate()
        TestHelpers.assertFailure(service.logsForActor(by: staff, actorId), code: "PERM_DENIED")
        print("  PASS: testLogsForActorRequiresPrivilegedRole")
    }

    func testComplianceReviewerCanReadLogs() {
        let service = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        service.log(actorId: UUID(), action: "action", entityId: UUID())
        let reviewer = TestHelpers.makeComplianceReviewer()
        let logs = TestHelpers.assertSuccess(service.allLogs(by: reviewer))!
        TestHelpers.assert(logs.count == 1, "Compliance reviewer should read audit logs")
        print("  PASS: testComplianceReviewerCanReadLogs")
    }
}
