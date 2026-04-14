import UIKit

/// Admin-only PermissionScope management: create/edit/delete scopes by user, site, function, date range.
/// Routes through UserManagementService for proper admin authorization.
final class PermissionScopeViewController: BaseTableViewController {

    private var scopes: [PermissionScope] = []
    private var users: [User] = []

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Permission Scopes"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAdd))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let admin = container.sessionService.currentUser, admin.role == .administrator else {
            applyState(.error("Admin access required")); return
        }
        guard case .success(let allUsers) = container.userManagementService.listUsers(by: admin) else {
            applyState(.error("Access denied")); return
        }
        users = allUsers
        guard case .success(let allScopes) = container.userManagementService.listAllScopes(by: admin) else {
            applyState(.error("Access denied")); return
        }
        scopes = allScopes
        if scopes.isEmpty { applyState(.empty("No permission scopes defined")) }
        else { applyState(.loaded) }
    }

    @objc private func didTapAdd() {
        guard let admin = container.sessionService.currentUser, admin.role == .administrator else { return }

        let alert = UIAlertController(title: "Create Permission Scope", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Username" }
        alert.addTextField { $0.placeholder = "Site (e.g., lot-a)" }
        alert.addTextField { $0.placeholder = "Function Key (e.g., leads)" }

        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let username = alert.textFields?[0].text ?? ""
            let site = alert.textFields?[1].text ?? ""
            let functionKey = alert.textFields?[2].text ?? ""

            guard !username.isEmpty, !site.isEmpty, !functionKey.isEmpty else {
                self.showError("All fields required"); return
            }

            guard case .success(let targetUser) = self.container.userManagementService.findUserByUsername(by: admin, username: username),
                  let targetUser = targetUser else {
                self.showError("User '\(username)' not found"); return
            }

            let result = self.container.userManagementService.createScope(
                by: admin, userId: targetUser.id, site: site, functionKey: functionKey,
                validFrom: Date(), validTo: Date().addingTimeInterval(365 * 86400)
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

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { scopes.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let scope = scopes[indexPath.row]
        let username = users.first(where: { $0.id == scope.userId })?.username ?? "unknown"
        var config = cell.defaultContentConfiguration()
        config.text = "\(username) @ \(scope.site)"
        config.secondaryText = "Function: \(scope.functionKey) | \(scope.validFrom) - \(scope.validTo)"
        config.image = UIImage(systemName: "lock.shield")
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        guard let admin = container.sessionService.currentUser, admin.role == .administrator else { return }
        let scope = scopes[indexPath.row]
        switch container.userManagementService.deleteScope(by: admin, scopeId: scope.id) {
        case .success: viewWillAppear(false)
        case .failure(let err): showError(err.message)
        }
    }
}
