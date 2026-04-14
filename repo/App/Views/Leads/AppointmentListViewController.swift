import UIKit

/// Appointment list with confirmation action.
/// Shows unconfirmed appointments and allows confirming them.
/// Calls AppointmentService.updateStatus — real service, real persistence.
final class AppointmentListViewController: BaseTableViewController {

    private var appointments: [Appointment] = []
    var site: String = ""

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Appointments"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let user = container.sessionService.currentUser else { return }
        if case .success(let appts) = container.appointmentService.getUnconfirmedWithinSLA(by: user, site: site) {
            appointments = appts
        }
        if appointments.isEmpty { applyState(.empty("No appointments")) }
        else { applyState(.loaded) }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { appointments.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let appt = appointments[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = "Appointment: \(appt.startTime)"
        config.secondaryText = appt.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true

        if appt.status == .scheduled {
            config.image = UIImage(systemName: "calendar.badge.exclamationmark")
            config.imageProperties.tintColor = .systemOrange
            cell.accessoryType = .disclosureIndicator
        } else if appt.status == .confirmed {
            config.image = UIImage(systemName: "calendar.badge.checkmark")
            config.imageProperties.tintColor = .systemGreen
        } else {
            config.image = UIImage(systemName: "calendar")
            config.imageProperties.tintColor = .secondaryLabel
        }

        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let appt = appointments[indexPath.row]
        showAppointmentActions(appt)
    }

    private func showAppointmentActions(_ appt: Appointment) {
        guard let user = container.sessionService.currentUser else { return }
        let sheet = UIAlertController(title: "Appointment", message: "Status: \(appt.status.rawValue)", preferredStyle: .actionSheet)

        // Confirm (scheduled → confirmed)
        if appt.status == .scheduled {
            sheet.addAction(UIAlertAction(title: "Confirm Appointment", style: .default) { [weak self] _ in
                self?.updateStatus(appt, to: .confirmed, user: user)
            })
            sheet.addAction(UIAlertAction(title: "Cancel Appointment", style: .destructive) { [weak self] _ in
                self?.updateStatus(appt, to: .canceled, user: user)
            })
        }
        // Complete (confirmed → completed)
        if appt.status == .confirmed {
            sheet.addAction(UIAlertAction(title: "Mark Completed", style: .default) { [weak self] _ in
                self?.updateStatus(appt, to: .completed, user: user)
            })
            sheet.addAction(UIAlertAction(title: "Mark No-Show", style: .destructive) { [weak self] _ in
                self?.updateStatus(appt, to: .noShow, user: user)
            })
        }
        sheet.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(sheet, animated: true)
    }

    private func updateStatus(_ appt: Appointment, to status: AppointmentStatus, user: User) {
        let result = container.appointmentService.updateStatus(
            by: user, site: site, appointmentId: appt.id, newStatus: status, operationId: UUID()
        )
        switch result {
        case .success: viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }
}
