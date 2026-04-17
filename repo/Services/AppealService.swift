import Foundation

/// Manages appeal lifecycle. Approval updates the originating ExceptionCase.
final class AppealService {

    private let appealRepo: AppealRepository
    private let exceptionCaseRepo: ExceptionCaseRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        appealRepo: AppealRepository,
        exceptionCaseRepo: ExceptionCaseRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.appealRepo = appealRepo
        self.exceptionCaseRepo = exceptionCaseRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Submit Appeal

    func submitAppeal(
        by user: User,
        site: String,
        exceptionId: UUID,
        reason: String,
        operationId: UUID
    ) -> ServiceResult<Appeal> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }

        guard var exception = exceptionCaseRepo.findById(exceptionId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        // Prevent duplicate appeals for same exception
        let existingAppeals = appealRepo.findByExceptionId(exceptionId, siteId: site)
        let hasActiveAppeal = existingAppeals.contains {
            $0.status == .submitted || $0.status == .underReview
        }
        guard !hasActiveAppeal else {
            return .failure(.duplicateEntity)
        }

        guard !reason.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.validationFailed("reason", "required"))
        }

        let appeal = Appeal(
            id: UUID(),
            siteId: site,
            exceptionId: exceptionId,
            status: .submitted,
            reviewerId: nil,
            submittedBy: user.id,
            reason: reason,
            resolvedAt: nil
        )

        // Update exception status to under_appeal
        exception.status = .underAppeal

        do {
            try appealRepo.save(appeal)
            try exceptionCaseRepo.save(exception)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "appeal_submitted", entityId: appeal.id)
            return .success(appeal)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Start Review (submitted → under_review)

    func startReview(
        by reviewer: User,
        site: String,
        appealId: UUID,
        operationId: UUID
    ) -> ServiceResult<Appeal> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: reviewer, action: "review", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }

        guard var appeal = appealRepo.findById(appealId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        guard appeal.status.canTransition(to: .underReview) else {
            return .failure(.invalidTransition)
        }

        appeal.status = .underReview
        appeal.reviewerId = reviewer.id

        do {
            try appealRepo.save(appeal)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: reviewer.id, action: "appeal_review_started", entityId: appealId)
            return .success(appeal)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Approve Appeal

    /// Approval updates ExceptionCase status to 'resolved'.
    func approveAppeal(
        by reviewer: User,
        site: String,
        appealId: UUID,
        operationId: UUID
    ) -> ServiceResult<Appeal> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: reviewer, action: "approve", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }

        guard var appeal = appealRepo.findById(appealId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        // Reviewer ownership: only the assigned reviewer (or admin) can approve
        if case .failure(let err) = enforceReviewerOwnership(appeal, reviewer: reviewer) {
            return .failure(err)
        }

        guard appeal.status.canTransition(to: .approved) else {
            return .failure(.invalidTransition)
        }

        appeal.status = .approved
        appeal.resolvedAt = Date()

        // Write back to ExceptionCase: resolved (site-scoped to prevent cross-site mutation)
        guard var exception = exceptionCaseRepo.findById(appeal.exceptionId, siteId: site) else {
            return .failure(.entityNotFound)
        }
        exception.status = .resolved

        do {
            try appealRepo.save(appeal)
            try exceptionCaseRepo.save(exception)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: reviewer.id, action: "appeal_approved", entityId: appealId)
            auditService.log(actorId: reviewer.id, action: "exception_resolved_via_appeal", entityId: exception.id)
            return .success(appeal)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Deny Appeal

    /// Denial updates ExceptionCase status to 'dismissed' (appeal rejected, exception stands).
    func denyAppeal(
        by reviewer: User,
        site: String,
        appealId: UUID,
        operationId: UUID
    ) -> ServiceResult<Appeal> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: reviewer, action: "deny", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }

        guard var appeal = appealRepo.findById(appealId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        // Reviewer ownership: only the assigned reviewer (or admin) can deny
        if case .failure(let err) = enforceReviewerOwnership(appeal, reviewer: reviewer) {
            return .failure(err)
        }

        guard appeal.status.canTransition(to: .denied) else {
            return .failure(.invalidTransition)
        }

        appeal.status = .denied
        appeal.resolvedAt = Date()

        // Exception remains open (dismiss the appeal, not the exception; site-scoped)
        guard var exception = exceptionCaseRepo.findById(appeal.exceptionId, siteId: site) else {
            return .failure(.entityNotFound)
        }
        exception.status = .open

        do {
            try appealRepo.save(appeal)
            try exceptionCaseRepo.save(exception)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: reviewer.id, action: "appeal_denied", entityId: appealId)
            return .success(appeal)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Archive Appeal (approved/denied → archived)

    func archiveAppeal(
        by user: User,
        site: String,
        appealId: UUID,
        operationId: UUID
    ) -> ServiceResult<Appeal> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "review", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }

        guard var appeal = appealRepo.findById(appealId, siteId: site) else {
            return .failure(.entityNotFound)
        }

        guard appeal.status.canTransition(to: .archived) else {
            return .failure(.invalidTransition)
        }

        appeal.status = .archived

        do {
            try appealRepo.save(appeal)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: user.id, action: "appeal_archived", entityId: appealId)
            return .success(appeal)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Query

    func findById(by user: User, site: String, _ id: UUID) -> ServiceResult<Appeal?> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }
        return .success(appealRepo.findById(id, siteId: site))
    }

    func findByExceptionId(by user: User, site: String, _ exceptionId: UUID) -> ServiceResult<[Appeal]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }
        return .success(appealRepo.findByExceptionId(exceptionId, siteId: site))
    }

    func findByStatus(by user: User, site: String, _ status: AppealStatus) -> ServiceResult<[Appeal]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .appeals,
            site: site, functionKey: "appeals"
        ) {
            return .failure(err)
        }
        let all = appealRepo.findByStatus(status, siteId: site)
        return .success(filterAppealsByUser(all, user: user))
    }

    /// Enforce that approve/deny is performed by the assigned reviewer or an admin.
    /// The appeal must have a reviewerId set (from startReview), and it must match the acting user.
    /// Admins may override to act on any appeal.
    private func enforceReviewerOwnership(_ appeal: Appeal, reviewer: User) -> ServiceResult<Void> {
        if reviewer.role == .administrator {
            return .success(())
        }
        guard let assignedReviewer = appeal.reviewerId, assignedReviewer == reviewer.id else {
            return .failure(ServiceError(code: "APPEAL_NOT_ASSIGNED", message: "Only the assigned reviewer can approve or deny this appeal"))
        }
        return .success(())
    }

    /// Admins and compliance reviewers see all appeals.
    /// Sales associates see only appeals they submitted.
    private func filterAppealsByUser(_ appeals: [Appeal], user: User) -> [Appeal] {
        switch user.role {
        case .administrator, .complianceReviewer:
            return appeals
        default:
            return appeals.filter { $0.submittedBy == user.id }
        }
    }
}
