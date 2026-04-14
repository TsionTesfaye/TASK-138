import Foundation
import CoreData

final class CoreDataAppointmentRepository: AppointmentRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDAppointment"

    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Appointment? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Appointment(mo: $0) }
    }

    func findByLeadId(_ leadId: UUID) -> [Appointment] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "leadId == %@", leadId as CVarArg), context: context
        ).map { Appointment(mo: $0) }
    }

    func findByStatus(_ status: AppointmentStatus) -> [Appointment] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { Appointment(mo: $0) }
    }

    func findUnconfirmedBefore(_ date: Date) -> [Appointment] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND startTime <= %@",
                AppointmentStatus.scheduled.rawValue, date as CVarArg), context: context
        ).map { Appointment(mo: $0) }
    }

    func findAll() -> [Appointment] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Appointment(mo: $0) }
    }

    func findBySiteId(_ siteId: String) -> [Appointment] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { Appointment(mo: $0) }
    }

    func save(_ appointment: Appointment) throws {
        try CoreDataHelpers.upsert(id: appointment.id, entityName: entityName, context: context) { mo in
            appointment.apply(to: mo)
        }
    }

    func delete(_ id: UUID) throws {
        try CoreDataHelpers.delete(id: id, entityName: entityName, context: context)
    }
}
