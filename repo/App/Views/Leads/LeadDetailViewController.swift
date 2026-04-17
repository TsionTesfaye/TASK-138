import UIKit

/// Lead detail: full info, notes, tags, reminders, status transitions, appointment creation.
final class LeadDetailViewController: BaseTableViewController {

    private lazy var viewModel = LeadViewModel(container: container)
    private let leadId: UUID

    init(container: ServiceContainer, leadId: UUID) {
        self.leadId = leadId
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Lead Detail"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        viewModel.onStateChange = { [weak self] state in self?.applyState(state) }

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Actions", style: .plain, target: self, action: #selector(showActions)
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadLeadDetail(id: leadId)
    }

    @objc private func showActions() {
        guard let lead = viewModel.selectedLead, let user = container.sessionService.currentUser else { return }
        let sheet = UIAlertController(title: "Actions", message: nil, preferredStyle: .actionSheet)
        sheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem

        // Status transitions based on state machine
        let isAdmin = user.role == .administrator
        for target in LeadStatus.allCases where lead.status.canTransition(to: target, isAdmin: isAdmin) {
            let label = target.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
            sheet.addAction(UIAlertAction(title: "Move to \(label)", style: .default) { [weak self] _ in
                self?.transitionTo(target)
            })
        }

        sheet.addAction(UIAlertAction(title: "Add Note", style: .default) { [weak self] _ in self?.promptAddNote() })
        sheet.addAction(UIAlertAction(title: "Add Tag", style: .default) { [weak self] _ in self?.promptAddTag() })
        sheet.addAction(UIAlertAction(title: "Add Reminder", style: .default) { [weak self] _ in self?.promptAddReminder() })
        sheet.addAction(UIAlertAction(title: "Schedule Appointment", style: .default) { [weak self] _ in self?.promptAppointment() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func transitionTo(_ status: LeadStatus) {
        let result = viewModel.transitionLead(id: leadId, to: status)
        switch result {
        case .success: viewModel.loadLeadDetail(id: leadId)
        case .failure(let err): showError(err.message)
        }
    }

    private func promptAddNote() {
        let alert = UIAlertController(title: "Add Note", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Note content" }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            switch self.viewModel.addNote(leadId: self.leadId, content: text) {
            case .success: self.viewModel.loadLeadDetail(id: self.leadId)
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptAddReminder() {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Date().addingTimeInterval(60)
        picker.date = Date().addingTimeInterval(3600)

        let alert = UIAlertController(title: "Set Reminder", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        picker.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 48),
            picker.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor),
        ])
        alert.addAction(UIAlertAction(title: "Set", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let dueAt = picker.date
            switch self.viewModel.addReminder(leadId: self.leadId, dueAt: dueAt) {
            case .success(let r):
                NotificationService.shared.scheduleReminderNotification(reminderId: r.id, dueAt: dueAt, message: "Follow up on lead")
                self.viewModel.loadLeadDetail(id: self.leadId)
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptAppointment() {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.minimumDate = Date().addingTimeInterval(60)
        picker.date = Date().addingTimeInterval(86400)

        let alert = UIAlertController(title: "Schedule Appointment", message: "\n\n\n\n\n\n\n\n\n", preferredStyle: .alert)
        picker.translatesAutoresizingMaskIntoConstraints = false
        alert.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 48),
            picker.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor),
        ])
        alert.addAction(UIAlertAction(title: "Schedule", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let startTime = picker.date
            switch self.viewModel.createAppointment(leadId: self.leadId, startTime: startTime) {
            case .success(let appt):
                NotificationService.shared.scheduleAppointmentSLAAlert(appointmentId: appt.id, startTime: startTime)
                self.showSuccess("Appointment scheduled")
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func promptAddTag() {
        let alert = UIAlertController(title: "Add Tag", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Tag name (e.g. hot-lead)" }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            switch self.viewModel.addTag(leadId: self.leadId, tagName: name) {
            case .success: self.viewModel.loadLeadDetail(id: self.leadId)
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Table (Sections: Info, Notes, Tags, Reminders)

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Information"
        case 1: return "Notes (\(viewModel.notes.count))"
        case 2: return "Tags (\(viewModel.tags.count))"
        case 3: return "Reminders (\(viewModel.reminders.count))"
        default: return nil
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard viewModel.selectedLead != nil else { return 0 }
        switch section {
        case 0: return 7
        case 1: return max(viewModel.notes.count, 1)
        case 2: return max(viewModel.tags.count, 1)
        case 3: return max(viewModel.reminders.count, 1)
        default: return 0
        }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard let lead = viewModel.selectedLead else { return cell }
        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true

        switch indexPath.section {
        case 0:
            let rows: [(String, String)] = [
                ("Customer", lead.customerName),
                ("Phone", LeadService.maskPhone(lead.phone)),
                ("Type", lead.leadType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized),
                ("Status", lead.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized),
                ("Vehicle Interest", lead.vehicleInterest),
                ("Contact Window", lead.preferredContactWindow),
                ("SLA Deadline", lead.slaDeadline.map { "\($0)" } ?? "N/A"),
            ]
            if indexPath.row < rows.count {
                config.text = rows[indexPath.row].0
                config.secondaryText = rows[indexPath.row].1
            }
        case 1:
            if viewModel.notes.isEmpty {
                config.text = "No notes yet"
                config.textProperties.color = .secondaryLabel
            } else {
                let note = viewModel.notes[indexPath.row]
                config.text = note.content
                config.secondaryText = "\(note.createdAt)"
            }
        case 2:
            if viewModel.tags.isEmpty {
                config.text = "No tags"
                config.textProperties.color = .secondaryLabel
                cell.selectionStyle = .none
            } else {
                let assignment = viewModel.tags[indexPath.row]
                config.text = "#\(assignment.tagId)"
                config.image = UIImage(systemName: "tag")
                config.imageProperties.tintColor = .systemBlue
                cell.selectionStyle = .default
            }
        case 3:
            if viewModel.reminders.isEmpty {
                config.text = "No reminders"
                config.textProperties.color = .secondaryLabel
            } else {
                let reminder = viewModel.reminders[indexPath.row]
                config.text = "Due: \(reminder.dueAt)"
                config.secondaryText = reminder.status.rawValue.capitalized
            }
        default: break
        }

        cell.contentConfiguration = config
        if indexPath.section != 2 { cell.selectionStyle = .none }
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2, !viewModel.tags.isEmpty else { return }
        let assignment = viewModel.tags[indexPath.row]
        let sheet = UIAlertController(title: "Tag", message: "Tag ID: \(assignment.tagId)", preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Remove Tag", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            switch self.viewModel.removeTag(leadId: self.leadId, tagId: assignment.tagId) {
            case .success: self.viewModel.loadLeadDetail(id: self.leadId)
            case .failure(let err): self.showError(err.message)
            }
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}
