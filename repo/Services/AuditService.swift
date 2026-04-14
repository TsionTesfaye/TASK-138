import Foundation
import os.log

/// design.md 4.10, 5.2
/// Append-only audit logging with tombstone support.
/// Every security-relevant action must be logged here.
final class AuditService {

    private let auditLogRepo: AuditLogRepository
    private static let logger = Logger(subsystem: "com.dealerops", category: "Audit")

    init(auditLogRepo: AuditLogRepository) {
        self.auditLogRepo = auditLogRepo
    }

    // MARK: - Logging

    /// Append an audit log entry. This is the sole write path for audit logs.
    /// design.md 5.2: Missing audit entry = system violation
    func log(actorId: UUID, action: String, entityId: UUID) {
        let entry = AuditLog(
            id: UUID(),
            actorId: actorId,
            action: action,
            entityId: entityId,
            timestamp: Date(),
            tombstone: false,
            deletedAt: nil,
            deletedBy: nil
        )
        do {
            try auditLogRepo.save(entry)
        } catch {
            AuditService.logger.error("CRITICAL: Failed to persist audit log action=\(action) error=\(error.localizedDescription)")
        }
    }

    // MARK: - Tombstone Deletion

    /// "Delete" a log by marking it as tombstone. The entry remains in storage.
    /// design.md: deleted logs become tombstones, not silent removals
    func deleteLog(logId: UUID, deletedBy actorId: UUID) -> ServiceResult<Void> {
        guard var entry = auditLogRepo.findById(logId) else {
            return .failure(.entityNotFound)
        }
        guard !entry.tombstone else {
            return .success(())
        }
        entry.tombstone = true
        entry.deletedAt = Date()
        entry.deletedBy = actorId
        do {
            try auditLogRepo.save(entry)
            // Log the deletion itself
            log(actorId: actorId, action: "audit_log_tombstoned", entityId: logId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "AUDIT_SAVE_FAIL", message: error.localizedDescription))
        }
    }

    // MARK: - Retention

    /// Purge tombstoned entries older than 1 year.
    /// design.md: retained for 1 year
    func purgeOldTombstones(olderThan date: Date) -> Int {
        let old = auditLogRepo.findTombstonesOlderThan(date)
        var purged = 0
        for entry in old {
            do {
                try auditLogRepo.delete(entry.id)
                purged += 1
            } catch {
                AuditService.logger.error("Failed to purge tombstone \(entry.id): \(error.localizedDescription)")
            }
        }
        return purged
    }

    // MARK: - Query

    func logsForEntity(_ entityId: UUID) -> [AuditLog] {
        auditLogRepo.findByEntityId(entityId)
    }

    func logsForActor(_ actorId: UUID) -> [AuditLog] {
        auditLogRepo.findByActorId(actorId)
    }

    func allLogs() -> [AuditLog] {
        auditLogRepo.findAll()
    }
}
