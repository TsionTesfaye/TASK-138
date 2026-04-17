import Foundation

/// Seeds demo accounts for QA and tester use.
/// Invoked at app launch via the `-SeedDemoAccounts` launch argument.
///
/// Safety guarantees:
/// - Idempotent: checks by username before saving. Running twice produces no duplicates.
/// - Non-destructive: never deletes or overwrites existing users.
/// - Bootstrap locked: after seeding, userRepo.count() > 0 → BootstrapViewController is
///   unreachable (AppDelegate routes to LoginViewController when count > 0).
struct DebugSeeder {

    private let userRepo: UserRepository
    private let permissionScopeRepo: PermissionScopeRepository
    private let authService: AuthService

    /// The site name used for all non-admin demo permission scopes.
    static let demoSite = "demo-lot"

    /// Canonical credentials — must match the README "Tester Quick Start" table exactly.
    static let accounts: [(username: String, password: String, role: UserRole)] = [
        ("admin",     "Admin12345678",  .administrator),
        ("sales1",    "Sales12345678",  .salesAssociate),
        ("clerk1",    "Clerk12345678",  .inventoryClerk),
        ("reviewer1", "Reviewer12345", .complianceReviewer),
    ]

    // Function keys granted to each non-admin role at demoSite.
    // Administrators bypass scope checks entirely (PermissionService.validateScope).
    private static let scopesByRole: [UserRole: [String]] = [
        .salesAssociate:     ["leads", "carpool"],
        .inventoryClerk:     ["inventory"],
        .complianceReviewer: ["compliance", "leads"],
    ]

    init(userRepo: UserRepository, permissionScopeRepo: PermissionScopeRepository, authService: AuthService) {
        self.userRepo = userRepo
        self.permissionScopeRepo = permissionScopeRepo
        self.authService = authService
    }

    /// Seed all demo accounts. Returns the number of new accounts created (0 if already seeded).
    @discardableResult
    func seed() -> Int {
        var created = 0
        let validFrom = Date()
        let validTo = validFrom.addingTimeInterval(365 * 24 * 3600) // 1 year

        for account in Self.accounts {
            // Idempotency: skip if username already exists
            guard userRepo.findByUsername(account.username) == nil else { continue }

            let salt = authService.generateSalt()
            let hash = authService.hashPassword(account.password, salt: salt)
            let user = User(
                id: UUID(),
                username: account.username,
                passwordHash: hash,
                passwordSalt: salt,
                role: account.role,
                biometricEnabled: false,
                failedAttempts: 0,
                lastFailedAttempt: nil,
                lockoutUntil: nil,
                createdAt: Date(),
                isActive: true
            )
            try? userRepo.save(user)

            if let keys = Self.scopesByRole[account.role] {
                for key in keys {
                    let scope = PermissionScope(
                        id: UUID(), userId: user.id, site: Self.demoSite,
                        functionKey: key, validFrom: validFrom, validTo: validTo
                    )
                    try? permissionScopeRepo.save(scope)
                }
            }

            created += 1
        }
        return created
    }
}
