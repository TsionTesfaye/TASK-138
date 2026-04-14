import Foundation
import CoreData

final class CoreDataUserRepository: UserRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDUser"

    init(context: NSManagedObjectContext) { self.context = context }

    func count() -> Int {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        return (try? context.count(for: request)) ?? 0
    }

    func findById(_ id: UUID) -> User? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { User(mo: $0) }
    }

    func findByUsername(_ username: String) -> User? {
        let results = CoreDataHelpers.fetch(
            entityName: entityName,
            predicate: NSPredicate(format: "username == %@", username),
            context: context
        )
        return results.first.map { User(mo: $0) }
    }

    func findAll() -> [User] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { User(mo: $0) }
    }

    func save(_ user: User) throws {
        try CoreDataHelpers.upsert(id: user.id, entityName: entityName, context: context) { mo in
            user.apply(to: mo)
        }
    }

    func delete(_ id: UUID) throws {
        try CoreDataHelpers.delete(id: id, entityName: entityName, context: context)
    }
}
