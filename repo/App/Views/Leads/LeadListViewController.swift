import UIKit

/// Lead list with status filters, masked phone numbers, SLA indicators.
final class LeadListViewController: BaseTableViewController {

    private lazy var viewModel = LeadViewModel(container: container)
    private let filterControl = UISegmentedControl(items: ["All", "New", "Follow-Up", "Closed", "Invalid"])

    init(container: ServiceContainer) {
        super.init(container: container, style: .plain)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Leads"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "lead")

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(didTapAdd)
        )

        filterControl.selectedSegmentIndex = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 50))
        filterControl.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(filterControl)
        NSLayoutConstraint.activate([
            filterControl.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            filterControl.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            filterControl.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        tableView.tableHeaderView = header

        viewModel.onStateChange = { [weak self] state in self?.applyState(state) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.loadLeads()
    }

    @objc private func filterChanged() {
        switch filterControl.selectedSegmentIndex {
        case 1: viewModel.filterStatus = .new
        case 2: viewModel.filterStatus = .followUp
        case 3: viewModel.filterStatus = .closedWon
        case 4: viewModel.filterStatus = .invalid
        default: viewModel.filterStatus = nil
        }
        viewModel.loadLeads()
    }

    @objc private func didTapAdd() {
        let vc = CreateLeadViewController(container: container)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Table

    override func tableView(_ tv: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.leads.count
    }

    override func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tv.dequeueReusableCell(withIdentifier: "lead", for: indexPath)
        let lead = viewModel.leads[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = lead.customerName
        config.secondaryText = "\(LeadService.maskPhone(lead.phone)) \u{2022} \(lead.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)"
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true

        // SLA indicator
        if lead.status == .new, let deadline = lead.slaDeadline, deadline < Date() {
            config.image = UIImage(systemName: "exclamationmark.circle.fill")
            config.imageProperties.tintColor = .systemRed
        } else {
            config.image = UIImage(systemName: "person.crop.rectangle")
            config.imageProperties.tintColor = .systemBlue
        }

        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: true)
        let lead = viewModel.leads[indexPath.row]
        let detail = LeadDetailViewController(container: container, leadId: lead.id)
        navigationController?.pushViewController(detail, animated: true)
    }
}
