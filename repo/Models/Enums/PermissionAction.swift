import Foundation

/// Modules in the permission matrix
enum PermissionModule: String, CaseIterable, Codable {
    case leads = "leads"
    case inventory = "inventory"
    case carpool = "carpool"
    case appeals = "appeals"
    case exceptions = "exceptions"
    case admin = "admin"
}

/// Access levels in the permission matrix
enum PermissionLevel: String, CaseIterable, Codable {
    case none = "none"
    case view = "view"
    case read = "read"
    case create = "create"
    case crud = "crud"
    case review = "review"
    case full = "full"
}

/// Permission matrix from design.md section 4.19
struct PermissionMatrix {

    /// Returns the permission level for a given role and module.
    /// Matches design.md 4.19 exactly:
    /// | Role                | Leads | Inventory | Carpool | Appeals | Admin |
    /// |---------------------|-------|-----------|---------|---------|-------|
    /// | Administrator       | FULL  | FULL      | FULL    | FULL    | FULL  |
    /// | Sales Associate     | CRUD  | NONE      | VIEW    | CREATE  | NONE  |
    /// | Inventory Clerk     | NONE  | CRUD      | NONE    | NONE    | NONE  |
    /// | Compliance Reviewer | READ  | READ      | NONE    | REVIEW  | NONE  |
    static func level(for role: UserRole, module: PermissionModule) -> PermissionLevel {
        switch (role, module) {
        // Administrator: full everything
        case (.administrator, _):
            return .full

        // Sales Associate
        case (.salesAssociate, .leads):
            return .crud
        case (.salesAssociate, .inventory):
            return .none
        case (.salesAssociate, .carpool):
            return .view
        case (.salesAssociate, .appeals):
            return .create
        case (.salesAssociate, .exceptions):
            return .read
        case (.salesAssociate, .admin):
            return .none

        // Inventory Clerk
        case (.inventoryClerk, .leads):
            return .none
        case (.inventoryClerk, .inventory):
            return .crud
        case (.inventoryClerk, .carpool):
            return .none
        case (.inventoryClerk, .appeals):
            return .none
        case (.inventoryClerk, .exceptions):
            return .none
        case (.inventoryClerk, .admin):
            return .none

        // Compliance Reviewer
        case (.complianceReviewer, .leads):
            return .read
        case (.complianceReviewer, .inventory):
            return .read
        case (.complianceReviewer, .carpool):
            return .none
        case (.complianceReviewer, .appeals):
            return .review
        case (.complianceReviewer, .exceptions):
            return .review
        case (.complianceReviewer, .admin):
            return .none
        }
    }

    /// Check if a role can perform a specific action on a module
    static func canPerform(role: UserRole, action: String, module: PermissionModule) -> Bool {
        let level = self.level(for: role, module: module)
        switch level {
        case .full:
            return true
        case .crud:
            return ["create", "read", "update", "delete"].contains(action)
        case .review:
            return ["read", "review", "approve", "deny"].contains(action)
        case .create:
            return ["create", "read"].contains(action)
        case .read:
            return action == "read"
        case .view:
            return action == "read"
        case .none:
            return false
        }
    }
}
