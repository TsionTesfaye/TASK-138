import Foundation

/// design.md 4.15, 4.19
/// Central permission enforcement. ALL services must call validateAccess before writes/sensitive reads.
/// Rules: No bypass allowed. Missing permission = hard failure.
final class PermissionService {

    let permissionScopeRepo: PermissionScopeRepository

    init(permissionScopeRepo: PermissionScopeRepository) {
        self.permissionScopeRepo = permissionScopeRepo
    }

    // MARK: - Role-Based Access (Matrix)

    /// Check if user's role permits the given action on the given module.
    /// Uses PermissionMatrix from design.md 4.19.
    func validateAccess(user: User, action: String, module: PermissionModule) -> ServiceResult<Void> {
        guard user.isActive else {
            return .failure(.accountInactive)
        }
        guard PermissionMatrix.canPerform(role: user.role, action: action, module: module) else {
            return .failure(.permissionDenied)
        }
        return .success(())
    }

    // MARK: - Scope-Based Access

    /// Check if user has a valid scope for the given site and functionKey at the current date.
    /// design.md: default rule: no scope = no access
    /// Note: Administrators bypass scope checks (full access).
    func validateScope(user: User, site: String, functionKey: String, at date: Date = Date()) -> ServiceResult<Void> {
        guard user.isActive else {
            return .failure(.accountInactive)
        }
        // Administrators bypass scope
        if user.role == .administrator {
            return .success(())
        }
        let scopes = permissionScopeRepo.findByUserIdAndSiteAndFunction(
            userId: user.id, site: site, functionKey: functionKey, at: date
        )
        guard !scopes.isEmpty else {
            return .failure(.scopeDenied)
        }
        return .success(())
    }

    // MARK: - Combined Validation

    /// Validate both role-based access and scope in one call.
    func validateFullAccess(
        user: User,
        action: String,
        module: PermissionModule,
        site: String,
        functionKey: String,
        at date: Date = Date()
    ) -> ServiceResult<Void> {
        let roleResult = validateAccess(user: user, action: action, module: module)
        if case .failure = roleResult { return roleResult }

        let scopeResult = validateScope(user: user, site: site, functionKey: functionKey, at: date)
        if case .failure = scopeResult { return scopeResult }

        return .success(())
    }

    // MARK: - Admin Check

    func requireAdmin(user: User) -> ServiceResult<Void> {
        guard user.isActive else {
            return .failure(.accountInactive)
        }
        guard user.role == .administrator else {
            return .failure(.adminRequired)
        }
        return .success(())
    }
}
