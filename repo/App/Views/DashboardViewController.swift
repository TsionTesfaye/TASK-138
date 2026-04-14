import UIKit

/// Role-based dashboard with SLA alerts and quick actions.
final class DashboardViewController: BaseTableViewController {

    private lazy var viewModel = DashboardViewModel(container: container)

    private struct DashAction {
        let title: String
        let icon: String
        let color: UIColor
        let action: () -> Void
    }
    private var actions: [DashAction] = []

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Dashboard"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "metric")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "action")

        viewModel.onStateChange = { [weak self] state in self?.applyState(state) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.load()
        buildActions()
    }

    private func buildActions() {
        guard let user = container.sessionService.currentUser else { return }
        actions = []
        if PermissionMatrix.canPerform(role: user.role, action: "create", module: .leads) {
            actions.append(DashAction(title: "Create Lead", icon: "plus.circle", color: .systemBlue) { [weak self] in
                guard let self = self else { return }
                let vc = CreateLeadViewController(container: self.container)
                self.navigationController?.pushViewController(vc, animated: true)
            })
        }
        if PermissionMatrix.canPerform(role: user.role, action: "read", module: .inventory) {
            actions.append(DashAction(title: "Inventory Tasks", icon: "shippingbox", color: .systemOrange) { [weak self] in
                guard let self = self else { return }
                let vc = InventoryTaskListViewController(container: self.container)
                self.navigationController?.pushViewController(vc, animated: true)
            })
        }
        if PermissionMatrix.canPerform(role: user.role, action: "read", module: .appeals) {
            actions.append(DashAction(title: "Exceptions", icon: "exclamationmark.shield", color: .systemRed) { [weak self] in
                guard let self = self else { return }
                let vc = ExceptionListViewController(container: self.container)
                self.navigationController?.pushViewController(vc, animated: true)
            })
        }
        // Check-in available to all active users
        actions.append(DashAction(title: "Check In", icon: "location.circle", color: .systemTeal) { [weak self] in
            guard let self = self else { return }
            let vc = CheckInViewController(container: self.container)
            self.navigationController?.pushViewController(vc, animated: true)
        })
        // Appointments
        if PermissionMatrix.canPerform(role: user.role, action: "read", module: .leads) {
            actions.append(DashAction(title: "Appointments", icon: "calendar", color: .systemPurple) { [weak self] in
                guard let self = self else { return }
                let vc = AppointmentListViewController(container: self.container)
                self.navigationController?.pushViewController(vc, animated: true)
            })
        }
        // Admin: permission scopes
        if user.role == .administrator {
            actions.append(DashAction(title: "Permission Scopes", icon: "lock.shield", color: .systemIndigo) { [weak self] in
                guard let self = self else { return }
                let vc = PermissionScopeViewController(container: self.container)
                self.navigationController?.pushViewController(vc, animated: true)
            })
        }
    }

    // MARK: - Table Data Source

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Welcome"
        case 1: return "Alerts"
        case 2: return "Quick Actions"
        default: return nil
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let data = viewModel.data else { return 0 }
        switch section {
        case 0: return 1
        case 1:
            var count = 0
            if data.slaViolationCount > 0 { count += 1 }
            if data.pendingAppealCount > 0 { count += 1 }
            if data.pendingVarianceCount > 0 { count += 1 }
            if data.unconfirmedAppointmentCount > 0 { count += 1 }
            return max(count, 1)
        case 2: return actions.count
        default: return 0
        }
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let data = viewModel.data else { return UITableViewCell() }

        switch indexPath.section {
        case 0:
            let cell = tv.dequeueReusableCell(withIdentifier: "metric", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = data.username
            config.secondaryText = data.role
            config.image = UIImage(systemName: "person.circle")
            config.textProperties.font = .preferredFont(forTextStyle: .headline)
            config.textProperties.adjustsFontForContentSizeCategory = true
            config.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell

        case 1:
            let cell = tv.dequeueReusableCell(withIdentifier: "metric", for: indexPath)
            var config = cell.defaultContentConfiguration()

            var alerts: [(String, String, UIColor)] = []
            if data.slaViolationCount > 0 {
                alerts.append(("\(data.slaViolationCount) SLA Violations", "clock.badge.exclamationmark", .systemRed))
            }
            if data.pendingAppealCount > 0 {
                alerts.append(("\(data.pendingAppealCount) Pending Appeals", "doc.text", .systemOrange))
            }
            if data.pendingVarianceCount > 0 {
                alerts.append(("\(data.pendingVarianceCount) Pending Variances", "exclamationmark.triangle", .systemYellow))
            }
            if data.unconfirmedAppointmentCount > 0 {
                alerts.append(("\(data.unconfirmedAppointmentCount) Unconfirmed Appointments", "calendar.badge.exclamationmark", .systemPurple))
            }

            if alerts.isEmpty {
                config.text = "No active alerts"
                config.image = UIImage(systemName: "checkmark.circle")
                config.imageProperties.tintColor = .systemGreen
            } else if indexPath.row < alerts.count {
                let alert = alerts[indexPath.row]
                config.text = alert.0
                config.image = UIImage(systemName: alert.1)
                config.imageProperties.tintColor = alert.2
            }
            config.textProperties.font = .preferredFont(forTextStyle: .body)
            config.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            return cell

        case 2:
            let cell = tv.dequeueReusableCell(withIdentifier: "action", for: indexPath)
            let action = actions[indexPath.row]
            var config = cell.defaultContentConfiguration()
            config.text = action.title
            config.image = UIImage(systemName: action.icon)
            config.imageProperties.tintColor = action.color
            config.textProperties.font = .preferredFont(forTextStyle: .body)
            config.textProperties.adjustsFontForContentSizeCategory = true
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            return cell

        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 2, indexPath.row < actions.count {
            actions[indexPath.row].action()
        }
    }
}
