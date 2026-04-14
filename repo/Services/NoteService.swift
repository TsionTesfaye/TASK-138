import Foundation

/// design.md 3.5, 3.6, questions.md Q12
/// Manages notes and tags with polymorphic associations.
/// Note addition on a lead is an SLA qualifying action.
final class NoteService {

    private let noteRepo: NoteRepository
    private let tagRepo: TagRepository
    private let permissionService: PermissionService
    private let auditService: AuditService
    private let slaService: SLAService
    private let operationLogRepo: OperationLogRepository

    init(
        noteRepo: NoteRepository,
        tagRepo: TagRepository,
        permissionService: PermissionService,
        auditService: AuditService,
        slaService: SLAService,
        operationLogRepo: OperationLogRepository
    ) {
        self.noteRepo = noteRepo
        self.tagRepo = tagRepo
        self.permissionService = permissionService
        self.auditService = auditService
        self.slaService = slaService
        self.operationLogRepo = operationLogRepo
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

        let note = Note(
            id: UUID(),
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
        return .success(noteRepo.findByEntity(entityId: entityId, entityType: entityType))
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
        return .success(tagRepo.findAssignments(entityId: entityId, entityType: entityType))
    }
}
