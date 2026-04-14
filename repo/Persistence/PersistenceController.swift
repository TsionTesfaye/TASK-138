import Foundation
import CoreData

/// Core Data stack for DealerOps.
/// Builds the managed object model programmatically so it works without .xcdatamodeld.
final class PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    /// Use inMemory for tests
    init(inMemory: Bool = false) {
        let model = PersistenceController.buildModel()
        container = NSPersistentContainer(name: "DealerOps", managedObjectModel: model)
        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [desc]
        }
        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                loadError = error
            }
        }
        if let error = loadError {
            ServiceLogger.persistenceError(ServiceLogger.persistence, operation: "loadPersistentStores", error: error)
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }

    func save(_ context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    // MARK: - Programmatic Model

    static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let userEntity = buildUserEntity()
        let permScopeEntity = buildPermissionScopeEntity()
        let leadEntity = buildLeadEntity()
        let appointmentEntity = buildAppointmentEntity()
        let noteEntity = buildNoteEntity()
        let tagEntity = buildTagEntity()
        let tagAssignmentEntity = buildTagAssignmentEntity()
        let reminderEntity = buildReminderEntity()
        let poolOrderEntity = buildPoolOrderEntity()
        let routeSegmentEntity = buildRouteSegmentEntity()
        let inventoryItemEntity = buildInventoryItemEntity()
        let countTaskEntity = buildCountTaskEntity()
        let countBatchEntity = buildCountBatchEntity()
        let countEntryEntity = buildCountEntryEntity()
        let varianceEntity = buildVarianceEntity()
        let adjustmentOrderEntity = buildAdjustmentOrderEntity()
        let exceptionCaseEntity = buildExceptionCaseEntity()
        let checkInEntity = buildCheckInEntity()
        let appealEntity = buildAppealEntity()
        let evidenceFileEntity = buildEvidenceFileEntity()
        let auditLogEntity = buildAuditLogEntity()
        let businessHoursEntity = buildBusinessHoursConfigEntity()
        let carpoolMatchEntity = buildCarpoolMatchEntity()
        let operationLogEntity = buildOperationLogEntity()

        model.entities = [
            userEntity, permScopeEntity, leadEntity, appointmentEntity,
            noteEntity, tagEntity, tagAssignmentEntity, reminderEntity,
            poolOrderEntity, routeSegmentEntity,
            inventoryItemEntity, countTaskEntity, countBatchEntity, countEntryEntity,
            varianceEntity, adjustmentOrderEntity,
            exceptionCaseEntity, checkInEntity, appealEntity,
            evidenceFileEntity, auditLogEntity,
            businessHoursEntity, carpoolMatchEntity, operationLogEntity
        ]

        return model
    }

    // MARK: - Entity Builders

    private static func attr(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = optional
        if let dv = defaultValue { a.defaultValue = dv }
        return a
    }

    private static func buildUserEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDUser"
        e.managedObjectClassName = "CDUser"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("username", .stringAttributeType),
            attr("passwordHash", .stringAttributeType),
            attr("passwordSalt", .stringAttributeType),
            attr("role", .stringAttributeType),
            attr("biometricEnabled", .booleanAttributeType, defaultValue: false),
            attr("failedAttempts", .integer32AttributeType, defaultValue: 0),
            attr("lastFailedAttempt", .dateAttributeType, optional: true),
            attr("lockoutUntil", .dateAttributeType, optional: true),
            attr("createdAt", .dateAttributeType),
            attr("isActive", .booleanAttributeType, defaultValue: true),
        ]
        return e
    }

    private static func buildPermissionScopeEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDPermissionScope"
        e.managedObjectClassName = "CDPermissionScope"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("userId", .UUIDAttributeType),
            attr("site", .stringAttributeType),
            attr("functionKey", .stringAttributeType),
            attr("validFrom", .dateAttributeType),
            attr("validTo", .dateAttributeType),
        ]
        return e
    }

    private static func buildLeadEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDLead"
        e.managedObjectClassName = "CDLead"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("leadType", .stringAttributeType),
            attr("status", .stringAttributeType),
            attr("customerName", .stringAttributeType),
            attr("phone", .stringAttributeType),
            attr("vehicleInterest", .stringAttributeType),
            attr("preferredContactWindow", .stringAttributeType),
            attr("consentNotes", .stringAttributeType),
            attr("assignedTo", .UUIDAttributeType, optional: true),
            attr("createdAt", .dateAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("slaDeadline", .dateAttributeType, optional: true),
            attr("lastQualifyingAction", .dateAttributeType, optional: true),
            attr("archivedAt", .dateAttributeType, optional: true),
        ]
        return e
    }

    private static func buildAppointmentEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDAppointment"
        e.managedObjectClassName = "CDAppointment"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("leadId", .UUIDAttributeType),
            attr("startTime", .dateAttributeType),
            attr("status", .stringAttributeType),
        ]
        return e
    }

    private static func buildNoteEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDNote"
        e.managedObjectClassName = "CDNote"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("entityId", .UUIDAttributeType),
            attr("entityType", .stringAttributeType),
            attr("content", .stringAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("createdBy", .UUIDAttributeType),
        ]
        return e
    }

    private static func buildTagEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDTag"
        e.managedObjectClassName = "CDTag"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("name", .stringAttributeType),
        ]
        return e
    }

    private static func buildTagAssignmentEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDTagAssignment"
        e.managedObjectClassName = "CDTagAssignment"
        e.properties = [
            attr("tagId", .UUIDAttributeType),
            attr("entityId", .UUIDAttributeType),
            attr("entityType", .stringAttributeType),
        ]
        return e
    }

    private static func buildReminderEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDReminder"
        e.managedObjectClassName = "CDReminder"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("entityId", .UUIDAttributeType),
            attr("entityType", .stringAttributeType),
            attr("createdBy", .UUIDAttributeType),
            attr("dueAt", .dateAttributeType),
            attr("status", .stringAttributeType),
        ]
        return e
    }

    private static func buildPoolOrderEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDPoolOrder"
        e.managedObjectClassName = "CDPoolOrder"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("originLat", .doubleAttributeType),
            attr("originLng", .doubleAttributeType),
            attr("destinationLat", .doubleAttributeType),
            attr("destinationLng", .doubleAttributeType),
            attr("startTime", .dateAttributeType),
            attr("endTime", .dateAttributeType),
            attr("seatsAvailable", .integer32AttributeType),
            attr("vehicleType", .stringAttributeType),
            attr("createdBy", .UUIDAttributeType),
            attr("status", .stringAttributeType),
        ]
        return e
    }

    private static func buildRouteSegmentEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDRouteSegment"
        e.managedObjectClassName = "CDRouteSegment"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("poolOrderId", .UUIDAttributeType),
            attr("sequence", .integer32AttributeType),
            attr("locationLat", .doubleAttributeType),
            attr("locationLng", .doubleAttributeType),
        ]
        return e
    }

    private static func buildInventoryItemEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDInventoryItem"
        e.managedObjectClassName = "CDInventoryItem"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("identifier", .stringAttributeType),
            attr("expectedQty", .integer32AttributeType),
            attr("location", .stringAttributeType),
            attr("custodian", .stringAttributeType),
        ]
        return e
    }

    private static func buildCountTaskEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDCountTask"
        e.managedObjectClassName = "CDCountTask"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("assignedTo", .UUIDAttributeType),
            attr("status", .stringAttributeType),
        ]
        return e
    }

    private static func buildCountBatchEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDCountBatch"
        e.managedObjectClassName = "CDCountBatch"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("taskId", .UUIDAttributeType),
            attr("createdAt", .dateAttributeType),
        ]
        return e
    }

    private static func buildCountEntryEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDCountEntry"
        e.managedObjectClassName = "CDCountEntry"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("batchId", .UUIDAttributeType),
            attr("itemId", .UUIDAttributeType),
            attr("countedQty", .integer32AttributeType),
            attr("countedLocation", .stringAttributeType),
            attr("countedCustodian", .stringAttributeType),
        ]
        return e
    }

    private static func buildVarianceEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDVariance"
        e.managedObjectClassName = "CDVariance"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("itemId", .UUIDAttributeType),
            attr("expectedQty", .integer32AttributeType),
            attr("countedQty", .integer32AttributeType),
            attr("type", .stringAttributeType),
            attr("requiresApproval", .booleanAttributeType),
            attr("approved", .booleanAttributeType, defaultValue: false),
        ]
        return e
    }

    private static func buildAdjustmentOrderEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDAdjustmentOrder"
        e.managedObjectClassName = "CDAdjustmentOrder"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("varianceId", .UUIDAttributeType),
            attr("approvedBy", .UUIDAttributeType, optional: true),
            attr("createdAt", .dateAttributeType),
            attr("status", .stringAttributeType),
        ]
        return e
    }

    private static func buildExceptionCaseEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDExceptionCase"
        e.managedObjectClassName = "CDExceptionCase"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("type", .stringAttributeType),
            attr("sourceId", .UUIDAttributeType),
            attr("reason", .stringAttributeType),
            attr("status", .stringAttributeType),
            attr("createdAt", .dateAttributeType),
        ]
        return e
    }

    private static func buildCheckInEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDCheckIn"
        e.managedObjectClassName = "CDCheckIn"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("userId", .UUIDAttributeType),
            attr("timestamp", .dateAttributeType),
            attr("locationLat", .doubleAttributeType),
            attr("locationLng", .doubleAttributeType),
        ]
        return e
    }

    private static func buildAppealEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDAppeal"
        e.managedObjectClassName = "CDAppeal"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("exceptionId", .UUIDAttributeType),
            attr("status", .stringAttributeType),
            attr("reviewerId", .UUIDAttributeType, optional: true),
            attr("submittedBy", .UUIDAttributeType),
            attr("reason", .stringAttributeType),
            attr("resolvedAt", .dateAttributeType, optional: true),
        ]
        return e
    }

    private static func buildEvidenceFileEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDEvidenceFile"
        e.managedObjectClassName = "CDEvidenceFile"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("siteId", .stringAttributeType),
            attr("entityId", .UUIDAttributeType),
            attr("entityType", .stringAttributeType),
            attr("filePath", .stringAttributeType),
            attr("fileType", .stringAttributeType),
            attr("fileSize", .integer64AttributeType),
            attr("fileHash", .stringAttributeType),
            attr("createdAt", .dateAttributeType),
            attr("pinnedByAdmin", .booleanAttributeType, defaultValue: false),
        ]
        return e
    }

    private static func buildAuditLogEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDAuditLog"
        e.managedObjectClassName = "CDAuditLog"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("actorId", .UUIDAttributeType),
            attr("action", .stringAttributeType),
            attr("entityId", .UUIDAttributeType),
            attr("timestamp", .dateAttributeType),
            attr("tombstone", .booleanAttributeType, defaultValue: false),
            attr("deletedAt", .dateAttributeType, optional: true),
            attr("deletedBy", .UUIDAttributeType, optional: true),
        ]
        return e
    }

    private static func buildBusinessHoursConfigEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDBusinessHoursConfig"
        e.managedObjectClassName = "CDBusinessHoursConfig"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("startHour", .integer32AttributeType, defaultValue: 9),
            attr("endHour", .integer32AttributeType, defaultValue: 17),
            attr("workingDays", .stringAttributeType, defaultValue: "2,3,4,5,6"),
        ]
        return e
    }

    private static func buildCarpoolMatchEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDCarpoolMatch"
        e.managedObjectClassName = "CDCarpoolMatch"
        e.properties = [
            attr("id", .UUIDAttributeType),
            attr("requestOrderId", .UUIDAttributeType),
            attr("offerOrderId", .UUIDAttributeType),
            attr("matchScore", .doubleAttributeType),
            attr("detourMiles", .doubleAttributeType),
            attr("timeOverlapMinutes", .doubleAttributeType),
            attr("accepted", .booleanAttributeType, defaultValue: false),
            attr("createdAt", .dateAttributeType),
        ]
        return e
    }

    private static func buildOperationLogEntity() -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = "CDOperationLog"
        e.managedObjectClassName = "CDOperationLog"
        e.properties = [
            attr("operationId", .UUIDAttributeType),
            attr("createdAt", .dateAttributeType),
        ]
        return e
    }
}
