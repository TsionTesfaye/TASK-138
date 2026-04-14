import Foundation

/// Tests all state machine transitions for all entities.
final class StateMachineTests {

    func runAll() {
        print("--- StateMachineTests ---")
        testLeadTransitions()
        testAppointmentTransitions()
        testPoolOrderTransitions()
        testAppealTransitions()
    }

    func testLeadTransitions() {
        // Valid transitions
        TestHelpers.assert(LeadStatus.new.canTransition(to: .followUp, isAdmin: false))
        TestHelpers.assert(LeadStatus.followUp.canTransition(to: .closedWon, isAdmin: false))
        TestHelpers.assert(LeadStatus.followUp.canTransition(to: .invalid, isAdmin: false))
        TestHelpers.assert(LeadStatus.invalid.canTransition(to: .followUp, isAdmin: true))
        TestHelpers.assert(LeadStatus.closedWon.canTransition(to: .followUp, isAdmin: true))

        // Admin-only: non-admin cannot reopen
        TestHelpers.assert(!LeadStatus.invalid.canTransition(to: .followUp, isAdmin: false))
        TestHelpers.assert(!LeadStatus.closedWon.canTransition(to: .followUp, isAdmin: false))

        // Invalid transitions
        TestHelpers.assert(!LeadStatus.new.canTransition(to: .closedWon, isAdmin: false))
        TestHelpers.assert(!LeadStatus.new.canTransition(to: .invalid, isAdmin: false))
        TestHelpers.assert(!LeadStatus.closedWon.canTransition(to: .invalid, isAdmin: false))
        TestHelpers.assert(!LeadStatus.invalid.canTransition(to: .closedWon, isAdmin: false))
        TestHelpers.assert(!LeadStatus.new.canTransition(to: .new, isAdmin: false))

        // requiresAdmin checks
        TestHelpers.assert(LeadStatus.invalid.requiresAdminForTransition(to: .followUp))
        TestHelpers.assert(LeadStatus.closedWon.requiresAdminForTransition(to: .followUp))
        TestHelpers.assert(!LeadStatus.new.requiresAdminForTransition(to: .followUp))
        print("  PASS: testLeadTransitions")
    }

    func testAppointmentTransitions() {
        TestHelpers.assert(AppointmentStatus.scheduled.canTransition(to: .confirmed))
        TestHelpers.assert(AppointmentStatus.scheduled.canTransition(to: .canceled))
        TestHelpers.assert(AppointmentStatus.scheduled.canTransition(to: .noShow))
        TestHelpers.assert(AppointmentStatus.confirmed.canTransition(to: .completed))
        TestHelpers.assert(AppointmentStatus.confirmed.canTransition(to: .canceled))
        TestHelpers.assert(AppointmentStatus.confirmed.canTransition(to: .noShow))

        // Invalid
        TestHelpers.assert(!AppointmentStatus.completed.canTransition(to: .confirmed))
        TestHelpers.assert(!AppointmentStatus.canceled.canTransition(to: .confirmed))
        TestHelpers.assert(!AppointmentStatus.noShow.canTransition(to: .completed))
        TestHelpers.assert(!AppointmentStatus.scheduled.canTransition(to: .completed))
        print("  PASS: testAppointmentTransitions")
    }

    func testPoolOrderTransitions() {
        TestHelpers.assert(PoolOrderStatus.draft.canTransition(to: .active))
        TestHelpers.assert(PoolOrderStatus.active.canTransition(to: .matched))
        TestHelpers.assert(PoolOrderStatus.matched.canTransition(to: .completed))
        TestHelpers.assert(PoolOrderStatus.active.canTransition(to: .canceled))
        TestHelpers.assert(PoolOrderStatus.active.canTransition(to: .expired))
        TestHelpers.assert(PoolOrderStatus.draft.canTransition(to: .expired)) // any → expired

        // Invalid
        TestHelpers.assert(!PoolOrderStatus.draft.canTransition(to: .matched))
        TestHelpers.assert(!PoolOrderStatus.draft.canTransition(to: .completed))
        TestHelpers.assert(!PoolOrderStatus.completed.canTransition(to: .active))
        TestHelpers.assert(!PoolOrderStatus.canceled.canTransition(to: .active))
        print("  PASS: testPoolOrderTransitions")
    }

    func testAppealTransitions() {
        TestHelpers.assert(AppealStatus.submitted.canTransition(to: .underReview))
        TestHelpers.assert(AppealStatus.underReview.canTransition(to: .approved))
        TestHelpers.assert(AppealStatus.underReview.canTransition(to: .denied))
        TestHelpers.assert(AppealStatus.approved.canTransition(to: .archived))
        TestHelpers.assert(AppealStatus.denied.canTransition(to: .archived))

        // Invalid
        TestHelpers.assert(!AppealStatus.submitted.canTransition(to: .approved))
        TestHelpers.assert(!AppealStatus.submitted.canTransition(to: .denied))
        TestHelpers.assert(!AppealStatus.submitted.canTransition(to: .archived))
        TestHelpers.assert(!AppealStatus.underReview.canTransition(to: .archived))
        TestHelpers.assert(!AppealStatus.archived.canTransition(to: .submitted))
        print("  PASS: testAppealTransitions")
    }
}
