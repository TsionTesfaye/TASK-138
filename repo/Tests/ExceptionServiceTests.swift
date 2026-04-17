import Foundation

/// Tests for ExceptionService: missed check-in, buddy punching detection.
final class ExceptionServiceTests {

    private func makeService() -> (ExceptionService, InMemoryCheckInRepository, InMemoryExceptionCaseRepository, InMemoryPermissionScopeRepository) {
        let exceptionRepo = InMemoryExceptionCaseRepository()
        let checkInRepo = InMemoryCheckInRepository()
        let auditService = AuditService(auditLogRepo: InMemoryAuditLogRepository())
        let permScopeRepo = InMemoryPermissionScopeRepository()
        let permService = PermissionService(permissionScopeRepo: permScopeRepo)
        let opLogRepo = InMemoryOperationLogRepository()

        let service = ExceptionService(
            exceptionCaseRepo: exceptionRepo, checkInRepo: checkInRepo,
            permissionService: permService, auditService: auditService,
            operationLogRepo: opLogRepo
        )
        return (service, checkInRepo, exceptionRepo, permScopeRepo)
    }

    func runAll() {
        print("--- ExceptionServiceTests ---")
        testMissedCheckInDetected()
        testMissedCheckInNotDetectedWithinWindow()
        testBuddyPunchingDetected()
        testBuddyPunchingNotDetectedDifferentLocations()
        testMisidentificationDetected()
        testRecordCheckIn()
        testRecordCheckInByStaff()
        testRecordCheckInNoScopeDenied()
    }

