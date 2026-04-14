import Foundation
import CoreData

final class CoreDataInventoryItemRepository: InventoryItemRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDInventoryItem"

    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> InventoryItem? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { InventoryItem(mo: $0) }
    }

    func findByIdentifier(_ identifier: String) -> InventoryItem? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "identifier == %@", identifier), context: context
        ).first.map { InventoryItem(mo: $0) }
    }

    func findAll() -> [InventoryItem] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { InventoryItem(mo: $0) }
    }

    func findBySiteId(_ siteId: String) -> [InventoryItem] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { InventoryItem(mo: $0) }
    }

    func save(_ item: InventoryItem) throws {
        try CoreDataHelpers.upsert(id: item.id, entityName: entityName, context: context) { mo in
            item.apply(to: mo)
        }
    }

    func delete(_ id: UUID) throws {
        try CoreDataHelpers.delete(id: id, entityName: entityName, context: context)
    }
}
