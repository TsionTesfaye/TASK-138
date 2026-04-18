import Foundation
import CoreData

// MARK: - Generic helpers

extension NSManagedObject {
    func uuid(_ key: String) -> UUID {
        guard let v = value(forKey: key) as? UUID else {
            ServiceLogger.persistenceError(ServiceLogger.persistence, operation: "read_uuid_\(key)_on_\(entity.name ?? "?")", error: NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Field '\(key)' is not UUID"]))
            return UUID()
        }
        return v
    }
    func optUUID(_ key: String) -> UUID? { value(forKey: key) as? UUID }
    func string(_ key: String) -> String {
        guard let v = value(forKey: key) as? String else {
            ServiceLogger.persistenceError(ServiceLogger.persistence, operation: "read_string_\(key)_on_\(entity.name ?? "?")", error: NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Field '\(key)' is not String"]))
            return ""
        }
        return v
    }
    func optString(_ key: String) -> String? { value(forKey: key) as? String }
    func date(_ key: String) -> Date {
        guard let v = value(forKey: key) as? Date else {
            ServiceLogger.persistenceError(ServiceLogger.persistence, operation: "read_date_\(key)_on_\(entity.name ?? "?")", error: NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Field '\(key)' is not Date"]))
            return Date()
        }
        return v
    }
    func optDate(_ key: String) -> Date? { value(forKey: key) as? Date }
    func int32(_ key: String) -> Int {
        guard let v = value(forKey: key) as? Int32 else { return Int(value(forKey: key) as? Int16 ?? 0) }
        return Int(v)
    }
    func int64(_ key: String) -> Int {
        guard let v = value(forKey: key) as? Int64 else { return Int(value(forKey: key) as? Int32 ?? 0) }
        return Int(v)
    }
    func double(_ key: String) -> Double {
        guard let v = value(forKey: key) as? Double else { return 0 }
        return v
    }
    func bool(_ key: String) -> Bool {
        (value(forKey: key) as? Bool) ?? false
    }
}

extension NSManagedObject {
    /// Safely decode a RawRepresentable enum from a stored string, falling back to the first case.
    func enumValue<T: RawRepresentable & CaseIterable>(_ key: String) -> T where T.RawValue == String {
        let raw = string(key)
        if let v = T(rawValue: raw) { return v }
        ServiceLogger.persistenceError(ServiceLogger.persistence, operation: "read_enum_\(key)_on_\(entity.name ?? "?")", error: NSError(domain: "CoreData", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown rawValue '\(raw)' for \(T.self)"]))
        return T.allCases.first!
    }
}

// MARK: - Role Mapping

extension Role {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            name: mo.enumValue("name") as UserRole,
            displayName: mo.string("displayName")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id")
        mo.setValue(name.rawValue, forKey: "name")
        mo.setValue(displayName, forKey: "displayName")
    }
}

// MARK: - User Mapping

extension User {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), username: mo.string("username"),
            passwordHash: mo.string("passwordHash"), passwordSalt: mo.string("passwordSalt"),
            role: mo.enumValue("role") as UserRole,
            biometricEnabled: mo.bool("biometricEnabled"),
            failedAttempts: mo.int32("failedAttempts"),
            lastFailedAttempt: mo.optDate("lastFailedAttempt"),
            lockoutUntil: mo.optDate("lockoutUntil"),
            createdAt: mo.date("createdAt"), isActive: mo.bool("isActive")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(username, forKey: "username")
        mo.setValue(passwordHash, forKey: "passwordHash"); mo.setValue(passwordSalt, forKey: "passwordSalt")
        mo.setValue(role.rawValue, forKey: "role"); mo.setValue(biometricEnabled, forKey: "biometricEnabled")
        mo.setValue(Int32(failedAttempts), forKey: "failedAttempts")
        mo.setValue(lastFailedAttempt, forKey: "lastFailedAttempt")
        mo.setValue(lockoutUntil, forKey: "lockoutUntil")
        mo.setValue(createdAt, forKey: "createdAt"); mo.setValue(isActive, forKey: "isActive")
    }
}

// MARK: - Lead Mapping

extension Lead {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            leadType: mo.enumValue("leadType") as LeadType,
            status: mo.enumValue("status") as LeadStatus,
            customerName: mo.string("customerName"), phone: mo.string("phone"),
            vehicleInterest: mo.string("vehicleInterest"),
            preferredContactWindow: mo.string("preferredContactWindow"),
            consentNotes: mo.string("consentNotes"),
            assignedTo: mo.optUUID("assignedTo"),
            createdAt: mo.date("createdAt"), updatedAt: mo.date("updatedAt"),
            slaDeadline: mo.optDate("slaDeadline"),
            lastQualifyingAction: mo.optDate("lastQualifyingAction"),
            archivedAt: mo.optDate("archivedAt")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(leadType.rawValue, forKey: "leadType")
        mo.setValue(status.rawValue, forKey: "status")
        mo.setValue(customerName, forKey: "customerName"); mo.setValue(phone, forKey: "phone")
        mo.setValue(vehicleInterest, forKey: "vehicleInterest")
        mo.setValue(preferredContactWindow, forKey: "preferredContactWindow")
        mo.setValue(consentNotes, forKey: "consentNotes")
        mo.setValue(assignedTo, forKey: "assignedTo")
        mo.setValue(createdAt, forKey: "createdAt"); mo.setValue(updatedAt, forKey: "updatedAt")
        mo.setValue(slaDeadline, forKey: "slaDeadline")
        mo.setValue(lastQualifyingAction, forKey: "lastQualifyingAction")
        mo.setValue(archivedAt, forKey: "archivedAt")
    }
}

// MARK: - Appointment Mapping

extension Appointment {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            leadId: mo.uuid("leadId"),
            startTime: mo.date("startTime"),
            status: mo.enumValue("status") as AppointmentStatus
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(leadId, forKey: "leadId")
        mo.setValue(startTime, forKey: "startTime"); mo.setValue(status.rawValue, forKey: "status")
    }
}

