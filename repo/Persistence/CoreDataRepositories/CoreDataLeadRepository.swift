import Foundation
import CoreData

final class CoreDataLeadRepository: LeadRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDLead"

    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Lead? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Lead(mo: $0) }
    }

    func findByStatus(_ status: LeadStatus) -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { Lead(mo: $0) }
    }

    func findByAssignedTo(_ userId: UUID) -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "assignedTo == %@", userId as CVarArg), context: context
        ).map { Lead(mo: $0) }
    }

    func findLeadsExceedingSLA(before deadline: Date) -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND archivedAt == nil AND slaDeadline != nil AND slaDeadline <= %@",
                LeadStatus.new.rawValue, deadline as CVarArg), context: context
        ).map { Lead(mo: $0) }
    }

    func findClosedLeadsOlderThan(_ date: Date) -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "(status == %@ OR status == %@) AND archivedAt == nil AND updatedAt <= %@",
                LeadStatus.closedWon.rawValue, LeadStatus.invalid.rawValue, date as CVarArg), context: context
        ).map { Lead(mo: $0) }
    }

    func findAll() -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Lead(mo: $0) }
    }

    func findBySiteId(_ siteId: String) -> [Lead] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { Lead(mo: $0) }
    }

    func save(_ lead: Lead) throws {
        try CoreDataHelpers.upsert(id: lead.id, entityName: entityName, context: context) { mo in
            lead.apply(to: mo)
        }
    }

    func delete(_ id: UUID) throws {
        try CoreDataHelpers.delete(id: id, entityName: entityName, context: context)
    }
}
