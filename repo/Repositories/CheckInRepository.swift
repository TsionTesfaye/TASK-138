import Foundation

protocol CheckInRepository {
    func findById(_ id: UUID) -> CheckIn?
    func findByUserId(_ userId: UUID) -> [CheckIn]
    func findByUserIdInTimeRange(userId: UUID, start: Date, end: Date) -> [CheckIn]
    func findInTimeRange(start: Date, end: Date) -> [CheckIn]
    func findAll() -> [CheckIn]
    func findBySiteId(_ siteId: String) -> [CheckIn]
    func save(_ checkIn: CheckIn) throws
    func delete(_ id: UUID) throws
}

final class InMemoryCheckInRepository: CheckInRepository {
    private var store: [UUID: CheckIn] = [:]

    func findById(_ id: UUID) -> CheckIn? { store[id] }

    func findByUserId(_ userId: UUID) -> [CheckIn] {
        store.values.filter { $0.userId == userId }
    }

    func findByUserIdInTimeRange(userId: UUID, start: Date, end: Date) -> [CheckIn] {
        store.values.filter {
            $0.userId == userId && $0.timestamp >= start && $0.timestamp <= end
        }
    }

    func findInTimeRange(start: Date, end: Date) -> [CheckIn] {
        store.values.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    func findAll() -> [CheckIn] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [CheckIn] {
        Array(store.values.filter { $0.siteId == siteId })
    }

    func save(_ checkIn: CheckIn) throws { store[checkIn.id] = checkIn }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
