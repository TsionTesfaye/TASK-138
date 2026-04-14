import Foundation
import CoreData

/// Shared helpers for Core Data repositories.
enum CoreDataHelpers {

    /// Fetch a single managed object by UUID id field.
    static func findById(
        _ id: UUID, entityName: String, context: NSManagedObjectContext
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    /// Fetch all managed objects matching a predicate.
    static func fetch(
        entityName: String,
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.predicate = predicate
        return (try? context.fetch(request)) ?? []
    }

    /// Upsert: find by id or insert new, then apply values and save.
    static func upsert(
        id: UUID, entityName: String, context: NSManagedObjectContext,
        apply: (NSManagedObject) -> Void
    ) throws {
        let mo = findById(id, entityName: entityName, context: context)
            ?? NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        apply(mo)
        try context.save()
    }

    /// Delete by id.
    static func delete(
        id: UUID, entityName: String, context: NSManagedObjectContext
    ) throws {
        guard let mo = findById(id, entityName: entityName, context: context) else { return }
        context.delete(mo)
        try context.save()
    }
}
