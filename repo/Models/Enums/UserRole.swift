import Foundation

/// Role is modeled as an enum rather than a persisted entity by deliberate design choice.
/// The role set is fixed by policy; no runtime mutation is required.
/// Role assignment is persisted on the User entity and is fully audited via AuditService.
/// PermissionMatrix encodes all role capabilities statically, which is verified by the test suite.
/// If role metadata (labels, feature flags) becomes dynamic, migrate to a CDRole entity at that point.
enum UserRole: String, CaseIterable, Codable {
    case administrator = "administrator"
    case salesAssociate = "sales_associate"
    case inventoryClerk = "inventory_clerk"
    case complianceReviewer = "compliance_reviewer"
}
