import Foundation

enum UserRole: String, CaseIterable, Codable {
    case administrator = "administrator"
    case salesAssociate = "sales_associate"
    case inventoryClerk = "inventory_clerk"
    case complianceReviewer = "compliance_reviewer"
}
