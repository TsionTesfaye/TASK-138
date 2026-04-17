import Foundation

/// Runs all test suites.
struct TestRunner {
    static func runAll() {
        print("=== DealerOps Test Suite ===\n")

        AuthServiceTests().runAll()
        print()
        SessionServiceTests().runAll()
        print()
        PermissionServiceTests().runAll()
        print()
        UserManagementServiceTests().runAll()
        print()
        LeadServiceTests().runAll()
        print()
        AppointmentServiceTests().runAll()
        print()
        NoteServiceTests().runAll()
        print()
        ReminderServiceTests().runAll()
        print()
        SLAServiceTests().runAll()
        print()
        InventoryServiceTests().runAll()
        print()
        CarpoolServiceTests().runAll()
        print()
        ExceptionServiceTests().runAll()
        print()
        AppealServiceTests().runAll()
        print()
        AuditServiceTests().runAll()
        print()
        StateMachineTests().runAll()
        print()
        #if canImport(CoreData)
        CoreDataIntegrationTests().runAll()
        print()
        #endif
        EncryptionTests().runAll()
        print()
        FileServiceTests().runAll()
        print()
        BackgroundTaskServiceTests().runAll()
        print()
        DebugSeederTests().runAll()
        print()
        ServiceContainerTests().runAll()
        print()
        #if canImport(CoreData)
        ViewModelTests().runAll()
        print()
        UIFlowTests().runAll()
        print()
        NegativeUITests().runAll()
        print()
        UIStateTransitionTests().runAll()
        print()
        #endif

        print("=== All \(TestHelpers.failureCount == 0 ? "Tests Passed" : "\(TestHelpers.failureCount) FAILURES") ===")
    }
}

// To run: call TestRunner.runAll() from an @main entry point or playground