    func testMissedCheckInDetected() {
        let (service, _, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let userId = UUID()
        let expectedTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let now = Date()

        let result = service.detectMissedCheckIns(by: admin, site: "lot-a", userId: userId, expectedTime: expectedTime, now: now)
        let exceptions = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(exceptions.count == 1, "Should detect missed check-in")
        TestHelpers.assert(exceptions[0].type == .missedCheckIn)
        print("  PASS: testMissedCheckInDetected")
    }

    func testMissedCheckInNotDetectedWithinWindow() {
        let (service, checkInRepo, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let userId = UUID()
        let expectedTime = Date().addingTimeInterval(-3600)

        // User checked in 10 minutes after expected time (within 30 min window)
        let checkIn = CheckIn(
            id: UUID(), siteId: "lot-a", userId: userId,
            timestamp: expectedTime.addingTimeInterval(10 * 60),
            locationLat: 37.77, locationLng: -122.41
        )
        try! checkInRepo.save(checkIn)

        let result = service.detectMissedCheckIns(by: admin, site: "lot-a", userId: userId, expectedTime: expectedTime)
        let exceptions = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(exceptions.isEmpty, "Should not flag if check-in within window")
        print("  PASS: testMissedCheckInNotDetectedWithinWindow")
    }

    func testBuddyPunchingDetected() {
        let (service, checkInRepo, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        // Two different users check in at the same location within 30 seconds
        let checkIn1 = CheckIn(id: UUID(), siteId: "lot-a", userId: UUID(), timestamp: now, locationLat: 37.7749, locationLng: -122.4194)
        let checkIn2 = CheckIn(id: UUID(), siteId: "lot-a", userId: UUID(), timestamp: now.addingTimeInterval(10), locationLat: 37.7749, locationLng: -122.4194)
        try! checkInRepo.save(checkIn1)
        try! checkInRepo.save(checkIn2)

        let result = service.detectBuddyPunching(
            by: admin, site: "lot-a", inTimeRange: now.addingTimeInterval(-60), end: now.addingTimeInterval(60)
        )
        let exceptions = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(exceptions.count >= 1, "Should detect buddy punching")
        TestHelpers.assert(exceptions[0].type == .buddyPunching)
        print("  PASS: testBuddyPunchingDetected")
    }

    func testBuddyPunchingNotDetectedDifferentLocations() {
        let (service, checkInRepo, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let now = Date()

        // Two users at different locations (miles apart)
        let checkIn1 = CheckIn(id: UUID(), siteId: "lot-a", userId: UUID(), timestamp: now, locationLat: 37.7749, locationLng: -122.4194)
        let checkIn2 = CheckIn(id: UUID(), siteId: "lot-a", userId: UUID(), timestamp: now.addingTimeInterval(10), locationLat: 37.90, locationLng: -122.10)
        try! checkInRepo.save(checkIn1)
        try! checkInRepo.save(checkIn2)

        let result = service.detectBuddyPunching(
            by: admin, site: "lot-a", inTimeRange: now.addingTimeInterval(-60), end: now.addingTimeInterval(60)
        )
        let exceptions = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(exceptions.isEmpty, "Should not flag different locations")
        print("  PASS: testBuddyPunchingNotDetectedDifferentLocations")
    }

    func testMisidentificationDetected() {
        let (service, checkInRepo, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let userId = UUID()
        let now = Date()

        // Same user checks in at locations 15+ miles apart within 5 minutes
        let checkIn1 = CheckIn(id: UUID(), siteId: "lot-a", userId: userId, timestamp: now, locationLat: 37.7749, locationLng: -122.4194) // SF
        let checkIn2 = CheckIn(id: UUID(), siteId: "lot-a", userId: userId, timestamp: now.addingTimeInterval(5 * 60), locationLat: 37.55, locationLng: -122.05) // ~25 miles away
        try! checkInRepo.save(checkIn1)
        try! checkInRepo.save(checkIn2)

        let result = service.detectMisidentification(
            by: admin, site: "lot-a", userId: userId, inTimeRange: now.addingTimeInterval(-60), end: now.addingTimeInterval(3600)
        )
        let exceptions = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(exceptions.count >= 1, "Should detect misidentification")
        TestHelpers.assert(exceptions[0].type == .misidentification)
        print("  PASS: testMisidentificationDetected")
    }

    func testRecordCheckIn() {
        let (service, checkInRepo, _, _) = makeService()
        let admin = TestHelpers.makeAdmin()
        let result = service.recordCheckIn(by: admin, site: "lot-a", locationLat: 37.77, locationLng: -122.41, operationId: UUID())
        let checkIn = TestHelpers.assertSuccess(result)!
        TestHelpers.assert(checkIn.userId == admin.id)
        TestHelpers.assert(checkInRepo.findAll().count == 1)
        print("  PASS: testRecordCheckIn")
    }

    func testRecordCheckInByStaff() {
        let (service, checkInRepo, _, scopeRepo) = makeService()

        for staff in [TestHelpers.makeSalesAssociate(), TestHelpers.makeInventoryClerk(), TestHelpers.makeComplianceReviewer()] {
            let scope = PermissionScope(
                id: UUID(), userId: staff.id, site: "lot-a", functionKey: "checkin",
                validFrom: Date().addingTimeInterval(-3600), validTo: Date().addingTimeInterval(3600)
            )
            try! scopeRepo.save(scope)
            let result = service.recordCheckIn(by: staff, site: "lot-a", locationLat: 37.77, locationLng: -122.41, operationId: UUID())
            let checkIn = TestHelpers.assertSuccess(result)!
            TestHelpers.assert(checkIn.userId == staff.id, "\(staff.role) should be able to check in")
        }

        TestHelpers.assert(checkInRepo.findAll().count == 3, "All 3 staff roles should have recorded a check-in")
        print("  PASS: testRecordCheckInByStaff")
    }

    func testRecordCheckInNoScopeDenied() {
        let (service, _, _, _) = makeService()
        let staff = TestHelpers.makeSalesAssociate()
        // No "checkin" scope granted
        let result = service.recordCheckIn(by: staff, site: "lot-a", locationLat: 37.77, locationLng: -122.41, operationId: UUID())
        TestHelpers.assertFailure(result, code: "SCOPE_DENIED")
        print("  PASS: testRecordCheckInNoScopeDenied")
    }
}
