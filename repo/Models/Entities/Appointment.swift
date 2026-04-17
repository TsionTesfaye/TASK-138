import Foundation

struct Appointment: Equatable {
    let id: UUID
    var siteId: String
    var leadId: UUID
    var startTime: Date
    var status: AppointmentStatus
}
