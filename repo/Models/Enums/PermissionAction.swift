import Foundation

/// Modules in the permission matrix
enum PermissionModule: String, CaseIterable, Codable {
    case leads = "leads"
    case inventory = "inventory"
    case carpool = "carpool"
    case appeals = "appeals"
    case exceptions = "exceptions"
    case checkin = "checkin"
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

struct PermissionMatrix {

    /// Returns the permission level for a given role and module.
    ///
    /// | Role                | Leads | Inventory | Carpool | Appeals | Exceptions | Checkin | Admin |
    /// |---------------------|-------|-----------|---------|---------|------------|---------|-------|
    /// | Administrator       | FULL  | FULL      | FULL    | FULL    | FULL       | FULL    | FULL  |
    /// | Sales Associate     | CRUD  | NONE      | CRUD    | CREATE  | READ       | CREATE  | NONE  |
    /// | Inventory Clerk     | NONE  | CRUD      | NONE    | CREATE  | NONE       | CREATE  | NONE  |
    /// | Compliance Reviewer | NONE  | NONE      | NONE    | REVIEW  | REVIEW     | CREATE  | NONE  |
    ///
    /// Checkin is a dedicated module so any active scoped staff member can record their own
    /// check-in without being granted exception-management permissions.
    static func level(for role: UserRole, module: PermissionModule) -> PermissionLevel {
        switch (role, module) {
        // Administrator: full access to everything
        case (.administrator, _):
            return .full

        // Sales Associate
        case (.salesAssociate, .leads):       return .crud
        case (.salesAssociate, .inventory):   return .none
        case (.salesAssociate, .carpool):     return .crud
        case (.salesAssociate, .appeals):     return .create
        case (.salesAssociate, .exceptions):  return .read
        case (.salesAssociate, .checkin):     return .create
        case (.salesAssociate, .admin):       return .none

        // Inventory Clerk
        case (.inventoryClerk, .leads):       return .none
        case (.inventoryClerk, .inventory):   return .crud
        case (.inventoryClerk, .carpool):     return .none
        case (.inventoryClerk, .appeals):     return .create
        case (.inventoryClerk, .exceptions):  return .none
        case (.inventoryClerk, .checkin):     return .create
        case (.inventoryClerk, .admin):       return .none

        // Compliance Reviewer
        case (.complianceReviewer, .leads):       return .none
        case (.complianceReviewer, .inventory):   return .none
        case (.complianceReviewer, .carpool):     return .none
        case (.complianceReviewer, .appeals):     return .review
        case (.complianceReviewer, .exceptions):  return .review
        case (.complianceReviewer, .checkin):     return .create
        case (.complianceReviewer, .admin):       return .none
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
