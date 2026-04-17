import Foundation

/// Manages appointments with state machine and SLA alerts.
final class AppointmentService {

    private let appointmentRepo: AppointmentRepository
    private let leadRepo: LeadRepository
    private let permissionService: PermissionService
    private let slaService: SLAService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        appointmentRepo: AppointmentRepository,
        leadRepo: LeadRepository,
        permissionService: PermissionService,
        slaService: SLAService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.appointmentRepo = appointmentRepo
        self.leadRepo = leadRepo
        self.permissionService = permissionService
        self.slaService = slaService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Create Appointment

    func createAppointment(
        by user: User,
        site: String,
        leadId: UUID,
        startTime: Date,
        operationId: UUID
    ) -> ServiceResult<Appointment> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        // Verify lead exists, enforce site isolation and ownership
        guard let lead = leadRepo.findById(leadId) else {
            return .failure(.entityNotFound)
        }
        guard lead.siteId == site else { return .failure(.permissionDenied) }
        if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
            return .failure(err)
        }

        let appointment = Appointment(
            id: UUID(),
            siteId: site,
            leadId: leadId,
            startTime: startTime,
            status: .scheduled
        )

        do {
            try appointmentRepo.save(appointment)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "appointment_created", entityId: appointment.id)
            return .success(appointment)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Update Status (State Machine)

    func updateStatus(
        by user: User,
        site: String,
        appointmentId: UUID,
        newStatus: AppointmentStatus,
        operationId: UUID
    ) -> ServiceResult<Appointment> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard var appointment = appointmentRepo.findById(appointmentId) else {
            return .failure(.entityNotFound)
        }
        guard appointment.siteId == site else { return .failure(.permissionDenied) }

        // Object-level: verify ownership of parent lead
        if let lead = leadRepo.findById(appointment.leadId) {
            if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
                return .failure(err)
            }
        }

        // State machine validation
        guard appointment.status.canTransition(to: newStatus) else {
            return .failure(.invalidTransition)
        }

        let oldStatus = appointment.status
        appointment.status = newStatus

        do {
            try appointmentRepo.save(appointment)
            try operationLogRepo.save(operationId)
            auditService.log(
                actorId: user.id,
                action: "appointment_status_\(oldStatus.rawValue)_to_\(newStatus.rawValue)",
                entityId: appointmentId
            )
            return .success(appointment)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - SLA Query

    /// Get appointments that are unconfirmed and within 30 min of start.
    func getUnconfirmedWithinSLA(by user: User, site: String, now: Date = Date()) -> ServiceResult<[Appointment]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        let thirtyMinFromNow = now.addingTimeInterval(30 * 60)
        let all = appointmentRepo.findUnconfirmedBefore(thirtyMinFromNow)
            .filter { $0.siteId == site }
        // Apply ownership filtering: non-admin/non-reviewer see only their leads' appointments
        let filtered = filterAppointmentsByLeadOwnership(all, user: user)
        return .success(filtered)
    }

    /// System-initiated SLA check (used by BackgroundTaskService / SLAService).
    /// No authorization — background tasks have no user context.
    func getUnconfirmedWithinSLAForSystem(now: Date = Date()) -> [Appointment] {
        let thirtyMinFromNow = now.addingTimeInterval(30 * 60)
        return appointmentRepo.findUnconfirmedBefore(thirtyMinFromNow)
    }

    // MARK: - Query

    func findById(by user: User, site: String, _ id: UUID) -> ServiceResult<Appointment?> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        guard let appointment = appointmentRepo.findById(id) else {
            return .success(nil)
        }
        guard appointment.siteId == site else { return .failure(.permissionDenied) }
        // Object-level: verify ownership of parent lead
        if let lead = leadRepo.findById(appointment.leadId) {
            if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
                return .failure(err)
            }
        }
        return .success(appointment)
    }

    func findByLeadId(by user: User, site: String, _ leadId: UUID) -> ServiceResult<[Appointment]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        // Object-level: verify ownership of parent lead before returning its appointments
        if let lead = leadRepo.findById(leadId) {
            guard lead.siteId == site else { return .failure(.permissionDenied) }
            if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
                return .failure(err)
            }
        }
        return .success(appointmentRepo.findByLeadId(leadId).filter { $0.siteId == site })
    }

    // MARK: - Object-Level Ownership

    /// Filter a list of appointments by parent lead ownership.
    /// Admins/reviewers see all; others see only appointments whose parent lead
    /// is assigned to them or unassigned.
    private func filterAppointmentsByLeadOwnership(_ appointments: [Appointment], user: User) -> [Appointment] {
        switch user.role {
        case .administrator, .complianceReviewer:
            return appointments
        default:
            return appointments.filter { appt in
                guard let lead = leadRepo.findById(appt.leadId) else { return false }
                return lead.assignedTo == nil || lead.assignedTo == user.id
            }
        }
    }

    /// Admins and compliance reviewers pass unconditionally.
    /// Other roles must own the lead (assignedTo == user.id) or lead must be unassigned.
    private func enforceLeadOwnership(_ lead: Lead, user: User) -> ServiceResult<Void> {
        switch user.role {
        case .administrator, .complianceReviewer:
            return .success(())
        default:
            guard lead.assignedTo == nil || lead.assignedTo == user.id else {
                return .failure(.permissionDenied)
            }
            return .success(())
        }
    }
}
