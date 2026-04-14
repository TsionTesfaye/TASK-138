import Foundation

/// design.md 4.2, 4.13 (Lead State Machine), questions.md Q8, Q9, Q11
/// Manages lead lifecycle, SLA tracking, and archiving.
final class LeadService {

    private let leadRepo: LeadRepository
    private let permissionService: PermissionService
    private let slaService: SLAService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository
    private let reminderRepo: ReminderRepository

    init(
        leadRepo: LeadRepository,
        permissionService: PermissionService,
        slaService: SLAService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository,
        reminderRepo: ReminderRepository
    ) {
        self.leadRepo = leadRepo
        self.permissionService = permissionService
        self.slaService = slaService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
        self.reminderRepo = reminderRepo
    }

    // MARK: - Create Lead

    struct CreateLeadInput {
        let leadType: LeadType
        let customerName: String
        let phone: String
        let vehicleInterest: String
        let preferredContactWindow: String
        let consentNotes: String
    }

    func createLead(by user: User, site: String, input: CreateLeadInput, operationId: UUID) -> ServiceResult<Lead> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        // Input validation
        guard !input.customerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.validationFailed("customerName", "required"))
        }
        guard !input.phone.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.validationFailed("phone", "required"))
        }
        let normalizedPhone = LeadService.normalizePhone(input.phone)
        guard LeadService.isValidPhone(normalizedPhone) else {
            return .failure(.validationFailed("phone", "must be format XXX-XXX-XXXX"))
        }

        let now = Date()
        let slaDeadline = slaService.computeLeadDeadline(from: now)

        let lead = Lead(
            id: UUID(),
            siteId: site,
            leadType: input.leadType,
            status: .new,
            customerName: input.customerName,
            phone: normalizedPhone,
            vehicleInterest: input.vehicleInterest,
            preferredContactWindow: input.preferredContactWindow,
            consentNotes: input.consentNotes,
            assignedTo: nil,
            createdAt: now,
            updatedAt: now,
            slaDeadline: slaDeadline,
            lastQualifyingAction: now,
            archivedAt: nil
        )

        do {
            try leadRepo.save(lead)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "lead_created", entityId: lead.id)
            return .success(lead)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Update Status (State Machine from design.md 4.13)

    func updateLeadStatus(
        by user: User,
        site: String,
        leadId: UUID,
        newStatus: LeadStatus,
        operationId: UUID
    ) -> ServiceResult<Lead> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard var lead = leadRepo.findById(leadId) else {
            return .failure(.entityNotFound)
        }
        guard lead.siteId == site else { return .failure(.permissionDenied) }

        // Object-level: non-admin/non-reviewer can only mutate leads assigned to them or unassigned
        if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
            return .failure(err)
        }

        // State machine validation
        let isAdmin = user.role == .administrator
        guard lead.status.canTransition(to: newStatus, isAdmin: isAdmin) else {
            return .failure(.invalidTransition)
        }

        // Admin-only transitions require explicit admin check
        if lead.status.requiresAdminForTransition(to: newStatus) {
            if case .failure(let err) = permissionService.requireAdmin(user: user) {
                return .failure(err)
            }
        }

        let oldStatus = lead.status
        lead.status = newStatus
        lead.updatedAt = Date()

        // SLA qualifying action: status change resets SLA
        let now = Date()
        lead.lastQualifyingAction = now
        lead.slaDeadline = slaService.computeLeadDeadline(from: now)

        do {
            try leadRepo.save(lead)
            try operationLogRepo.save(operationId)
            auditService.log(
                actorId: user.id,
                action: "lead_status_\(oldStatus.rawValue)_to_\(newStatus.rawValue)",
                entityId: leadId
            )
            return .success(lead)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Assign Lead (SLA qualifying action)

    func assignLead(
        by user: User,
        site: String,
        leadId: UUID,
        assigneeId: UUID,
        operationId: UUID
    ) -> ServiceResult<Lead> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard var lead = leadRepo.findById(leadId) else {
            return .failure(.entityNotFound)
        }
        guard lead.siteId == site else { return .failure(.permissionDenied) }

        // Object-level: non-admin/non-reviewer can only assign leads they own or unassigned leads
        if case .failure(let err) = enforceLeadOwnership(lead, user: user) {
            return .failure(err)
        }

        lead.assignedTo = assigneeId
        lead.updatedAt = Date()

        // Assignment is a qualifying SLA action
        let now = Date()
        lead.lastQualifyingAction = now
        lead.slaDeadline = slaService.computeLeadDeadline(from: now)

        do {
            try leadRepo.save(lead)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "lead_assigned", entityId: leadId)
            return .success(lead)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Archive Closed Leads (180-day rule)

    /// design.md: closed leads archived after 180 days
    /// System-initiated batch operation.
    func archiveClosedLeads(olderThan date: Date) -> Int {
        let leads = leadRepo.findClosedLeadsOlderThan(date)
        var archived = 0
        for var lead in leads {
            lead.archivedAt = Date()
            do { try leadRepo.save(lead) } catch { ServiceLogger.persistenceError(ServiceLogger.leads, operation: "save_lead_archive", error: error) }

            // Cancel pending reminders for archived leads
            let pendingReminders = reminderRepo.findPendingByEntity(entityId: lead.id, entityType: "Lead")
            for var reminder in pendingReminders {
                reminder.status = .canceled
                do { try reminderRepo.save(reminder) } catch { ServiceLogger.persistenceError(ServiceLogger.leads, operation: "save_reminder_cancel", error: error) }
            }

            auditService.log(actorId: UUID(), action: "lead_archived", entityId: lead.id)
            archived += 1
        }
        return archived
    }

    // MARK: - Query

    func findById(by user: User, site: String, _ id: UUID) -> ServiceResult<Lead?> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        guard let lead = leadRepo.findById(id) else {
            return .success(nil)
        }
        guard lead.siteId == site else { return .failure(.permissionDenied) }
        // Object-level isolation: non-admin/non-reviewer users can only see
        // leads assigned to them or unassigned leads (consistent with findByStatus)
        switch user.role {
        case .administrator, .complianceReviewer:
            return .success(lead)
        default:
            guard lead.assignedTo == nil || lead.assignedTo == user.id else {
                return .failure(.permissionDenied)
            }
            return .success(lead)
        }
    }

    func findByStatus(by user: User, site: String, _ status: LeadStatus) -> ServiceResult<[Lead]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        let all = leadRepo.findByStatus(status).filter { $0.siteId == site }
        return .success(filterLeadsByUser(all, user: user))
    }

    func findByAssignedTo(by user: User, site: String, _ userId: UUID) -> ServiceResult<[Lead]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        return .success(leadRepo.findByAssignedTo(userId).filter { $0.siteId == site })
    }

    func findAllNonArchived(by user: User, site: String) -> ServiceResult<[Lead]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        let all = leadRepo.findAll().filter { $0.siteId == site && $0.archivedAt == nil }
        return .success(filterLeadsByUser(all, user: user))
    }

    /// Object-level ownership check for lead mutations and reads.
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

    /// Admins and compliance reviewers see all leads. Sales associates see only
    /// leads assigned to them or unassigned leads.
    private func filterLeadsByUser(_ leads: [Lead], user: User) -> [Lead] {
        switch user.role {
        case .administrator, .complianceReviewer:
            return leads
        default:
            return leads.filter { $0.assignedTo == nil || $0.assignedTo == user.id }
        }
    }

    /// Normalize a phone input to XXX-XXX-XXXX format.
    /// Strips all non-digit characters then formats as 3-3-4.
    static func normalizePhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count == 10 else { return phone.trimmingCharacters(in: .whitespaces) }
        let d = Array(digits)
        return "\(String(d[0..<3]))-\(String(d[3..<6]))-\(String(d[6..<10]))"
    }

    /// Validate phone is in XXX-XXX-XXXX format (exactly 10 digits).
    static func isValidPhone(_ phone: String) -> Bool {
        let digits = phone.filter { $0.isNumber }
        return digits.count == 10
    }

    /// Mask phone number for list views: ***-***-0123
    static func maskPhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 4 else { return "***-***-****" }
        let lastFour = String(digits.suffix(4))
        return "***-***-\(lastFour)"
    }
}
