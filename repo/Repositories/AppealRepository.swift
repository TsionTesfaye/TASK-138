import Foundation

protocol AppealRepository {
    func findById(_ id: UUID) -> Appeal?
    func findById(_ id: UUID, siteId: String) -> Appeal?
    func findByExceptionId(_ exceptionId: UUID) -> [Appeal]
    func findByExceptionId(_ exceptionId: UUID, siteId: String) -> [Appeal]
    func findByStatus(_ status: AppealStatus) -> [Appeal]
    func findByStatus(_ status: AppealStatus, siteId: String) -> [Appeal]
    func findByReviewerId(_ reviewerId: UUID) -> [Appeal]
    func findAll() -> [Appeal]
    func findBySiteId(_ siteId: String) -> [Appeal]
    func save(_ appeal: Appeal) throws
    func delete(_ id: UUID) throws
}

final class InMemoryAppealRepository: AppealRepository {
    private var store: [UUID: Appeal] = [:]

    func findById(_ id: UUID) -> Appeal? { store[id] }

    func findById(_ id: UUID, siteId: String) -> Appeal? {
        guard let appeal = store[id], appeal.siteId == siteId else { return nil }
        return appeal
    }

    func findByExceptionId(_ exceptionId: UUID) -> [Appeal] {
        store.values.filter { $0.exceptionId == exceptionId }
    }

    func findByExceptionId(_ exceptionId: UUID, siteId: String) -> [Appeal] {
        store.values.filter { $0.exceptionId == exceptionId && $0.siteId == siteId }
    }

    func findByStatus(_ status: AppealStatus) -> [Appeal] {
        store.values.filter { $0.status == status }
    }

    func findByStatus(_ status: AppealStatus, siteId: String) -> [Appeal] {
        store.values.filter { $0.status == status && $0.siteId == siteId }
    }

    func findByReviewerId(_ reviewerId: UUID) -> [Appeal] {
        store.values.filter { $0.reviewerId == reviewerId }
    }

    func findAll() -> [Appeal] { Array(store.values) }

    func findBySiteId(_ siteId: String) -> [Appeal] {
        store.values.filter { $0.siteId == siteId }
    }

    func save(_ appeal: Appeal) throws { store[appeal.id] = appeal }

    func delete(_ id: UUID) throws { store.removeValue(forKey: id) }
}