// MARK: - InventoryItem Mapping

extension InventoryItem {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            identifier: mo.string("identifier"),
            expectedQty: mo.int32("expectedQty"),
            location: mo.string("location"), custodian: mo.string("custodian")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(identifier, forKey: "identifier")
        mo.setValue(Int32(expectedQty), forKey: "expectedQty")
        mo.setValue(location, forKey: "location"); mo.setValue(custodian, forKey: "custodian")
    }
}

// MARK: - CountEntry Mapping

extension CountEntry {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            batchId: mo.uuid("batchId"), itemId: mo.uuid("itemId"),
            countedQty: mo.int32("countedQty"),
            countedLocation: mo.string("countedLocation"),
            countedCustodian: mo.string("countedCustodian")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(batchId, forKey: "batchId")
        mo.setValue(itemId, forKey: "itemId"); mo.setValue(Int32(countedQty), forKey: "countedQty")
        mo.setValue(countedLocation, forKey: "countedLocation")
        mo.setValue(countedCustodian, forKey: "countedCustodian")
    }
}

// MARK: - Variance Mapping

extension Variance {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            itemId: mo.uuid("itemId"),
            expectedQty: mo.int32("expectedQty"), countedQty: mo.int32("countedQty"),
            type: mo.enumValue("type") as VarianceType,
            requiresApproval: mo.bool("requiresApproval"), approved: mo.bool("approved")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(itemId, forKey: "itemId")
        mo.setValue(Int32(expectedQty), forKey: "expectedQty")
        mo.setValue(Int32(countedQty), forKey: "countedQty")
        mo.setValue(type.rawValue, forKey: "type")
        mo.setValue(requiresApproval, forKey: "requiresApproval")
        mo.setValue(approved, forKey: "approved")
    }
}

// MARK: - AdjustmentOrder Mapping

extension AdjustmentOrder {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            varianceId: mo.uuid("varianceId"),
            approvedBy: mo.optUUID("approvedBy"), createdAt: mo.date("createdAt"),
            status: mo.enumValue("status") as AdjustmentOrderStatus
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(varianceId, forKey: "varianceId")
        mo.setValue(approvedBy, forKey: "approvedBy"); mo.setValue(createdAt, forKey: "createdAt")
        mo.setValue(status.rawValue, forKey: "status")
    }
}

// MARK: - ExceptionCase Mapping

extension ExceptionCase {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            type: mo.enumValue("type") as ExceptionType,
            sourceId: mo.uuid("sourceId"), reason: mo.string("reason"),
            status: mo.enumValue("status") as ExceptionCaseStatus,
            createdAt: mo.date("createdAt")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(type.rawValue, forKey: "type")
        mo.setValue(sourceId, forKey: "sourceId"); mo.setValue(reason, forKey: "reason")
        mo.setValue(status.rawValue, forKey: "status"); mo.setValue(createdAt, forKey: "createdAt")
    }
}

// MARK: - Appeal Mapping

extension Appeal {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            exceptionId: mo.uuid("exceptionId"),
            status: mo.enumValue("status") as AppealStatus,
            reviewerId: mo.optUUID("reviewerId"), submittedBy: mo.uuid("submittedBy"),
            reason: mo.string("reason"), resolvedAt: mo.optDate("resolvedAt")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(exceptionId, forKey: "exceptionId")
        mo.setValue(status.rawValue, forKey: "status")
        mo.setValue(reviewerId, forKey: "reviewerId")
        mo.setValue(submittedBy, forKey: "submittedBy")
        mo.setValue(reason, forKey: "reason"); mo.setValue(resolvedAt, forKey: "resolvedAt")
    }
}

