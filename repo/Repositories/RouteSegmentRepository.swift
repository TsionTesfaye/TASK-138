import Foundation

protocol RouteSegmentRepository {
    func findById(_ id: UUID) -> RouteSegment?
    func findByPoolOrderId(_ poolOrderId: UUID) -> [RouteSegment]
    func save(_ segment: RouteSegment) throws
    func delete(_ id: UUID) throws
}

final class InMemoryRouteSegmentRepository: RouteSegmentRepository {
    private var store: [UUID: RouteSegment] = [:]

    func findById(_ id: UUID) -> RouteSegment? { store[id] }

    func findByPoolOrderId(_ poolOrderId: UUID) -> [RouteSegment] {
        store.values.filter { $0.poolOrderId == poolOrderId }.sorted { $0.sequence < $1.sequence }
    }

    func save(_ segment: RouteSegment) throws { store[segment.id] = segment }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
