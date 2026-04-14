import Foundation

protocol ExceptionCaseRepository {
    func findById(_ id: UUID) -> ExceptionCase?
    func findById(_ id: UUID, siteId: String) -> ExceptionCase?
    func findByType(_ type: ExceptionType) -> [ExceptionCase]
    func findByStatus(_ status: ExceptionCaseStatus) -> [ExceptionCase]
    func findByStatus(_ status: ExceptionCaseStatus, siteId: String) -> [ExceptionCase]
    func findBySourceId(_ sourceId: UUID) -> [ExceptionCase]
    func findAll() -> [ExceptionCase]
    func findBySiteId(_ siteId: String) -> [ExceptionCase]
    func save(_ exceptionCase: ExceptionCase) throws
    func delete(_ id: UUID) throws
}

final class InMemoryExceptionCaseRepository: ExceptionCaseRepository {
    private var store: [UUID: ExceptionCase] = [:]

    func findById(_ id: UUID) -> ExceptionCase? { store[id] }

    func findById(_ id: UUID, siteId: String) -> ExceptionCase? {
        guard let ec = store[id], ec.siteId == siteId else { return nil }
        return ec
    }

    func findByType(_ type: ExceptionType) -> [ExceptionCase] {
        store.values.filter { $0.type == type }
    }

    func findByStatus(_ status: ExceptionCaseStatus) -> [ExceptionCase] {
        store.values.filter { $0.status == status }
    }

    func findByStatus(_ status: ExceptionCaseStatus, siteId: String) -> [ExceptionCase] {
        store.values.filter { $0.status == status && $0.siteId == siteId }
    }

    func findBySourceId(_ sourceId: UUID) -> [ExceptionCase] {
        store.values.filter { $0.sourceId == sourceId }
    }

    func findAll() -> [ExceptionCase] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [ExceptionCase] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ exceptionCase: ExceptionCase) throws { store[exceptionCase.id] = exceptionCase }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
