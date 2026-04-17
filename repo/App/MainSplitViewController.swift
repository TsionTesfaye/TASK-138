import UIKit

/// Main split view controller for iPad support.
/// On iPhone: tab bar. On iPad: split view with sidebar.
final class MainSplitViewController: UISplitViewController, UISplitViewControllerDelegate {

    let container: ServiceContainer

    init(container: ServiceContainer) {
        self.container = container
        super.init(style: .doubleColumn)
        delegate = self
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebar = SidebarViewController(container: container)
        sidebar.onSelection = { [weak self] section in
            self?.showSection(section)
        }

        let dashboard = DashboardViewController(container: container)

        setViewController(UINavigationController(rootViewController: sidebar), for: .primary)
        setViewController(UINavigationController(rootViewController: dashboard), for: .secondary)
        setViewController(makeTabBar(), for: .compact)
    }

    private func showSection(_ section: AppSection) {
        let vc: UIViewController
        switch section {
        case .dashboard:
            vc = DashboardViewController(container: container)
        case .leads:
            vc = LeadListViewController(container: container)
        case .inventory:
            vc = InventoryTaskListViewController(container: container)
        case .carpool:
            vc = CarpoolListViewController(container: container)
        case .compliance:
            vc = ExceptionListViewController(container: container)
        case .admin:
            vc = AdminPanelViewController(container: container)
        }
        setViewController(UINavigationController(rootViewController: vc), for: .secondary)
    }

    private func makeTabBar() -> UITabBarController {
        let tab = UITabBarController()
        let user = container.sessionService.currentUser

        var vcs: [UIViewController] = []

        let dashboard = UINavigationController(rootViewController: DashboardViewController(container: container))
        dashboard.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)
        vcs.append(dashboard)

        if PermissionMatrix.canPerform(role: user?.role ?? .salesAssociate, action: "read", module: .leads) {
            let leads = UINavigationController(rootViewController: LeadListViewController(container: container))
            leads.tabBarItem = UITabBarItem(title: "Leads", image: UIImage(systemName: "person.crop.rectangle"), tag: 1)
            vcs.append(leads)
        }

        if PermissionMatrix.canPerform(role: user?.role ?? .inventoryClerk, action: "read", module: .inventory) {
            let inv = UINavigationController(rootViewController: InventoryTaskListViewController(container: container))
            inv.tabBarItem = UITabBarItem(title: "Inventory", image: UIImage(systemName: "shippingbox"), tag: 2)
            vcs.append(inv)
        }

        if PermissionMatrix.canPerform(role: user?.role ?? .salesAssociate, action: "read", module: .carpool) {
            let carpool = UINavigationController(rootViewController: CarpoolListViewController(container: container))
            carpool.tabBarItem = UITabBarItem(title: "Carpool", image: UIImage(systemName: "car.2"), tag: 3)
            vcs.append(carpool)
        }

        if PermissionMatrix.canPerform(role: user?.role ?? .complianceReviewer, action: "read", module: .appeals) {
            let compliance = UINavigationController(rootViewController: ExceptionListViewController(container: container))
            compliance.tabBarItem = UITabBarItem(title: "Compliance", image: UIImage(systemName: "exclamationmark.shield"), tag: 4)
            vcs.append(compliance)
        }

        if user?.role == .administrator {
            let admin = UINavigationController(rootViewController: AdminPanelViewController(container: container))
            admin.tabBarItem = UITabBarItem(title: "Admin", image: UIImage(systemName: "gearshape"), tag: 5)
            vcs.append(admin)
        }

        tab.viewControllers = vcs
        return tab
    }

    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        .compact
    }
}

enum AppSection: String, CaseIterable {
    case dashboard = "Dashboard"
    case leads = "Leads"
    case inventory = "Inventory"
    case carpool = "Carpool"
    case compliance = "Compliance"
    case admin = "Admin"

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .leads: return "person.crop.rectangle"
        case .inventory: return "shippingbox"
        case .carpool: return "car.2"
        case .compliance: return "exclamationmark.shield"
        case .admin: return "gearshape"
        }
    }
}

/// Sidebar for iPad split view.
final class SidebarViewController: UITableViewController {

    let container: ServiceContainer
    var onSelection: ((AppSection) -> Void)?
    private var sections: [AppSection] = []

    init(container: ServiceContainer) {
        self.container = container
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DealerOps"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let user = container.sessionService.currentUser
        sections = [.dashboard]
        if PermissionMatrix.canPerform(role: user?.role ?? .salesAssociate, action: "read", module: .leads) {
            sections.append(.leads)
        }
        if PermissionMatrix.canPerform(role: user?.role ?? .inventoryClerk, action: "read", module: .inventory) {
            sections.append(.inventory)
        }
        if PermissionMatrix.canPerform(role: user?.role ?? .salesAssociate, action: "read", module: .carpool) {
            sections.append(.carpool)
        }
        if PermissionMatrix.canPerform(role: user?.role ?? .complianceReviewer, action: "read", module: .appeals) {
            sections.append(.compliance)
        }
        if user?.role == .administrator {
            sections.append(.admin)
        }
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int { sections.count }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let section = sections[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = section.rawValue
        config.image = UIImage(systemName: section.icon)
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelection?(sections[indexPath.row])
    }
}
