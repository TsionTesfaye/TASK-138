import Foundation

struct Lead: Equatable {
    let id: UUID
    var siteId: String
    var leadType: LeadType
    var status: LeadStatus
    var customerName: String
    var phone: String
    var vehicleInterest: String
    var preferredContactWindow: String
    var consentNotes: String
    var assignedTo: UUID?
    var createdAt: Date
    var updatedAt: Date
    var slaDeadline: Date?
    var lastQualifyingAction: Date?
    var archivedAt: Date?
}
