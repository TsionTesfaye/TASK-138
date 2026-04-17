import Foundation

protocol RoleRepository {
    func findAll() -> [Role]
    func findById(_ id: UUID) -> Role?
    func findByName(_ name: UserRole) -> Role?
    func save(_ role: Role) throws
}

final class InMemoryRoleRepository: RoleRepository {
    private var store: [UUID: Role] = [:]

    init() {
        let definitions: [(UserRole, String)] = [
            (.administrator, "Administrator"),
            (.salesAssociate, "Sales Associate"),
            (.inventoryClerk, "Inventory Clerk"),
            (.complianceReviewer, "Compliance Reviewer"),
        ]
        for (name, displayName) in definitions {
            let role = Role(id: UUID(), name: name, displayName: displayName)
            store[role.id] = role
        }
    }

    func findAll() -> [Role] { Array(store.values) }
    func findById(_ id: UUID) -> Role? { store[id] }
    func findByName(_ name: UserRole) -> Role? { store.values.first { $0.name == name } }
    func save(_ role: Role) throws { store[role.id] = role }
}
