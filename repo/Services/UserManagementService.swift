import Foundation

/// design.md 4.18
/// Admin-only user management: create, update role, deactivate, reset lockout.
final class UserManagementService {

    private let userRepo: UserRepository
    private let permissionService: PermissionService
    private let authService: AuthService
    private let auditService: AuditService
    private let operationLogRepo: OperationLogRepository

    init(
        userRepo: UserRepository,
        permissionService: PermissionService,
        authService: AuthService,
        auditService: AuditService,
        operationLogRepo: OperationLogRepository
    ) {
        self.userRepo = userRepo
        self.permissionService = permissionService
        self.authService = authService
        self.auditService = auditService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Create User

    /// Only Administrator can create users. No self-registration after bootstrap.
    func createUser(
        by admin: User,
        username: String,
        password: String,
        role: UserRole,
        operationId: UUID
    ) -> ServiceResult<User> {
        // Idempotency check
        if operationLogRepo.exists(operationId) {
            return .failure(.duplicateOperation)
        }

        // Permission: admin only
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        // Validate password
        if let error = authService.validatePasswordPolicy(password) {
            return .failure(error)
        }

        // Check username uniqueness
        if userRepo.findByUsername(username) != nil {
            return .failure(.duplicateEntity)
        }

        let salt = authService.generateSalt()
        let hash = authService.hashPassword(password, salt: salt)

        let user = User(
            id: UUID(),
            username: username,
            passwordHash: hash,
            passwordSalt: salt,
            role: role,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )

        do {
            try userRepo.save(user)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: admin.id, action: "user_created", entityId: user.id)
            return .success(user)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Update Role

    func updateRole(by admin: User, userId: UUID, newRole: UserRole, operationId: UUID) -> ServiceResult<User> {
        if operationLogRepo.exists(operationId) {
            return .failure(.duplicateOperation)
        }

        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        guard var user = userRepo.findById(userId) else {
            return .failure(.entityNotFound)
        }

        let oldRole = user.role
        user.role = newRole

        do {
            try userRepo.save(user)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: admin.id, action: "role_changed_from_\(oldRole.rawValue)_to_\(newRole.rawValue)", entityId: userId)
            return .success(user)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Deactivate User

    func deactivateUser(by admin: User, userId: UUID, operationId: UUID) -> ServiceResult<Void> {
        if operationLogRepo.exists(operationId) {
            return .failure(.duplicateOperation)
        }

        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        // Prevent admin from deactivating themselves
        guard admin.id != userId else {
            return .failure(ServiceError(code: "SELF_DEACTIVATE", message: "Cannot deactivate own account"))
        }

        guard var user = userRepo.findById(userId) else {
            return .failure(.entityNotFound)
        }

        user.isActive = false

        do {
            try userRepo.save(user)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: admin.id, action: "user_deactivated", entityId: userId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Query

    func listUsers(by admin: User) -> ServiceResult<[User]> {
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }
        return .success(userRepo.findAll())
    }

    func findUserByUsername(by admin: User, username: String) -> ServiceResult<User?> {
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }
        return .success(userRepo.findByUsername(username))
    }

    // MARK: - Permission Scope Management

    func listAllScopes(by admin: User) -> ServiceResult<[PermissionScope]> {
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }
        let users = userRepo.findAll()
        var allScopes: [PermissionScope] = []
        for u in users {
            allScopes.append(contentsOf: permissionService.permissionScopeRepo.findByUserId(u.id))
        }
        return .success(allScopes)
    }

    func createScope(
        by admin: User,
        userId: UUID,
        site: String,
        functionKey: String,
        validFrom: Date,
        validTo: Date
    ) -> ServiceResult<PermissionScope> {
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        let scope = PermissionScope(
            id: UUID(), userId: userId, site: site, functionKey: functionKey,
            validFrom: validFrom, validTo: validTo
        )

        do {
            try permissionService.permissionScopeRepo.save(scope)
            auditService.log(actorId: admin.id, action: "permission_scope_created", entityId: scope.id)
            return .success(scope)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    func deleteScope(by admin: User, scopeId: UUID) -> ServiceResult<Void> {
        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        do {
            try permissionService.permissionScopeRepo.delete(scopeId)
            auditService.log(actorId: admin.id, action: "permission_scope_deleted", entityId: scopeId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Reset Lockout

    func resetLockout(by admin: User, userId: UUID, operationId: UUID) -> ServiceResult<Void> {
        if operationLogRepo.exists(operationId) {
            return .failure(.duplicateOperation)
        }

        if case .failure(let err) = permissionService.requireAdmin(user: admin) {
            return .failure(err)
        }

        guard var user = userRepo.findById(userId) else {
            return .failure(.entityNotFound)
        }

        user.failedAttempts = 0
        user.lastFailedAttempt = nil
        user.lockoutUntil = nil

        do {
            try userRepo.save(user)
            try operationLogRepo.save(operationId)
            auditService.log(actorId: admin.id, action: "lockout_reset", entityId: userId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }
}
