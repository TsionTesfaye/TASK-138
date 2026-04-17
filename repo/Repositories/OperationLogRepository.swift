import Foundation

/// Supports idempotency
protocol OperationLogRepository {
    func exists(_ operationId: UUID) -> Bool
    func save(_ operationId: UUID) throws
}

final class InMemoryOperationLogRepository: OperationLogRepository {
    private var store: Set<UUID> = []

    func exists(_ operationId: UUID) -> Bool {
        store.contains(operationId)
    }

    func save(_ operationId: UUID) throws {
        store.insert(operationId)
    }
}
