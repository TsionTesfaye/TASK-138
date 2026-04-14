import Foundation

/// design.md 4.4, questions.md Q13
/// Manages reminders with state-driven lifecycle.
final class ReminderService {

    private let reminderRepo: ReminderRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        reminderRepo: ReminderRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.reminderRepo = reminderRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
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

        let reminder = Reminder(
            id: UUID(),
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
        return .success(reminderRepo.findByEntity(entityId: entityId, entityType: entityType))
    }
}
