import Foundation

protocol UserRepository {
    func count() -> Int
    func findById(_ id: UUID) -> User?
    func findByUsername(_ username: String) -> User?
    func findAll() -> [User]
    func save(_ user: User) throws
    func delete(_ id: UUID) throws
}

final class InMemoryUserRepository: UserRepository {
    private var store: [UUID: User] = [:]

    func count() -> Int { store.count }

    func findById(_ id: UUID) -> User? { store[id] }

    func findByUsername(_ username: String) -> User? {
        store.values.first { $0.username == username }
    }

    func findAll() -> [User] { Array(store.values) }

    func save(_ user: User) throws {
        store[user.id] = user
    }

    func delete(_ id: UUID) throws {
        store.removeValue(forKey: id)
    }
}
