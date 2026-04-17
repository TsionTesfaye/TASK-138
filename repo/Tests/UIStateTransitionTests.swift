#if canImport(CoreData)
import Foundation

final class UIStateTransitionTests {

    private let testSite = "lot-a"

    func runAll() {
        print("--- UIStateTransitionTests ---")
        testLeadViewModelInitialState()
        testLeadViewModelLoadingThenEmptyState()
        testLeadViewModelLoadingThenLoadedState()
        testLeadViewModelErrorState()
        testLeadViewModelErrorMessageContainsCode()
        testInventoryViewModelInitialState()
        testInventoryViewModelEmptyStateOnLoad()
        testInventoryViewModelLoadedState()
        testDashboardViewModelTransitionsToLoaded()
        testBaseViewModelStateCallbackFires()
        testLeadViewModelStateAfterCreateSuccess()
        testLoadLeadDetailTransitionsToLoaded()
        testLoadLeadDetailTransitionsToErrorForUnknown()
    }

    func testLeadViewModelInitialState() {
        let container = ServiceContainer(inMemory: true)
        let vm = LeadViewModel(container: container)
        TestHelpers.assert(vm.state == .idle, "Initial state should be .idle")
        print("  PASS: testLeadViewModelInitialState")
    }

    func testLeadViewModelLoadingThenEmptyState() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        var capturedStates: [BaseViewModel.ViewState] = []
        vm.onStateChange = { capturedStates.append($0) }

        vm.loadLeads()

        TestHelpers.assert(vm.state == .empty("No leads found"), "State should be .empty after load with no leads")

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        TestHelpers.assert(capturedStates.contains(.loading), "loading state was never emitted")
        TestHelpers.assert(capturedStates.contains(.empty("No leads found")), "empty state was never emitted")

