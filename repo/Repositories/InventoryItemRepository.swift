import Foundation

protocol InventoryItemRepository {
    func findById(_ id: UUID) -> InventoryItem?
    func findByIdentifier(_ identifier: String) -> InventoryItem?
    func findAll() -> [InventoryItem]
    func findBySiteId(_ siteId: String) -> [InventoryItem]
    func save(_ item: InventoryItem) throws
    func delete(_ id: UUID) throws
}

final class InMemoryInventoryItemRepository: InventoryItemRepository {
    private var store: [UUID: InventoryItem] = [:]

    func findById(_ id: UUID) -> InventoryItem? { store[id] }

    func findByIdentifier(_ identifier: String) -> InventoryItem? {
        store.values.first { $0.identifier == identifier }
    }

    func findAll() -> [InventoryItem] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [InventoryItem] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ item: InventoryItem) throws { store[item.id] = item }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
