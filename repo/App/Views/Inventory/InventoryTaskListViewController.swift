import UIKit

/// Inventory task list with batch creation, count entry, scanner, variance display, approval.
final class InventoryTaskListViewController: BaseTableViewController {

    private lazy var viewModel = InventoryViewModel(container: container)

    init(container: ServiceContainer) {
        super.init(container: container, style: .insetGrouped)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inventory"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        let addBtn = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapCreateTask))
        let scanBtn = UIBarButtonItem(image: UIImage(systemName: "barcode.viewfinder"), style: .plain, target: self, action: #selector(didTapScan))
        navigationItem.rightBarButtonItems = [addBtn, scanBtn]

        viewModel.onStateChange = { [weak self] state in self?.applyState(state) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadTasks()
        viewModel.loadPendingVariances()
    }

    @objc private func didTapCreateTask() {
        guard let user = container.sessionService.currentUser else { return }
        let result = viewModel.createTask(assignedTo: user.id)
        switch result {
        case .success: viewModel.loadTasks()
        case .failure(let err): showError(err.message)
        }
    }

    @objc private func didTapScan() {
        let alert = UIAlertController(title: "Scanner Input", message: "Enter item identifier", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Identifier (e.g., VIN-12345)" }
        alert.addAction(UIAlertAction(title: "Lookup", style: .default) { [weak self] _ in
            guard let self = self, let text = alert.textFields?.first?.text else { return }
            switch self.viewModel.scannerLookup(text) {
            case .success(let item):
                self.showSuccess("Found: \(item.identifier) — Qty: \(item.expectedQty) @ \(item.location)")
            case .failure(let err):
                self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Table (Sections: Tasks, Pending Variances)

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tv: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Count Tasks" : "Pending Variances (\(viewModel.variances.count))"
    }

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? max(viewModel.tasks.count, 1) : max(viewModel.variances.count, 1)
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true

        if indexPath.section == 0 {
            if viewModel.tasks.isEmpty {
                config.text = "No tasks. Tap + to create."
                config.textProperties.color = .secondaryLabel
            } else {
                let task = viewModel.tasks[indexPath.row]
                config.text = "Task \(task.id.uuidString.prefix(8))..."
                config.secondaryText = task.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
                config.image = UIImage(systemName: "checklist")
                cell.accessoryType = .disclosureIndicator
            }
        } else {
            if viewModel.variances.isEmpty {
                config.text = "No pending variances"
                config.textProperties.color = .secondaryLabel
            } else {
                let v = viewModel.variances[indexPath.row]
                config.text = "\(v.type.rawValue.replacingOccurrences(of: "_", with: " ").capitalized): expected \(v.expectedQty), counted \(v.countedQty)"
                config.secondaryText = v.requiresApproval ? "Requires Admin Approval" : "Auto-approved"
                config.image = UIImage(systemName: "exclamationmark.triangle")
                config.imageProperties.tintColor = .systemOrange
                if container.sessionService.currentUser?.role == .administrator {
                    cell.accessoryType = .disclosureIndicator
                }
            }
        }
        cell.contentConfiguration = config
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && !viewModel.tasks.isEmpty {
            let task = viewModel.tasks[indexPath.row]
            let vc = CountEntryViewController(container: container, taskId: task.id)
            navigationController?.pushViewController(vc, animated: true)
        } else if indexPath.section == 1 && !viewModel.variances.isEmpty {
            let v = viewModel.variances[indexPath.row]
            if container.sessionService.currentUser?.role == .administrator {
                promptApproveVariance(v)
            }
        }
    }

    private func promptApproveVariance(_ variance: Variance) {
        let alert = UIAlertController(
            title: "Approve Variance?",
            message: "\(variance.type.rawValue): expected \(variance.expectedQty), counted \(variance.countedQty)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Approve & Execute", style: .default) { [weak self] _ in
            guard let self = self else { return }
            switch self.viewModel.approveVariance(varianceId: variance.id) {
            case .success(let order):
                switch self.viewModel.executeAdjustment(orderId: order.id) {
                case .success: self.showSuccess("Adjustment applied"); self.viewModel.loadPendingVariances(); self.tableView.reloadData()
                case .failure(let err): self.showError(err.message)
                }
            case .failure(let err): self.showError(err.message)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