        let loadingIndex = capturedStates.firstIndex(of: .loading)!
        let emptyIndex = capturedStates.firstIndex(of: .empty("No leads found"))!
        TestHelpers.assert(loadingIndex < emptyIndex, ".loading must precede .empty in state sequence")
        print("  PASS: testLeadViewModelLoadingThenEmptyState")
    }

    func testLeadViewModelLoadingThenLoadedState() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let lead = Lead(
            id: UUID(), siteId: testSite, leadType: .quoteRequest, status: .new,
            customerName: "Test Customer", phone: "415-555-0010", vehicleInterest: "Sedan",
            preferredContactWindow: "Morning", consentNotes: "OK", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! container.leadRepo.save(lead)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        var capturedStates: [BaseViewModel.ViewState] = []
        vm.onStateChange = { capturedStates.append($0) }

        vm.loadLeads()

        TestHelpers.assert(vm.state == .loaded, "State should be .loaded after loading with leads present")

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        TestHelpers.assert(capturedStates.contains(.loading), "loading state was never emitted")
        TestHelpers.assert(capturedStates.contains(.loaded), "loaded state was never emitted")

        let loadingIndex = capturedStates.firstIndex(of: .loading)!
        let loadedIndex = capturedStates.firstIndex(of: .loaded)!
        TestHelpers.assert(loadingIndex < loadedIndex, ".loading must precede .loaded in state sequence")
        print("  PASS: testLeadViewModelLoadingThenLoadedState")
    }

    func testLeadViewModelErrorState() {
        let container = ServiceContainer(inMemory: true)
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeads()

        if case .error(_) = vm.state {
            // expected
        } else {
            TestHelpers.assert(false, "Expected .error state for sales associate with no scope, got \(vm.state)")
        }
        print("  PASS: testLeadViewModelErrorState")
    }

    func testLeadViewModelErrorMessageContainsCode() {
        let container = ServiceContainer(inMemory: true)
        let sales = TestHelpers.makeSalesAssociate()
        try! container.userRepo.save(sales)
        container.sessionService.startSession(user: sales)

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeads()

        if case .error(let msg) = vm.state {
            TestHelpers.assert(!msg.isEmpty, "Error message should not be empty")
        } else {
            TestHelpers.assert(false, "Expected .error state, got \(vm.state)")
        }
        print("  PASS: testLeadViewModelErrorMessageContainsCode")
    }

    func testInventoryViewModelInitialState() {
        let container = ServiceContainer(inMemory: true)
        let vm = InventoryViewModel(container: container)
        TestHelpers.assert(vm.state == .idle, "Initial state should be .idle")
        print("  PASS: testInventoryViewModelInitialState")
    }

    func testInventoryViewModelEmptyStateOnLoad() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = InventoryViewModel(container: container)
        vm.site = testSite
        vm.loadTasks()

        TestHelpers.assert(vm.state == .empty("No count tasks"), "State should be .empty when no tasks exist")
        print("  PASS: testInventoryViewModelEmptyStateOnLoad")
    }

    func testInventoryViewModelLoadedState() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let task = CountTask(id: UUID(), siteId: testSite, assignedTo: admin.id, status: .pending)
        try! container.countTaskRepo.save(task)

        let vm = InventoryViewModel(container: container)
        vm.site = testSite
        vm.loadTasks()

        TestHelpers.assert(vm.state == .loaded, "State should be .loaded when tasks exist")
        TestHelpers.assert(vm.tasks.count == 1, "Should have exactly 1 task")
        print("  PASS: testInventoryViewModelLoadedState")
    }

    func testDashboardViewModelTransitionsToLoaded() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = DashboardViewModel(container: container)
        vm.site = testSite
        vm.load()

        TestHelpers.assert(vm.state == .loaded, "Dashboard state should be .loaded after load()")
        TestHelpers.assert(vm.data != nil, "Dashboard data should not be nil after load()")
        print("  PASS: testDashboardViewModelTransitionsToLoaded")
    }

    func testBaseViewModelStateCallbackFires() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        var lastCallbackState: BaseViewModel.ViewState? = nil
        vm.onStateChange = { lastCallbackState = $0 }

        vm.loadLeads()

        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        TestHelpers.assert(lastCallbackState != nil, "onStateChange callback should have fired")
        TestHelpers.assert(lastCallbackState == vm.state, "Callback state should match current vm.state")
        print("  PASS: testBaseViewModelStateCallbackFires")
    }

    func testLeadViewModelStateAfterCreateSuccess() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = LeadViewModel(container: container)
        vm.site = testSite

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Create Test",
            phone: "415-555-0020",
            vehicleInterest: "Truck",
            preferredContactWindow: "Afternoon",
            consentNotes: "Agreed"
        )
        let result = vm.createLead(input: input)
        _ = TestHelpers.assertSuccess(result)

        if case .error(_) = vm.state {
            TestHelpers.assert(false, "vm.state must not be error after successful createLead")
        }
        print("  PASS: testLeadViewModelStateAfterCreateSuccess")
    }

    func testLoadLeadDetailTransitionsToLoaded() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let lead = Lead(
            id: UUID(), siteId: testSite, leadType: .appointment, status: .new,
            customerName: "Detail Test", phone: "415-555-0030", vehicleInterest: "SUV",
            preferredContactWindow: "Morning", consentNotes: "OK", assignedTo: nil,
            createdAt: Date(), updatedAt: Date(), slaDeadline: nil,
            lastQualifyingAction: nil, archivedAt: nil
        )
        try! container.leadRepo.save(lead)

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeadDetail(id: lead.id)

        TestHelpers.assert(vm.state == .loaded, "State should be .loaded after successful loadLeadDetail")
        TestHelpers.assert(vm.selectedLead != nil, "selectedLead should not be nil after loadLeadDetail")
        print("  PASS: testLoadLeadDetailTransitionsToLoaded")
    }

    func testLoadLeadDetailTransitionsToErrorForUnknown() {
        let container = ServiceContainer(inMemory: true)
        let admin = TestHelpers.makeAdmin()
        try! container.userRepo.save(admin)
        container.sessionService.startSession(user: admin)

        let vm = LeadViewModel(container: container)
        vm.site = testSite
        vm.loadLeadDetail(id: UUID())

        if case .error(let msg) = vm.state {
            TestHelpers.assert(msg == "Lead not found", "Error message should be 'Lead not found', got '\(msg)'")
        } else {
            TestHelpers.assert(false, "Expected .error state for unknown lead id, got \(vm.state)")
        }
        print("  PASS: testLoadLeadDetailTransitionsToErrorForUnknown")
    }
}
#endif
