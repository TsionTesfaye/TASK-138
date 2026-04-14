import Foundation

protocol AppointmentRepository {
    func findById(_ id: UUID) -> Appointment?
    func findByLeadId(_ leadId: UUID) -> [Appointment]
    func findByStatus(_ status: AppointmentStatus) -> [Appointment]
    func findUnconfirmedBefore(_ date: Date) -> [Appointment]
    func findAll() -> [Appointment]
    func findBySiteId(_ siteId: String) -> [Appointment]
    func save(_ appointment: Appointment) throws
    func delete(_ id: UUID) throws
}

final class InMemoryAppointmentRepository: AppointmentRepository {
    private var store: [UUID: Appointment] = [:]

    func findById(_ id: UUID) -> Appointment? { store[id] }

    func findByLeadId(_ leadId: UUID) -> [Appointment] {
        store.values.filter { $0.leadId == leadId }
    }

    func findByStatus(_ status: AppointmentStatus) -> [Appointment] {
        store.values.filter { $0.status == status }
    }

    func findUnconfirmedBefore(_ date: Date) -> [Appointment] {
        store.values.filter {
            $0.status == .scheduled &&
            $0.startTime <= date
        }
    }

    func findAll() -> [Appointment] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [Appointment] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ appointment: Appointment) throws {
        store[appointment.id] = appointment
    }

    func delete(_ id: UUID) throws {
        store.removeValue(forKey: id)
    }
}