// MARK: - EvidenceFile Mapping

extension EvidenceFile {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), siteId: mo.string("siteId"),
            entityId: mo.uuid("entityId"),
            entityType: mo.string("entityType"), filePath: mo.string("filePath"),
            fileType: mo.enumValue("fileType") as EvidenceFileType,
            fileSize: mo.int64("fileSize"), hash: mo.string("fileHash"),
            createdAt: mo.date("createdAt"), pinnedByAdmin: mo.bool("pinnedByAdmin")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId")
        mo.setValue(entityId, forKey: "entityId")
        mo.setValue(entityType, forKey: "entityType"); mo.setValue(filePath, forKey: "filePath")
        mo.setValue(fileType.rawValue, forKey: "fileType")
        mo.setValue(Int64(fileSize), forKey: "fileSize")
        mo.setValue(hash, forKey: "fileHash"); mo.setValue(createdAt, forKey: "createdAt")
        mo.setValue(pinnedByAdmin, forKey: "pinnedByAdmin")
    }
}

// MARK: - AuditLog Mapping

extension AuditLog {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), actorId: mo.uuid("actorId"),
            action: mo.string("action"), entityId: mo.uuid("entityId"),
            timestamp: mo.date("timestamp"), tombstone: mo.bool("tombstone"),
            deletedAt: mo.optDate("deletedAt"), deletedBy: mo.optUUID("deletedBy")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(actorId, forKey: "actorId")
        mo.setValue(action, forKey: "action"); mo.setValue(entityId, forKey: "entityId")
        mo.setValue(timestamp, forKey: "timestamp"); mo.setValue(tombstone, forKey: "tombstone")
        mo.setValue(deletedAt, forKey: "deletedAt"); mo.setValue(deletedBy, forKey: "deletedBy")
    }
}

// MARK: - Note Mapping

extension Note {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), siteId: mo.string("siteId"), entityId: mo.uuid("entityId"),
            entityType: mo.string("entityType"), content: mo.string("content"),
            createdAt: mo.date("createdAt"), createdBy: mo.uuid("createdBy")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId")
        mo.setValue(entityId, forKey: "entityId")
        mo.setValue(entityType, forKey: "entityType"); mo.setValue(content, forKey: "content")
        mo.setValue(createdAt, forKey: "createdAt"); mo.setValue(createdBy, forKey: "createdBy")
    }
}

// MARK: - Tag Mapping

extension Tag {
    init(mo: NSManagedObject) {
        self.init(id: mo.uuid("id"), name: mo.string("name"))
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(name, forKey: "name")
    }
}

extension TagAssignment {
    init(mo: NSManagedObject) {
        self.init(tagId: mo.uuid("tagId"), entityId: mo.uuid("entityId"), entityType: mo.string("entityType"))
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(tagId, forKey: "tagId"); mo.setValue(entityId, forKey: "entityId")
        mo.setValue(entityType, forKey: "entityType")
    }
}

// MARK: - Reminder Mapping

extension Reminder {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), siteId: mo.string("siteId"), entityId: mo.uuid("entityId"),
            entityType: mo.string("entityType"), createdBy: mo.uuid("createdBy"),
            dueAt: mo.date("dueAt"),
            status: mo.enumValue("status") as ReminderStatus
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId")
        mo.setValue(entityId, forKey: "entityId")
        mo.setValue(entityType, forKey: "entityType"); mo.setValue(createdBy, forKey: "createdBy")
        mo.setValue(dueAt, forKey: "dueAt"); mo.setValue(status.rawValue, forKey: "status")
    }
}

// MARK: - PoolOrder Mapping

extension PoolOrder {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            originLat: mo.double("originLat"), originLng: mo.double("originLng"),
            destinationLat: mo.double("destinationLat"), destinationLng: mo.double("destinationLng"),
            startTime: mo.date("startTime"), endTime: mo.date("endTime"),
            seatsAvailable: mo.int32("seatsAvailable"),
            vehicleType: mo.string("vehicleType"),
            createdBy: mo.uuid("createdBy"),
            status: mo.enumValue("status") as PoolOrderStatus
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId")
        mo.setValue(originLat, forKey: "originLat"); mo.setValue(originLng, forKey: "originLng")
        mo.setValue(destinationLat, forKey: "destinationLat"); mo.setValue(destinationLng, forKey: "destinationLng")
        mo.setValue(startTime, forKey: "startTime"); mo.setValue(endTime, forKey: "endTime")
        mo.setValue(Int32(seatsAvailable), forKey: "seatsAvailable")
        mo.setValue(vehicleType, forKey: "vehicleType")
        mo.setValue(createdBy, forKey: "createdBy"); mo.setValue(status.rawValue, forKey: "status")
    }
}

