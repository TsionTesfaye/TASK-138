import Foundation

protocol PermissionScopeRepository {
    func findByUserId(_ userId: UUID) -> [PermissionScope]
    func findByUserIdAndSiteAndFunction(userId: UUID, site: String, functionKey: String, at date: Date) -> [PermissionScope]
    func findAll() -> [PermissionScope]
    func save(_ scope: PermissionScope) throws
    func delete(_ id: UUID) throws
}

final class InMemoryPermissionScopeRepository: PermissionScopeRepository {
    private var store: [UUID: PermissionScope] = [:]

    func findByUserId(_ userId: UUID) -> [PermissionScope] {
        store.values.filter { $0.userId == userId }
    }

    func findByUserIdAndSiteAndFunction(userId: UUID, site: String, functionKey: String, at date: Date) -> [PermissionScope] {
        store.values.filter {
            $0.userId == userId &&
            $0.site == site &&
            $0.functionKey == functionKey &&
            $0.validFrom <= date &&
            $0.validTo >= date
        }
    }

    func findAll() -> [PermissionScope] { Array(store.values) }

    func save(_ scope: PermissionScope) throws {
        store[scope.id] = scope
    }

    func delete(_ id: UUID) throws {
        store.removeValue(forKey: id)
    }
}
