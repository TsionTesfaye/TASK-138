import Foundation

/// Manages reminders with state-driven lifecycle.
final class ReminderService {

    private let reminderRepo: ReminderRepository
    private let leadRepo: LeadRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        reminderRepo: ReminderRepository,
        leadRepo: LeadRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.reminderRepo = reminderRepo
        self.leadRepo = leadRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Entity Ownership

    private func enforceEntityAccess(entityId: UUID, entityType: String, site: String, user: User) -> ServiceResult<Void> {
        guard entityType == "Lead" else { return .success(()) }
        guard let lead = leadRepo.findById(entityId) else { return .failure(.entityNotFound) }
        guard lead.siteId == site else { return .failure(.permissionDenied) }
        switch user.role {
        case .administrator, .complianceReviewer: return .success(())
        default:
            guard lead.assignedTo == nil || lead.assignedTo == user.id else { return .failure(.permissionDenied) }
            return .success(())
        }
    }

    // MARK: - Create Reminder

    func createReminder(
        by user: User,
        site: String,
        entityId: UUID,
        entityType: String,
        dueAt: Date,
        operationId: UUID
    ) -> ServiceResult<Reminder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }

        let reminder = Reminder(
            id: UUID(),
            siteId: site,
            entityId: entityId,
            entityType: entityType,
            createdBy: user.id,
            dueAt: dueAt,
            status: .pending
        )

        do {
            try reminderRepo.save(reminder)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "reminder_created", entityId: reminder.id)
            return .success(reminder)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Complete Reminder

    func completeReminder(by user: User, site: String, reminderId: UUID, operationId: UUID) -> ServiceResult<Reminder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard var reminder = reminderRepo.findById(reminderId) else {
            return .failure(.entityNotFound)
        }
        guard reminder.siteId == site else { return .failure(.permissionDenied) }

        if case .failure(let err) = enforceEntityAccess(entityId: reminder.entityId, entityType: reminder.entityType, site: site, user: user) {
            return .failure(err)
        }

        guard reminder.status == .pending else {
            return .failure(.invalidTransition)
        }

        reminder.status = .completed

        do {
            try reminderRepo.save(reminder)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "reminder_completed", entityId: reminderId)
            return .success(reminder)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Cancel Reminder

    func cancelReminder(by user: User, site: String, reminderId: UUID, operationId: UUID) -> ServiceResult<Reminder> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard var reminder = reminderRepo.findById(reminderId) else {
            return .failure(.entityNotFound)
        }
        guard reminder.siteId == site else { return .failure(.permissionDenied) }

        if case .failure(let err) = enforceEntityAccess(entityId: reminder.entityId, entityType: reminder.entityType, site: site, user: user) {
            return .failure(err)
        }

        guard reminder.status == .pending else {
            return .failure(.invalidTransition)
        }

        reminder.status = .canceled

        do {
            try reminderRepo.save(reminder)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "reminder_canceled", entityId: reminderId)
            return .success(reminder)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Due Reminders

    func getDueReminders(now: Date = Date()) -> [Reminder] {
        reminderRepo.findDueReminders(before: now)
    }

    func findByEntity(by user: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[Reminder]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }
        return .success(reminderRepo.findByEntity(entityId: entityId, entityType: entityType).filter { $0.siteId == site })
    }
}
