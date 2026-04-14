import UIKit

/// Admin panel: user management, role updates, lockout reset, permission scopes.
final class AdminPanelViewController: BaseTableViewController {

    private var users: [User] = []

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Admin Panel"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapCreateUser))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let admin = container.sessionService.currentUser,
              case .success(let allUsers) = container.userManagementService.listUsers(by: admin) else {
            applyState(.error("Access denied")); return
        }
        users = allUsers
        if users.isEmpty { applyState(.empty("No users")) }
        else { applyState(.loaded) }
    }

    @objc private func didTapCreateUser() {
        let alert = UIAlertController(title: "Create User", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Username" }
        alert.addTextField { $0.placeholder = "Password"; $0.isSecureTextEntry = true }

        let roleControl = UISegmentedControl(items: ["Admin", "Sales", "Clerk", "Reviewer"])
        roleControl.selectedSegmentIndex = 1
        alert.view.addSubview(roleControl)
        roleControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            roleControl.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 140),
            roleControl.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
        ])
        // Add height for segmented control
        let heightConstraint = alert.view.heightAnchor.constraint(equalToConstant: 230)
        heightConstraint.isActive = true

        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self, let admin = self.container.sessionService.currentUser,
                  let username = alert.textFields?[0].text, !username.isEmpty,
                  let password = alert.textFields?[1].text, !password.isEmpty else { return }

            let roles: [UserRole] = [.administrator, .salesAssociate, .inventoryClerk, .complianceReviewer]
            let role = roles[roleControl.selectedSegmentIndex]

            let result = self.container.userManagementService.createUser(
                by: admin, username: username, password: password, role: role, operationId: UUID()
            )
            switch result {
            case .success: self.viewWillAppear(false)
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Table

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { users.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let user = users[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = user.username
        config.secondaryText = "\(user.role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized) \u{2022} \(user.isActive ? "Active" : "Inactive")"
        config.image = UIImage(systemName: user.isActive ? "person.circle" : "person.circle.fill")
        config.imageProperties.tintColor = user.isActive ? .systemGreen : .systemGray
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let user = users[indexPath.row]
        showUserActions(user)
    }

    private func showUserActions(_ user: User) {
        guard let admin = container.sessionService.currentUser else { return }
        let sheet = UIAlertController(title: user.username, message: "Role: \(user.role.rawValue)", preferredStyle: .actionSheet)

        // Change role
        for role in UserRole.allCases where role != user.role {
            let label = role.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
            sheet.addAction(UIAlertAction(title: "Change to \(label)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                switch self.container.userManagementService.updateRole(by: admin, userId: user.id, newRole: role, operationId: UUID()) {
                case .success: self.viewWillAppear(false)
                case .failure(let err): self.showError(err.message)
                }
            })
        }

        // Deactivate/Activate
        if user.isActive && user.id != admin.id {
            sheet.addAction(UIAlertAction(title: "Deactivate User", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                switch self.container.userManagementService.deactivateUser(by: admin, userId: user.id, operationId: UUID()) {
                case .success: self.viewWillAppear(false)
                case .failure(let err): self.showError(err.message)
                }
            })
        }

        // Reset lockout
        if user.lockoutUntil != nil {
            sheet.addAction(UIAlertAction(title: "Reset Lockout", style: .default) { [weak self] _ in
                guard let self = self else { return }
                switch self.container.userManagementService.resetLockout(by: admin, userId: user.id, operationId: UUID()) {
                case .success: self.viewWillAppear(false); self.showSuccess("Lockout reset")
                case .failure(let err): self.showError(err.message)
                }
            })
        }

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}
