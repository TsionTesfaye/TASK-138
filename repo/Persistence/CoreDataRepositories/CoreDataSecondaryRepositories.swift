import Foundation
import CoreData

// MARK: - Note

final class CoreDataNoteRepository: NoteRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDNote"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Note? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Note(mo: $0) }
    }
    func findByEntity(entityId: UUID, entityType: String) -> [Note] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@", entityId as CVarArg, entityType),
            context: context).map { Note(mo: $0) }
    }
    func findAll() -> [Note] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Note(mo: $0) }
    }
    func save(_ note: Note) throws {
        try CoreDataHelpers.upsert(id: note.id, entityName: entityName, context: context) { mo in note.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - Tag + TagAssignment

final class CoreDataTagRepository: TagRepository {
    private let context: NSManagedObjectContext
    private let tagEntity = "CDTag"
    private let assignEntity = "CDTagAssignment"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Tag? {
        CoreDataHelpers.findById(id, entityName: tagEntity, context: context).map { Tag(mo: $0) }
    }
    func findByName(_ name: String) -> Tag? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        return CoreDataHelpers.fetch(entityName: tagEntity,
            predicate: NSPredicate(format: "name == %@", normalized), context: context
        ).first.map { Tag(mo: $0) }
    }
    func findAll() -> [Tag] {
        CoreDataHelpers.fetch(entityName: tagEntity, context: context).map { Tag(mo: $0) }
    }
    func save(_ tag: Tag) throws {
        try CoreDataHelpers.upsert(id: tag.id, entityName: tagEntity, context: context) { mo in tag.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: tagEntity, context: context) }

    func findAssignments(entityId: UUID, entityType: String) -> [TagAssignment] {
        CoreDataHelpers.fetch(entityName: assignEntity,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@", entityId as CVarArg, entityType),
            context: context).map { TagAssignment(mo: $0) }
    }
    func findAssignmentsByTag(_ tagId: UUID) -> [TagAssignment] {
        CoreDataHelpers.fetch(entityName: assignEntity,
            predicate: NSPredicate(format: "tagId == %@", tagId as CVarArg), context: context
        ).map { TagAssignment(mo: $0) }
    }
    func saveAssignment(_ assignment: TagAssignment) throws {
        // Check for duplicate
        let existing = CoreDataHelpers.fetch(entityName: assignEntity,
            predicate: NSPredicate(format: "tagId == %@ AND entityId == %@ AND entityType == %@",
                assignment.tagId as CVarArg, assignment.entityId as CVarArg, assignment.entityType),
            context: context)
        guard existing.isEmpty else { return }
        let mo = NSEntityDescription.insertNewObject(forEntityName: assignEntity, into: context)
        assignment.apply(to: mo)
        try context.save()
    }
    func deleteAssignment(tagId: UUID, entityId: UUID, entityType: String) throws {
        let results = CoreDataHelpers.fetch(entityName: assignEntity,
            predicate: NSPredicate(format: "tagId == %@ AND entityId == %@ AND entityType == %@",
                tagId as CVarArg, entityId as CVarArg, entityType),
            context: context)
        for mo in results { context.delete(mo) }
        try context.save()
    }
}

// MARK: - Reminder

final class CoreDataReminderRepository: ReminderRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDReminder"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> Reminder? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { Reminder(mo: $0) }
    }
    func findByEntity(entityId: UUID, entityType: String) -> [Reminder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@", entityId as CVarArg, entityType),
            context: context).map { Reminder(mo: $0) }
    }
    func findDueReminders(before date: Date) -> [Reminder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND dueAt <= %@", ReminderStatus.pending.rawValue, date as CVarArg),
            context: context).map { Reminder(mo: $0) }
    }
    func findPendingByEntity(entityId: UUID, entityType: String) -> [Reminder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "entityId == %@ AND entityType == %@ AND status == %@",
                entityId as CVarArg, entityType, ReminderStatus.pending.rawValue),
            context: context).map { Reminder(mo: $0) }
    }
    func findAll() -> [Reminder] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { Reminder(mo: $0) }
    }
    func save(_ reminder: Reminder) throws {
        try CoreDataHelpers.upsert(id: reminder.id, entityName: entityName, context: context) { mo in reminder.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - PoolOrder

final class CoreDataPoolOrderRepository: PoolOrderRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDPoolOrder"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> PoolOrder? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { PoolOrder(mo: $0) }
    }
    func findById(_ id: UUID, siteId: String) -> PoolOrder? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "id == %@ AND siteId == %@", id as CVarArg, siteId),
            context: context).first.map { PoolOrder(mo: $0) }
    }
    func findByStatus(_ status: PoolOrderStatus) -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { PoolOrder(mo: $0) }
    }
    func findActiveInTimeWindow(start: Date, end: Date) -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND startTime <= %@ AND endTime >= %@",
                PoolOrderStatus.active.rawValue, end as CVarArg, start as CVarArg),
            context: context).map { PoolOrder(mo: $0) }
    }
    func findActiveInTimeWindow(start: Date, end: Date, siteId: String) -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND startTime <= %@ AND endTime >= %@ AND siteId == %@",
                PoolOrderStatus.active.rawValue, end as CVarArg, start as CVarArg, siteId),
            context: context).map { PoolOrder(mo: $0) }
    }
    func findExpiredBefore(_ date: Date) -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@ AND endTime < %@",
                PoolOrderStatus.active.rawValue, date as CVarArg),
            context: context).map { PoolOrder(mo: $0) }
    }
    func findAll() -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { PoolOrder(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [PoolOrder] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { PoolOrder(mo: $0) }
    }
    func save(_ order: PoolOrder) throws {
        try CoreDataHelpers.upsert(id: order.id, entityName: entityName, context: context) { mo in order.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - RouteSegment

final class CoreDataRouteSegmentRepository: RouteSegmentRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDRouteSegment"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> RouteSegment? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { RouteSegment(mo: $0) }
    }
    func findByPoolOrderId(_ poolOrderId: UUID) -> [RouteSegment] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "poolOrderId == %@", poolOrderId as CVarArg), context: context
        ).map { RouteSegment(mo: $0) }.sorted { $0.sequence < $1.sequence }
    }
    func save(_ segment: RouteSegment) throws {
        try CoreDataHelpers.upsert(id: segment.id, entityName: entityName, context: context) { mo in segment.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - CountTask

final class CoreDataCountTaskRepository: CountTaskRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDCountTask"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> CountTask? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { CountTask(mo: $0) }
    }
    func findByAssignedTo(_ userId: UUID) -> [CountTask] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "assignedTo == %@", userId as CVarArg), context: context
        ).map { CountTask(mo: $0) }
    }
    func findByStatus(_ status: CountTaskStatus) -> [CountTask] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "status == %@", status.rawValue), context: context
        ).map { CountTask(mo: $0) }
    }
    func findAll() -> [CountTask] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { CountTask(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [CountTask] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { CountTask(mo: $0) }
    }
    func save(_ task: CountTask) throws {
        try CoreDataHelpers.upsert(id: task.id, entityName: entityName, context: context) { mo in task.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - CountBatch

final class CoreDataCountBatchRepository: CountBatchRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDCountBatch"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> CountBatch? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { CountBatch(mo: $0) }
    }
    func findByTaskId(_ taskId: UUID) -> [CountBatch] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "taskId == %@", taskId as CVarArg), context: context
        ).map { CountBatch(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [CountBatch] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { CountBatch(mo: $0) }
    }
    func save(_ batch: CountBatch) throws {
        try CoreDataHelpers.upsert(id: batch.id, entityName: entityName, context: context) { mo in batch.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - CheckIn

final class CoreDataCheckInRepository: CheckInRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDCheckIn"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> CheckIn? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { CheckIn(mo: $0) }
    }
    func findByUserId(_ userId: UUID) -> [CheckIn] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "userId == %@", userId as CVarArg), context: context
        ).map { CheckIn(mo: $0) }
    }
    func findByUserIdInTimeRange(userId: UUID, start: Date, end: Date) -> [CheckIn] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "userId == %@ AND timestamp >= %@ AND timestamp <= %@",
                userId as CVarArg, start as CVarArg, end as CVarArg),
            context: context).map { CheckIn(mo: $0) }
    }
    func findInTimeRange(start: Date, end: Date) -> [CheckIn] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp <= %@",
                start as CVarArg, end as CVarArg),
            context: context).map { CheckIn(mo: $0) }
    }
    func findAll() -> [CheckIn] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { CheckIn(mo: $0) }
    }
    func findBySiteId(_ siteId: String) -> [CheckIn] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "siteId == %@", siteId), context: context
        ).map { CheckIn(mo: $0) }
    }
    func save(_ checkIn: CheckIn) throws {
        try CoreDataHelpers.upsert(id: checkIn.id, entityName: entityName, context: context) { mo in checkIn.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - BusinessHoursConfig

final class CoreDataBusinessHoursConfigRepository: BusinessHoursConfigRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDBusinessHoursConfig"
    init(context: NSManagedObjectContext) { self.context = context }

    func get() -> BusinessHoursConfig {
        let results = CoreDataHelpers.fetch(entityName: entityName, context: context)
        if let mo = results.first {
            return BusinessHoursConfig(mo: mo)
        }
        return .default
    }

    func save(_ config: BusinessHoursConfig) throws {
        try CoreDataHelpers.upsert(id: config.id, entityName: entityName, context: context) { mo in config.apply(to: mo) }
    }
}

// MARK: - CarpoolMatch

final class CoreDataCarpoolMatchRepository: CarpoolMatchRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDCarpoolMatch"
    init(context: NSManagedObjectContext) { self.context = context }

    func findById(_ id: UUID) -> CarpoolMatch? {
        CoreDataHelpers.findById(id, entityName: entityName, context: context).map { CarpoolMatch(mo: $0) }
    }
    func findByRequestOrderId(_ orderId: UUID) -> [CarpoolMatch] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "requestOrderId == %@", orderId as CVarArg), context: context
        ).map { CarpoolMatch(mo: $0) }
    }
    func findByOfferOrderId(_ orderId: UUID) -> [CarpoolMatch] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "offerOrderId == %@", orderId as CVarArg), context: context
        ).map { CarpoolMatch(mo: $0) }
    }
    func findAcceptedByOrderId(_ orderId: UUID) -> CarpoolMatch? {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "(requestOrderId == %@ OR offerOrderId == %@) AND accepted == YES",
                orderId as CVarArg, orderId as CVarArg), context: context
        ).first.map { CarpoolMatch(mo: $0) }
    }
    func findAll() -> [CarpoolMatch] {
        CoreDataHelpers.fetch(entityName: entityName, context: context).map { CarpoolMatch(mo: $0) }
    }
    func save(_ match: CarpoolMatch) throws {
        try CoreDataHelpers.upsert(id: match.id, entityName: entityName, context: context) { mo in match.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - PermissionScope

final class CoreDataPermissionScopeRepository: PermissionScopeRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDPermissionScope"
    init(context: NSManagedObjectContext) { self.context = context }

    func findByUserId(_ userId: UUID) -> [PermissionScope] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "userId == %@", userId as CVarArg), context: context
        ).map { PermissionScope(mo: $0) }
    }
    func findByUserIdAndSiteAndFunction(userId: UUID, site: String, functionKey: String, at date: Date) -> [PermissionScope] {
        CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "userId == %@ AND site == %@ AND functionKey == %@ AND validFrom <= %@ AND validTo >= %@",
                userId as CVarArg, site, functionKey, date as CVarArg, date as CVarArg),
            context: context).map { PermissionScope(mo: $0) }
    }
    func save(_ scope: PermissionScope) throws {
        try CoreDataHelpers.upsert(id: scope.id, entityName: entityName, context: context) { mo in scope.apply(to: mo) }
    }
    func delete(_ id: UUID) throws { try CoreDataHelpers.delete(id: id, entityName: entityName, context: context) }
}

// MARK: - OperationLog

final class CoreDataOperationLogRepository: OperationLogRepository {
    private let context: NSManagedObjectContext
    private let entityName = "CDOperationLog"
    init(context: NSManagedObjectContext) { self.context = context }

    func exists(_ operationId: UUID) -> Bool {
        let results = CoreDataHelpers.fetch(entityName: entityName,
            predicate: NSPredicate(format: "operationId == %@", operationId as CVarArg), context: context)
        return !results.isEmpty
    }
    func save(_ operationId: UUID) throws {
        let mo = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        mo.setValue(operationId, forKey: "operationId")
        mo.setValue(Date(), forKey: "createdAt")
        try context.save()
    }
}
