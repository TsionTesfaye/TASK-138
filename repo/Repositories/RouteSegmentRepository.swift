import Foundation

protocol RouteSegmentRepository {
    func findById(_ id: UUID) -> RouteSegment?
    func findByMatchId(_ matchId: UUID) -> [RouteSegment]
    func save(_ segment: RouteSegment) throws
    func delete(_ id: UUID) throws
}

final class InMemoryRouteSegmentRepository: RouteSegmentRepository {
    private var store: [UUID: RouteSegment] = [:]

    func findById(_ id: UUID) -> RouteSegment? { store[id] }

    func findByMatchId(_ matchId: UUID) -> [RouteSegment] {
        store.values.filter { $0.matchId == matchId }
    }

    func save(_ segment: RouteSegment) throws { store[segment.id] = segment }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
