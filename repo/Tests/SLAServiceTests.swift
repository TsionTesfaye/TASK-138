import Foundation

/// Tests for SLAService: business hours, deadline computation, violation detection.
final class SLAServiceTests {

    func runAll() {
        print("--- SLAServiceTests ---")
        testDeadlineDuringBusinessHours()
        testDeadlineSpansOvernight()
        testDeadlineSpansWeekend()
        testAppointmentSLADeadline()
        testViolationDetection()
    }

    func testDeadlineDuringBusinessHours() {
        let (service, _) = makeService()
        let cal = Calendar.current
        // Monday at 10:00 AM → deadline should be 12:00 PM same day
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 6 // Monday
        components.hour = 10
        components.minute = 0
        let start = cal.date(from: components)!

        let deadline = service.computeLeadDeadline(from: start)
        let deadlineHour = cal.component(.hour, from: deadline)
        let deadlineDay = cal.component(.day, from: deadline)
        TestHelpers.assert(deadlineHour == 12, "Deadline should be 12:00, got \(deadlineHour)")
        TestHelpers.assert(deadlineDay == 6, "Should be same day")
        print("  PASS: testDeadlineDuringBusinessHours")
    }

    func testDeadlineSpansOvernight() {
        let (service, _) = makeService()
        let cal = Calendar.current
        // Monday at 4:00 PM (16:00) → 1 hour left in day, need 2 total
        // → Mon 5PM (end) + next business day 9AM + 1 hour = Tue 10:00 AM
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 6 // Monday
        components.hour = 16
        components.minute = 0
        let start = cal.date(from: components)!

        let deadline = service.computeLeadDeadline(from: start)
        let deadlineHour = cal.component(.hour, from: deadline)
        let deadlineDay = cal.component(.day, from: deadline)
        TestHelpers.assert(deadlineDay == 7, "Should be Tuesday, got day \(deadlineDay)")
        TestHelpers.assert(deadlineHour == 10, "Should be 10:00, got \(deadlineHour)")
        print("  PASS: testDeadlineSpansOvernight")
    }

    func testDeadlineSpansWeekend() {
        let (service, _) = makeService()
        let cal = Calendar.current
        // Friday at 4:30 PM → 30 min left, need 2 hours total
        // → Fri 5PM (end) + skip Sat/Sun + Mon 9AM + 1.5 hours = Mon 10:30 AM
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 10 // Friday
        components.hour = 16
        components.minute = 30
        let start = cal.date(from: components)!

        let deadline = service.computeLeadDeadline(from: start)
        let deadlineDay = cal.component(.day, from: deadline)
        let deadlineHour = cal.component(.hour, from: deadline)
        let deadlineMin = cal.component(.minute, from: deadline)
        TestHelpers.assert(deadlineDay == 13, "Should be Monday (13th), got \(deadlineDay)")
        TestHelpers.assert(deadlineHour == 10, "Should be 10:XX, got \(deadlineHour)")
        TestHelpers.assert(deadlineMin == 30, "Should be 10:30, got \(deadlineMin)")
        print("  PASS: testDeadlineSpansWeekend")
    }

    func testAppointmentSLADeadline() {
        let (service, _) = makeService()
        let appointmentTime = Date().addingTimeInterval(3600) // 1 hour from now
        let deadline = service.computeAppointmentSLADeadline(appointmentStartTime: appointmentTime)
        let diff = appointmentTime.timeIntervalSince(deadline)
        TestHelpers.assert(abs(diff - 1800) < 1, "Should be 30 min before start")
        print("  PASS: testAppointmentSLADeadline")
    }

    func testViolationDetection() {
        let leadRepo = InMemoryLeadRepository()
        let apptRepo = InMemoryAppointmentRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let service = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)

        // Create a lead with an expired SLA deadline
        let lead = Lead(
            id: UUID(), siteId: "lot-a", leadType: .quoteRequest, status: .new,
            customerName: "Test", phone: "415-555-0000", vehicleInterest: "",
            preferredContactWindow: "", consentNotes: "", assignedTo: nil,
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date().addingTimeInterval(-7200),
            slaDeadline: Date().addingTimeInterval(-3600), // expired 1 hour ago
            lastQualifyingAction: Date().addingTimeInterval(-7200),
            archivedAt: nil
        )
        try! leadRepo.save(lead)

        // Create unconfirmed appointment starting soon
        let appt = Appointment(
            id: UUID(), siteId: "lot-a", leadId: UUID(),
            startTime: Date().addingTimeInterval(20 * 60), // 20 min from now
            status: .scheduled
        )
        try! apptRepo.save(appt)

        let violations = service.checkViolations()
        TestHelpers.assert(violations.leadViolations.contains(lead.id), "Should detect lead violation")
        TestHelpers.assert(violations.appointmentViolations.contains(appt.id), "Should detect appointment violation")
        print("  PASS: testViolationDetection")
    }

    private func makeService() -> (SLAService, InMemoryBusinessHoursConfigRepository) {
        let bhRepo = InMemoryBusinessHoursConfigRepository()
        let leadRepo = InMemoryLeadRepository()
        let apptRepo = InMemoryAppointmentRepository()
        let auditLogRepo = InMemoryAuditLogRepository()
        let auditService = AuditService(auditLogRepo: auditLogRepo)
        let service = SLAService(businessHoursRepo: bhRepo, leadRepo: leadRepo, appointmentRepo: apptRepo, auditService: auditService)
        return (service, bhRepo)
    }
}
