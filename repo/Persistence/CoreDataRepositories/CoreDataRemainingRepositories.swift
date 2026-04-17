import Foundation
import CoreData

// MARK: - Role

final class CoreDataRoleRepository: RoleRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDRole"
    init(context: NSManagedObjectContext) { self.context = context }

    func findAll() -> [Role] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Role(mo: $0) }
    }
    func findById(_ id: UUID) -> Role? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Role(mo: $0) }
    }
    func findByName(_ name: UserRole) -> Role? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "name == %@", name.rawValue), context: context
        ).first.map { Role(mo: $0) }
    }
    func save(_ role: Role) throws {
        try CoreDataHelpers.upsert(id: role.id, entityName: entityName, context: context) { mo in role.apply(to: mo) }
    }
}

// MARK: - CountEntry

final class CoreDataCountEntryRepository: CountEntryRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDCountEntry"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> CountEntry? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { CountEntry(mo: $0) }
    }
    func findByBatchId(_ batchId: UUID) -> [CountEntry] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "batchId == %@", batchId as CVarArg), context: context
        ).map { CountEntry(mo: $0) }
    }
    func findByItemId(_ itemId: UUID) -> [CountEntry] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "itemId == %@", itemId as CVarArg), context: context
        ).map { CountEntry(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [CountEntry] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { CountEntry(mo: $0) }
    }
    func save(_ entry: CountEntry) throws {
        try CoreDataHelpers.upsert(id: entry.id, entityName: entityName, context: context) { mo in entry.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - Variance

final class CoreDataVarianceRepository: VarianceRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDVariance"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Variance? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Variance(mo: $0) }
    }
    func findByItemId(_ itemId: UUID) -> [Variance] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "itemId == %@", itemId as CVarArg), context: context
        ).map { Variance(mo: $0) }
    }
    func findPendingApproval() -> [Variance] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "requiresApproval == YES AND approved == NO"), context: context
        ).map { Variance(mo: $0) }
    }
    func findAll() -> [Variance] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Variance(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [Variance] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { Variance(mo: $0) }
    }
    func save(_ variance: Variance) throws {
        try CoreDataHelpers.upsert(id: variance.id, entityName: entityName, context: context) { mo in variance.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - AdjustmentOrder

final class CoreDataAdjustmentOrderRepository: AdjustmentOrderRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDAdjustmentOrder"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> AdjustmentOrder? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { AdjustmentOrder(mo: $0) }
    }
    func findByVarianceId(_ varianceId: UUID) -> AdjustmentOrder? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "varianceId == %@", varianceId as CVarArg), context: context
        ).first.map { AdjustmentOrder(mo: $0) }
    }
    func findByStatus(_ status: AdjustmentOrderStatus) -> [AdjustmentOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { AdjustmentOrder(mo: $0) }
    }
    func findAll() -> [AdjustmentOrder] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { AdjustmentOrder(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [AdjustmentOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { AdjustmentOrder(mo: $0) }
    }
    func save(_ order: AdjustmentOrder) throws {
        try CoreDataHelpers.upsert(id: order.id, entityName: entityName, context: context) { mo in order.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - ExceptionCase

final class CoreDataExceptionCaseRepository: ExceptionCaseRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDExceptionCase"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> ExceptionCase? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { ExceptionCase(mo: $0) }
    }
    func findById(_ id: UUID, siteId: String) -> ExceptionCase? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "id == %@ AND siteId == %@", id as CVarArg, siteId),
            context: context).first.map { ExceptionCase(mo: $0) }
    }
    func findByType(_ type: ExceptionType) -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "type == %@", type.rawValue), context: context
        ).map { ExceptionCase(mo: $0) }
    }
    func findByStatus(_ status: ExceptionCaseStatus) -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { ExceptionCase(mo: $0) }
    }
    func findByStatus(_ status: ExceptionCaseStatus, siteId: String) -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND siteId == %@", status.rawValue, siteId),
            context: context).map { ExceptionCase(mo: $0) }
    }
    func findBySourceId(_ sourceId: UUID) -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "sourceId == %@", sourceId as CVarArg), context: context
        ).map { ExceptionCase(mo: $0) }
    }
    func findAll() -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { ExceptionCase(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [ExceptionCase] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { ExceptionCase(mo: $0) }
    }
    func save(_ ec: ExceptionCase) throws {
        try CoreDataHelpers.upsert(id: ec.id, entityName: entityName, context: context) { mo in ec.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - Appeal

final class CoreDataAppealRepository: AppealRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDAppeal"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Appeal? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Appeal(mo: $0) }
    }
    func findById(_ id: UUID, siteId: String) -> Appeal? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "id == %@ AND siteId == %@", id as CVarArg, siteId),
            context: context).first.map { Appeal(mo: $0) }
    }
    func findByExceptionId(_ exceptionId: UUID) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "exceptionId == %@", exceptionId as CVarArg), context: context
        ).map { Appeal(mo: $0) }
    }
    func findByExceptionId(_ exceptionId: UUID, siteId: String) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "exceptionId == %@ AND siteId == %@", exceptionId as CVarArg, siteId),
            context: context).map { Appeal(mo: $0) }
    }
    func findByStatus(_ status: AppealStatus) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { Appeal(mo: $0) }
    }
    func findByStatus(_ status: AppealStatus, siteId: String) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND siteId == %@", status.rawValue, siteId),
            context: context).map { Appeal(mo: $0) }
    }
    func findByReviewerId(_ reviewerId: UUID) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "reviewerId == %@", reviewerId as CVarArg), context: context
        ).map { Appeal(mo: $0) }
    }
    func findAll() -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Appeal(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [Appeal] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { Appeal(mo: $0) }
    }
    func save(_ appeal: Appeal) throws {
        try CoreDataHelpers.upsert(id: appeal.id, entityName: entityName, context: context) { mo in appeal.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - EvidenceFile

final class CoreDataEvidenceFileRepository: EvidenceFileRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDEvidenceFile"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> EvidenceFile? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { EvidenceFile(mo: $0) }
    }
    func findById(_ id: UUID, siteId: String) -> EvidenceFile? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "id == %@ AND siteId == %@", id as CVarArg, siteId),
            context: context).first.map { EvidenceFile(mo: $0) }
    }
    func findByEntity(entityId: UUID, entityType: String) -> [EvidenceFile] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@", entityId as CVarArg, entityType),
            context: context
        ).map { EvidenceFile(mo: $0) }
    }
    func findByEntity(entityId: UUID, entityType: String, siteId: String) -> [EvidenceFile] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@ AND siteId == %@", entityId as CVarArg, entityType, siteId),
            context: context
        ).map { EvidenceFile(mo: $0) }
    }
    func findUnpinnedOlderThan(_ date: Date) -> [EvidenceFile] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "pinnedByAdmin == NO AND createdAt < %@", date as CVarArg), context: context
        ).map { EvidenceFile(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [EvidenceFile] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { EvidenceFile(mo: $0) }
    }
    func findAll() -> [EvidenceFile] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { EvidenceFile(mo: $0) }
    }
    func save(_ file: EvidenceFile) throws {
        try CoreDataHelpers.upsert(id: file.id, entityName: entityName, context: context) { mo in file.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - AuditLog

final class CoreDataAuditLogRepository: AuditLogRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDAuditLog"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> AuditLog? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { AuditLog(mo: $0) }
    }
    func findByEntityId(_ entityId: UUID) -> [AuditLog] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND tombstone == NO", entityId as CVarArg), context: context
        ).map { AuditLog(mo: $0) }
    }
    func findByActorId(_ actorId: UUID) -> [AuditLog] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "actorId == %@ AND tombstone == NO", actorId as CVarArg), context: context
        ).map { AuditLog(mo: $0) }
    }
    func findTombstonesOlderThan(_ date: Date) -> [AuditLog] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "tombstone == YES AND deletedAt != nil AND deletedAt < %@", date as CVarArg),
            context: context
        ).map { AuditLog(mo: $0) }
    }
    func findAll() -> [AuditLog] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { AuditLog(mo: $0) }
    }
    func save(_ log: AuditLog) throws {
        try CoreDataHelpers.upsert(id: log.id, entityName: entityName, context: context) { mo in log.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}
