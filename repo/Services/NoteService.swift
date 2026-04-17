import Foundation

/// Manages notes and tags with polymorphic associations.
/// Note addition on a lead is an SLA qualifying action.
final class NoteService {

    private let noteRepo: NoteRepository
    private let tagRepo: TagRepository
    private let leadRepo: LeadRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let slaService: SLAService
    private let operationLogRepo: OperationLogRepository

    init(
        noteRepo: NoteRepository,
        tagRepo: TagRepository,
        leadRepo: LeadRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        slaService: SLAService,
        operationLogRepo: OperationLogRepository
    ) {
        self.noteRepo = noteRepo
        self.tagRepo = tagRepo
        self.leadRepo = leadRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.slaService = slaService
        self.operationLogRepo = operationLogRepo
    }

    // MARK: - Entity Ownership

    /// Verifies the entity exists at the site and the user has object-level access.
    /// For Lead entities, enforces lead ownership (same rule as LeadService).
    private func enforceEntityAccess(entityId: UUID, entityType: String, site: String, user: User) -> ServiceResult<Void> {
        guard entityType == "Lead" else { return .success(()) }
        guard let lead = leadRepo.findById(entityId) else { return .failure(.entityNotFound) }
        guard lead.siteId == site else { return .failure(.permissionDenied) }
        switch user.role {
        case .administrator, .complianceReviewer: return .success(())
        default:
            guard lead.assignedTo == nil || lead.assignedTo == user.id else { return .failure(.permissionDenied) }
            return .success(())
        }
    }

    // MARK: - Notes

    func addNote(
        by user: User,
        site: String,
        entityId: UUID,
        entityType: String,
        content: String,
        operationId: UUID
    ) -> ServiceResult<Note> {
        if operationLogRepo.exists(operationId) { return .failure(.duplicateOperation) }

        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "create", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }

        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure(.validationFailed("content", "required"))
        }

        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }

        let note = Note(
            id: UUID(),
            siteId: site,
            entityId: entityId,
            entityType: entityType,
            content: content,
            createdAt: Date(),
            createdBy: user.id
        )

        do {
            try noteRepo.save(note)
            try operationLogRepo.save(operationId)

            // If the entity is a Lead, adding a note is an SLA qualifying action
            if entityType == "Lead" {
                slaService.resetLeadSLA(leadId: entityId, actionDate: Date())
            }

            auditService.log(actorId: user.id, action: "note_added", entityId: note.id)
            return .success(note)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    func getNotesForEntity(by user: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[Note]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }
        return .success(noteRepo.findByEntity(entityId: entityId, entityType: entityType).filter { $0.siteId == site })
    }

    // MARK: - Tags

    /// Get or create a normalized tag.
    func getOrCreateTag(name: String) -> ServiceResult<Tag> {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else {
            return .failure(.validationFailed("tag", "name required"))
        }

        if let existing = tagRepo.findByName(normalized) {
            return .success(existing)
        }

        let tag = Tag(id: UUID(), name: normalized)
        do {
            try tagRepo.save(tag)
            return .success(tag)
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    /// Assign a tag to an entity.
    func assignTag(
        by user: User,
        site: String,
        tagId: UUID,
        entityId: UUID,
        entityType: String
    ) -> ServiceResult<Void> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }

        let assignment = TagAssignment(tagId: tagId, entityId: entityId, entityType: entityType)
        do {
            try tagRepo.saveAssignment(assignment)
            auditService.log(actorId: user.id, action: "tag_assigned", entityId: entityId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    /// Remove a tag from an entity.
    func removeTag(
        by user: User,
        site: String,
        tagId: UUID,
        entityId: UUID,
        entityType: String
    ) -> ServiceResult<Void> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "update", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }

        do {
            try tagRepo.deleteAssignment(tagId: tagId, entityId: entityId, entityType: entityType)
            auditService.log(actorId: user.id, action: "tag_removed", entityId: entityId)
            return .success(())
        } catch {
            return .failure(ServiceError(code: "SAVE_FAIL", message: error.localizedDescription))
        }
    }

    func getTagsForEntity(by user: User, site: String, entityId: UUID, entityType: String) -> ServiceResult<[TagAssignment]> {
        if case .failure(let err) = permissionService.validateFullAccess(
            user: user, action: "read", module: .leads,
            site: site, functionKey: "leads"
        ) {
            return .failure(err)
        }
        if case .failure(let err) = enforceEntityAccess(entityId: entityId, entityType: entityType, site: site, user: user) {
            return .failure(err)
        }
        return .success(tagRepo.findAssignments(entityId: entityId, entityType: entityType))
    }
}