// MARK: - CountTask Mapping

extension CountTask {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            assignedTo: mo.uuid("assignedTo"),
            status: mo.enumValue("status") as CountTaskStatus
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(assignedTo, forKey: "assignedTo")
        mo.setValue(status.rawValue, forKey: "status")
    }
}

// MARK: - CountBatch Mapping

extension CountBatch {
    init(mo: NSManagedObject) {
        self.init(id: mo.uuid("id"), siteId: mo.string("siteId"), taskId: mo.uuid("taskId"), createdAt: mo.date("createdAt"))
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(taskId, forKey: "taskId")
        mo.setValue(createdAt, forKey: "createdAt")
    }
}

// MARK: - CheckIn Mapping

extension CheckIn {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            siteId: mo.string("siteId"),
            userId: mo.uuid("userId"),
            timestamp: mo.date("timestamp"),
            locationLat: mo.double("locationLat"), locationLng: mo.double("locationLng")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(siteId, forKey: "siteId"); mo.setValue(userId, forKey: "userId")
        mo.setValue(timestamp, forKey: "timestamp")
        mo.setValue(locationLat, forKey: "locationLat"); mo.setValue(locationLng, forKey: "locationLng")
    }
}

// MARK: - BusinessHoursConfig Mapping

extension BusinessHoursConfig {
    init(mo: NSManagedObject) {
        let daysString = mo.string("workingDays")
        let days = daysString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        self.init(
            id: mo.uuid("id"), startHour: mo.int32("startHour"),
            endHour: mo.int32("endHour"), workingDays: days
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(Int32(startHour), forKey: "startHour")
        mo.setValue(Int32(endHour), forKey: "endHour")
        mo.setValue(workingDays.map { String($0) }.joined(separator: ","), forKey: "workingDays")
    }
}

// MARK: - CarpoolMatch Mapping

extension CarpoolMatch {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), requestOrderId: mo.uuid("requestOrderId"),
            offerOrderId: mo.uuid("offerOrderId"),
            matchScore: mo.double("matchScore"), detourMiles: mo.double("detourMiles"),
            timeOverlapMinutes: mo.double("timeOverlapMinutes"),
            accepted: mo.bool("accepted"), createdAt: mo.date("createdAt")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id")
        mo.setValue(requestOrderId, forKey: "requestOrderId")
        mo.setValue(offerOrderId, forKey: "offerOrderId")
        mo.setValue(matchScore, forKey: "matchScore"); mo.setValue(detourMiles, forKey: "detourMiles")
        mo.setValue(timeOverlapMinutes, forKey: "timeOverlapMinutes")
        mo.setValue(accepted, forKey: "accepted"); mo.setValue(createdAt, forKey: "createdAt")
    }
}

// MARK: - RouteSegment Mapping

extension RouteSegment {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"),
            matchId: mo.uuid("matchId"),
            originLat: mo.double("originLat"), originLng: mo.double("originLng"),
            destinationLat: mo.double("destinationLat"), destinationLng: mo.double("destinationLng"),
            distanceMiles: mo.double("distanceMiles"),
            estimatedDurationMinutes: mo.double("estimatedDurationMinutes"),
            createdAt: mo.date("createdAt")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(matchId, forKey: "matchId")
        mo.setValue(originLat, forKey: "originLat"); mo.setValue(originLng, forKey: "originLng")
        mo.setValue(destinationLat, forKey: "destinationLat"); mo.setValue(destinationLng, forKey: "destinationLng")
        mo.setValue(distanceMiles, forKey: "distanceMiles")
        mo.setValue(estimatedDurationMinutes, forKey: "estimatedDurationMinutes")
        mo.setValue(createdAt, forKey: "createdAt")
    }
}

// MARK: - PermissionScope Mapping

extension PermissionScope {
    init(mo: NSManagedObject) {
        self.init(
            id: mo.uuid("id"), userId: mo.uuid("userId"),
            site: mo.string("site"), functionKey: mo.string("functionKey"),
            validFrom: mo.date("validFrom"), validTo: mo.date("validTo")
        )
    }
    func apply(to mo: NSManagedObject) {
        mo.setValue(id, forKey: "id"); mo.setValue(userId, forKey: "userId")
        mo.setValue(site, forKey: "site"); mo.setValue(functionKey, forKey: "functionKey")
        mo.setValue(validFrom, forKey: "validFrom"); mo.setValue(validTo, forKey: "validTo")
    }
}
