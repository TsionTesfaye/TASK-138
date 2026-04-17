import UIKit

/// Admin/reviewer audit log browser with tombstone management.
/// Role-restricted: administrator and compliance_reviewer only.
final class AuditLogViewController: BaseTableViewController {

    private var logs: [AuditLog] = []
    private var filteredLogs: [AuditLog] = []
    private var filterText: String = ""
    private let searchBar = UISearchBar()

    init(container: ServiceContainer) {
        super.init(container: container, style: .plain)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Audit Logs"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "log")

        searchBar.placeholder = "Filter by action or entity ID"
        searchBar.delegate = self
        searchBar.searchBarStyle = .minimal
        tableView.tableHeaderView = searchBar
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadLogs()
    }

    private func loadLogs() {
        guard let user = container.sessionService.currentUser else { return }
        switch container.auditService.allLogs(by: user) {
        case .success(let all):
            logs = all.sorted { $0.timestamp > $1.timestamp }
        case .failure:
            logs = []
        }
        applyFilter()
    }

    private func applyFilter() {
        if filterText.isEmpty {
            filteredLogs = logs
        } else {
            let q = filterText.lowercased()
            filteredLogs = logs.filter {
                $0.action.lowercased().contains(q) ||
                $0.entityId.uuidString.lowercased().contains(q) ||
                $0.actorId.uuidString.lowercased().contains(q)
            }
        }
        if filteredLogs.isEmpty { applyState(.empty("No matching logs")) }
        else { applyState(.loaded) }
        tableView.reloadData()
    }

    // MARK: - Table

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredLogs.count
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "log", for: indexPath)
        let entry = filteredLogs[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = entry.action
        let dateStr = DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .medium)
        config.secondaryText = "\(dateStr) \u{2022} entity: \(entry.entityId.uuidString.prefix(8))"
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        if entry.tombstone {
            config.image = UIImage(systemName: "trash.circle")
            config.imageProperties.tintColor = .systemGray
            config.textProperties.color = .secondaryLabel
        } else {
            config.image = UIImage(systemName: "doc.text")
            config.imageProperties.tintColor = .systemBlue
        }
        cell.contentConfiguration = config
        cell.accessoryType = entry.tombstone ? .none : .disclosureIndicator
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let entry = filteredLogs[indexPath.row]
        guard !entry.tombstone else { return }
        showLogActions(entry)
    }

    private func showLogActions(_ entry: AuditLog) {
        guard let actor = container.sessionService.currentUser else { return }
        let sheet = UIAlertController(
            title: entry.action,
            message: "Actor: \(entry.actorId.uuidString.prefix(8))\nEntity: \(entry.entityId.uuidString.prefix(8))",
            preferredStyle: .actionSheet
        )
        if actor.role == .administrator || actor.role == .complianceReviewer {
            sheet.addAction(UIAlertAction(title: "Tombstone Entry", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                switch self.container.auditService.deleteLog(by: actor, logId: entry.id) {
                case .success: self.loadLogs()
                case .failure(let err): self.showError(err.message)
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}

extension AuditLogViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterText = searchText
        applyFilter()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filterText = ""
        applyFilter()
    }
}
