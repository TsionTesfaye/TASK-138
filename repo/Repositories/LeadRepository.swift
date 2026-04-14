import Foundation

protocol LeadRepository {
    func findById(_ id: UUID) -> Lead?
    func findByStatus(_ status: LeadStatus) -> [Lead]
    func findByAssignedTo(_ userId: UUID) -> [Lead]
    func findLeadsExceedingSLA(before deadline: Date) -> [Lead]
    func findClosedLeadsOlderThan(_ date: Date) -> [Lead]
    func findAll() -> [Lead]
    func findBySiteId(_ siteId: String) -> [Lead]
    func save(_ lead: Lead) throws
    func delete(_ id: UUID) throws
}

final class InMemoryLeadRepository: LeadRepository {
    private var store: [UUID: Lead] = [:]

    func findById(_ id: UUID) -> Lead? { store[id] }

    func findByStatus(_ status: LeadStatus) -> [Lead] {
        store.values.filter { $0.status == status }
    }

    func findByAssignedTo(_ userId: UUID) -> [Lead] {
        store.values.filter { $0.assignedTo == userId }
    }

    func findLeadsExceedingSLA(before deadline: Date) -> [Lead] {
        store.values.filter {
            $0.status == .new &&
            $0.archivedAt == nil &&
            ($0.slaDeadline.map { $0 <= deadline } ?? false)
        }
    }

    func findClosedLeadsOlderThan(_ date: Date) -> [Lead] {
        let terminalStatuses: Set<LeadStatus> = [.closedWon, .invalid]
        return store.values.filter {
            terminalStatuses.contains($0.status) &&
            $0.archivedAt == nil &&
            $0.updatedAt <= date
        }
    }

    func findAll() -> [Lead] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [Lead] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ lead: Lead) throws {
        store[lead.id] = lead
    }

    func delete(_ id: UUID) throws {
        store.removeValue(forKey: id)
    }
}
