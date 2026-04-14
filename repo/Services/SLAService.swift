import Foundation

/// design.md 4.11, 4.16, questions.md Q10, Q11
/// Computes SLA deadlines using business hours. Detects violations.
/// Fires local notifications on first detection of each violation.
final class SLAService {

    private let businessHoursRepo: BusinessHoursConfigRepository
    private let leadRepo: LeadRepository
    private let appointmentRepo: AppointmentRepository
    private let auditService: AuditService

    /// Tracks which violations have already been alerted to prevent duplicate notifications.
    /// Keyed by entity ID — once alerted, the same violation will not re-fire.
    private var alertedLeadViolations: Set<UUID> = []
    private var alertedAppointmentViolations: Set<UUID> = []

    init(
        businessHoursRepo: BusinessHoursConfigRepository,
        leadRepo: LeadRepository,
        appointmentRepo: AppointmentRepository,
        auditService: AuditService
    ) {
        self.businessHoursRepo = businessHoursRepo
        self.leadRepo = leadRepo
        self.appointmentRepo = appointmentRepo
        self.auditService = auditService
    }

    // MARK: - Lead SLA Deadline (2 business hours)

    /// Compute the SLA deadline: 2 business hours from the given date.
    /// Business hours default 9-17, Mon-Fri (from BusinessHoursConfig).
    func computeLeadDeadline(from startDate: Date) -> Date {
        let config = businessHoursRepo.get()
        return addBusinessHours(2, to: startDate, config: config)
    }

    /// Reset SLA by recomputing deadline from the action date.
    func resetLeadSLA(leadId: UUID, actionDate: Date) {
        guard var lead = leadRepo.findById(leadId) else { return }
        lead.slaDeadline = computeLeadDeadline(from: actionDate)
        lead.lastQualifyingAction = actionDate
        do { try leadRepo.save(lead) } catch { ServiceLogger.persistenceError(ServiceLogger.sla, operation: "save_lead_sla", error: error) }
        // Clear any previous alert for this lead so a new violation can be detected
        alertedLeadViolations.remove(leadId)
    }

    // MARK: - Appointment SLA (30 min before start)

    /// Compute the appointment SLA deadline: 30 minutes before startTime.
    func computeAppointmentSLADeadline(appointmentStartTime: Date) -> Date {
        return appointmentStartTime.addingTimeInterval(-30 * 60)
    }

    // MARK: - Violation Detection

    /// Check for SLA violations. Called by BackgroundTaskService.
    /// Returns IDs of leads/appointments in violation.
    /// Fires a local notification exactly once per new violation (deduped by entity ID).
    func checkViolations(now: Date = Date()) -> (leadViolations: [UUID], appointmentViolations: [UUID]) {
        var leadViolations: [UUID] = []
        var appointmentViolations: [UUID] = []

        // Lead SLA: new leads past deadline
        let overdueLeads = leadRepo.findLeadsExceedingSLA(before: now)
        for lead in overdueLeads {
            leadViolations.append(lead.id)
            auditService.log(actorId: UUID(), action: "sla_violation_lead", entityId: lead.id)

            // Fire notification only once per violation
            if !alertedLeadViolations.contains(lead.id) {
                alertedLeadViolations.insert(lead.id)
                NotificationService.shared.scheduleImmediateNotification(
                    identifier: "sla-lead-\(lead.id.uuidString)",
                    title: "Lead SLA Violation",
                    body: "Lead for \(lead.customerName) has exceeded the 2-hour SLA deadline."
                )
            }
        }

        // Appointment SLA: unconfirmed within 30 min of start
        let thirtyMinFromNow = now.addingTimeInterval(30 * 60)
        let unconfirmed = appointmentRepo.findUnconfirmedBefore(thirtyMinFromNow)
        for appt in unconfirmed {
            appointmentViolations.append(appt.id)
            auditService.log(actorId: UUID(), action: "sla_violation_appointment", entityId: appt.id)

            // Fire notification only once per violation
            if !alertedAppointmentViolations.contains(appt.id) {
                alertedAppointmentViolations.insert(appt.id)
                NotificationService.shared.scheduleImmediateNotification(
                    identifier: "sla-appt-\(appt.id.uuidString)",
                    title: "Appointment Not Confirmed",
                    body: "An appointment starting at \(appt.startTime) has not been confirmed."
                )
            }
        }

        return (leadViolations, appointmentViolations)
    }

    // MARK: - Business Hours Calculation

    /// Add business hours to a date, skipping non-working hours and non-working days.
    func addBusinessHours(_ hours: Int, to startDate: Date, config: BusinessHoursConfig) -> Date {
        let calendar = Calendar.current
        var remainingMinutes = hours * 60
        var current = startDate

        while remainingMinutes > 0 {
            let weekday = calendar.component(.weekday, from: current)
            let hour = calendar.component(.hour, from: current)
            let minute = calendar.component(.minute, from: current)
            let currentMinuteOfDay = hour * 60 + minute

            let startMinute = config.startHour * 60
            let endMinute = config.endHour * 60

            // If not a working day, advance to next working day start
            if !config.workingDays.contains(weekday) {
                current = nextWorkingDayStart(from: current, config: config, calendar: calendar)
                continue
            }

            // If before business hours, advance to start of business hours
            if currentMinuteOfDay < startMinute {
                current = calendar.date(bySettingHour: config.startHour, minute: 0, second: 0, of: current)!
                continue
            }

            // If after business hours, advance to next working day start
            if currentMinuteOfDay >= endMinute {
                current = nextWorkingDayStart(from: current, config: config, calendar: calendar)
                continue
            }

            // Within business hours — consume available minutes
            let availableMinutes = endMinute - currentMinuteOfDay
            if remainingMinutes <= availableMinutes {
                current = current.addingTimeInterval(TimeInterval(remainingMinutes * 60))
                remainingMinutes = 0
            } else {
                remainingMinutes -= availableMinutes
                current = nextWorkingDayStart(from: current, config: config, calendar: calendar)
            }
        }

        return current
    }

    private func nextWorkingDayStart(from date: Date, config: BusinessHoursConfig, calendar: Calendar) -> Date {
        var next = calendar.startOfDay(for: date)
        next = calendar.date(byAdding: .day, value: 1, to: next)!

        // Skip to next working day
        var weekday = calendar.component(.weekday, from: next)
        while !config.workingDays.contains(weekday) {
            next = calendar.date(byAdding: .day, value: 1, to: next)!
            weekday = calendar.component(.weekday, from: next)
        }

        return calendar.date(bySettingHour: config.startHour, minute: 0, second: 0, of: next)!
    }
}
