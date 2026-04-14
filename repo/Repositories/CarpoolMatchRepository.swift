import Foundation

protocol CarpoolMatchRepository {
    func findById(_ id: UUID) -> CarpoolMatch?
    func findByRequestOrderId(_ orderId: UUID) -> [CarpoolMatch]
    func findByOfferOrderId(_ orderId: UUID) -> [CarpoolMatch]
    func findAcceptedByOrderId(_ orderId: UUID) -> CarpoolMatch?
    func findAll() -> [CarpoolMatch]
    func save(_ match: CarpoolMatch) throws
    func delete(_ id: UUID) throws
}

final class InMemoryCarpoolMatchRepository: CarpoolMatchRepository {
    private var store: [UUID: CarpoolMatch] = [:]

    func findById(_ id: UUID) -> CarpoolMatch? { store[id] }

    func findByRequestOrderId(_ orderId: UUID) -> [CarpoolMatch] {
        store.values.filter { $0.requestOrderId == orderId }
    }

    func findByOfferOrderId(_ orderId: UUID) -> [CarpoolMatch] {
        store.values.filter { $0.offerOrderId == orderId }
    }

    func findAcceptedByOrderId(_ orderId: UUID) -> CarpoolMatch? {
        store.values.first {
            ($0.requestOrderId == orderId || $0.offerOrderId == orderId) && $0.accepted
        }
    }

    func findAll() -> [CarpoolMatch] { Array(store.values) }

    func save(_ match: CarpoolMatch) throws { store[match.id] = match }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
