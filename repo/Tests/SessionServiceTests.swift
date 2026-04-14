import Foundation

/// Tests for SessionService: session start, timeout, re-auth.
final class SessionServiceTests {

    func runAll() {
        print("--- SessionServiceTests ---")
        testSessionStartValid()
        testSessionExpiresAfter5Minutes()
        testSessionValidWithinWindow()
        testRecordActivityExtends()
        testEndSessionClearsState()
        testNoSessionRequiresReAuth()
    }

    func testSessionStartValid() {
        let service = SessionService()
        let user = TestHelpers.makeAdmin()
        service.startSession(user: user)
        TestHelpers.assert(service.isSessionValid(), "Session should be valid immediately")
        print("  PASS: testSessionStartValid")
    }

    func testSessionExpiresAfter5Minutes() {
        let service = SessionService()
        let user = TestHelpers.makeAdmin()
        let startTime = Date()
        service.now = { startTime }
        service.startSession(user: user)

        // Simulate 6 minutes later
        service.now = { startTime.addingTimeInterval(6 * 60) }
        TestHelpers.assert(!service.isSessionValid(), "Session should be expired after 6 min")
        TestHelpers.assert(service.requiresReAuthentication(), "Should require re-auth")
        print("  PASS: testSessionExpiresAfter5Minutes")
    }

    func testSessionValidWithinWindow() {
        let service = SessionService()
        let user = TestHelpers.makeAdmin()
        let startTime = Date()
        service.now = { startTime }
        service.startSession(user: user)

        // 4 minutes later — still valid
        service.now = { startTime.addingTimeInterval(4 * 60) }
        TestHelpers.assert(service.isSessionValid(), "Session should be valid at 4 min")
        print("  PASS: testSessionValidWithinWindow")
    }

    func testRecordActivityExtends() {
        let service = SessionService()
        let user = TestHelpers.makeAdmin()
        let startTime = Date()
        service.now = { startTime }
        service.startSession(user: user)

        // 4 minutes later, record activity
        let activityTime = startTime.addingTimeInterval(4 * 60)
        service.now = { activityTime }
        service.recordActivity()

        // 4 more minutes (8 total from start, 4 from last activity) — should still be valid
        service.now = { activityTime.addingTimeInterval(4 * 60) }
        TestHelpers.assert(service.isSessionValid(), "Should be valid after activity extends window")
        print("  PASS: testRecordActivityExtends")
    }

    func testEndSessionClearsState() {
        let service = SessionService()
        service.startSession(user: TestHelpers.makeAdmin())
        service.endSession()
        TestHelpers.assert(service.currentUser == nil, "User should be nil")
        TestHelpers.assert(!service.isSessionValid(), "Session should be invalid")
        print("  PASS: testEndSessionClearsState")
    }

    func testNoSessionRequiresReAuth() {
        let service = SessionService()
        TestHelpers.assert(service.requiresReAuthentication(), "No session should require re-auth")
        print("  PASS: testNoSessionRequiresReAuth")
    }
}
