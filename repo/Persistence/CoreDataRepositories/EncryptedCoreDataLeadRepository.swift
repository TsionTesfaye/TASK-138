import Foundation
import CoreData

/// Hard failure when encryption cannot be performed.
/// No plaintext fallback — if encryption fails, the save is rejected entirely.
enum EncryptionError: Error, CustomStringConvertible {
    case fieldEncryptionFailed(field: String, recordId: UUID)

    var description: String {
        switch self {
        case .fieldEncryptionFailed(let field, let recordId):
            return "Encryption failed for field '\(field)' on record \(recordId). Save aborted to prevent plaintext persistence."
        }
    }
}

/// Core Data Lead repository with AES encryption for sensitive fields.
/// Encrypts: phone, customerName, consentNotes at repository layer.
/// Services remain unaware of encryption — they see plaintext.
final class EncryptedCoreDataLeadRepository: LeadRepository {

    private let inner: CoreDataLeadRepository
    private let encryption: EncryptionServiceProtocol

    init(context: NSManagedObjectContext, encryption: EncryptionServiceProtocol) {
        self.inner = CoreDataLeadRepository(context: context)
        self.encryption = encryption
    }

    func findById(_ id: UUID) -> Lead? {
        inner.findById(id).map { decryptLead($0) }
    }

    func findByStatus(_ status: LeadStatus) -> [Lead] {
        inner.findByStatus(status).map { decryptLead($0) }
    }

    func findByAssignedTo(_ userId: UUID) -> [Lead] {
        inner.findByAssignedTo(userId).map { decryptLead($0) }
    }

    func findLeadsExceedingSLA(before deadline: Date) -> [Lead] {
        inner.findLeadsExceedingSLA(before: deadline).map { decryptLead($0) }
    }

    func findClosedLeadsOlderThan(_ date: Date) -> [Lead] {
        inner.findClosedLeadsOlderThan(date).map { decryptLead($0) }
    }

    func findAll() -> [Lead] {
        inner.findAll().map { decryptLead($0) }
    }

    func findBySiteId(_ siteId: String) -> [Lead] {
        inner.findBySiteId(siteId).map { decryptLead($0) }
    }

    func save(_ lead: Lead) throws {
        guard let encPhone = encryption.encrypt(lead.phone, recordId: lead.id) else {
            throw EncryptionError.fieldEncryptionFailed(field: "phone", recordId: lead.id)
        }
        guard let encName = encryption.encrypt(lead.customerName, recordId: lead.id) else {
            throw EncryptionError.fieldEncryptionFailed(field: "customerName", recordId: lead.id)
        }
        guard let encConsent = encryption.encrypt(lead.consentNotes, recordId: lead.id) else {
            throw EncryptionError.fieldEncryptionFailed(field: "consentNotes", recordId: lead.id)
        }

        let encrypted = Lead(
            id: lead.id, siteId: lead.siteId, leadType: lead.leadType, status: lead.status,
            customerName: encName, phone: encPhone,
            vehicleInterest: lead.vehicleInterest,
            preferredContactWindow: lead.preferredContactWindow,
            consentNotes: encConsent, assignedTo: lead.assignedTo,
            createdAt: lead.createdAt, updatedAt: lead.updatedAt,
            slaDeadline: lead.slaDeadline,
            lastQualifyingAction: lead.lastQualifyingAction,
            archivedAt: lead.archivedAt
        )
        try inner.save(encrypted)
    }

    func delete(_ id: UUID) throws {
        try inner.delete(id)
    }

    private func decryptLead(_ lead: Lead) -> Lead {
        let phone = encryption.decrypt(lead.phone, recordId: lead.id) ?? "[DECRYPTION FAILED]"
        let name = encryption.decrypt(lead.customerName, recordId: lead.id) ?? "[DECRYPTION FAILED]"
        let consent = encryption.decrypt(lead.consentNotes, recordId: lead.id) ?? "[DECRYPTION FAILED]"
        return Lead(
            id: lead.id, siteId: lead.siteId, leadType: lead.leadType, status: lead.status,
            customerName: name, phone: phone,
            vehicleInterest: lead.vehicleInterest,
            preferredContactWindow: lead.preferredContactWindow,
            consentNotes: consent, assignedTo: lead.assignedTo,
            createdAt: lead.createdAt, updatedAt: lead.updatedAt,
            slaDeadline: lead.slaDeadline,
            lastQualifyingAction: lead.lastQualifyingAction,
            archivedAt: lead.archivedAt
        )
    }
}
