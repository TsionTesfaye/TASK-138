import Foundation

final class LeadViewModel: BaseViewModel {

    private(set) var leads: [Lead] = []
    private(set) var selectedLead: Lead?
    private(set) var notes: [Note] = []
    private(set) var reminders: [Reminder] = []
    private(set) var tags: [TagAssignment] = []
    var filterStatus: LeadStatus? = nil
    var site: String = ""

    override init(container: ServiceContainer) {
        super.init(container: container)
        site = container.currentSite
    }

    func loadLeads() {
        guard let user = currentUser() else { return }
        setState(.loading)
        let result: ServiceResult<[Lead]>
        if let status = filterStatus {
            result = container.leadService.findByStatus(by: user, site: site, status)
        } else {
            result = container.leadService.findAllNonArchived(by: user, site: site)
        }
        switch result {
        case .success(let found):
            leads = found
            setState(leads.isEmpty ? .empty("No leads found") : .loaded)
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
    }

    func loadLeadDetail(id: UUID) {
        guard let user = currentUser() else { return }
        setState(.loading)
        switch container.leadService.findById(by: user, site: site, id) {
        case .success(let lead):
            guard let lead = lead else {
                setState(.error("Lead not found"))
                return
            }
            selectedLead = lead
            if case .success(let n) = container.noteService.getNotesForEntity(by: user, site: site, entityId: id, entityType: "Lead") {
                notes = n
            }
            if case .success(let r) = container.reminderService.findByEntity(by: user, site: site, entityId: id, entityType: "Lead") {
                reminders = r
            }
            if case .success(let t) = container.noteService.getTagsForEntity(by: user, site: site, entityId: id, entityType: "Lead") {
                tags = t
            }
            setState(.loaded)
        case .failure(let err):
            setState(.error("\(err.code): \(err.message)"))
        }
    }

    func createLead(input: LeadService.CreateLeadInput) -> ServiceResult<Lead> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.leadService.createLead(by: user, site: site, input: input, operationId: UUID())
    }

    func transitionLead(id: UUID, to status: LeadStatus) -> ServiceResult<Lead> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.leadService.updateLeadStatus(by: user, site: site, leadId: id, newStatus: status, operationId: UUID())
    }

    func assignLead(id: UUID, to assigneeId: UUID) -> ServiceResult<Lead> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.leadService.assignLead(by: user, site: site, leadId: id, assigneeId: assigneeId, operationId: UUID())
    }

    func addNote(leadId: UUID, content: String) -> ServiceResult<Note> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.noteService.addNote(by: user, site: site, entityId: leadId, entityType: "Lead", content: content, operationId: UUID())
    }

    func addReminder(leadId: UUID, dueAt: Date) -> ServiceResult<Reminder> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.reminderService.createReminder(by: user, site: site, entityId: leadId, entityType: "Lead", dueAt: dueAt, operationId: UUID())
    }

    func createAppointment(leadId: UUID, startTime: Date) -> ServiceResult<Appointment> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.appointmentService.createAppointment(by: user, site: site, leadId: leadId, startTime: startTime, operationId: UUID())
    }

    func addTag(leadId: UUID, tagName: String) -> ServiceResult<Void> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        switch container.noteService.getOrCreateTag(name: tagName) {
        case .success(let tag):
            return container.noteService.assignTag(by: user, site: site, tagId: tag.id, entityId: leadId, entityType: "Lead")
        case .failure(let err):
            return .failure(err)
        }
    }

    func removeTag(leadId: UUID, tagId: UUID) -> ServiceResult<Void> {
        guard let user = currentUser() else { return .failure(.sessionExpired) }
        return container.noteService.removeTag(by: user, site: site, tagId: tagId, entityId: leadId, entityType: "Lead")
    }
}
