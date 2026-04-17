import Foundation

/// Persisted role record. The role set is fixed by policy but stored as entities
/// so roles can be enumerated, carry display metadata, and be validated by ID.
struct Role: Equatable {
    let id: UUID
    let name: UserRole
    let displayName: String
}
