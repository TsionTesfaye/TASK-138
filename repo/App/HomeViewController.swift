import UIKit

/// Home screen with one real service call: create lead.
/// Proves end-to-end wiring: UI → Service → Repository → Core Data.
final class HomeViewController: UIViewController {

    private let container: ServiceContainer
    private let statusLabel = UILabel()
    var site: String = ""

    init(container: ServiceContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DealerOps"
        view.backgroundColor = .systemBackground

        let welcomeLabel = UILabel()
        welcomeLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        welcomeLabel.adjustsFontForContentSizeCategory = true
        welcomeLabel.text = "Welcome, \(container.sessionService.currentUser?.username ?? "User")"

        let roleLabel = UILabel()
        roleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        roleLabel.adjustsFontForContentSizeCategory = true
        roleLabel.text = "Role: \(container.sessionService.currentUser?.role.rawValue ?? "unknown")"
        roleLabel.textColor = .secondaryLabel

        let createLeadButton = UIButton(type: .system)
        createLeadButton.setTitle("Create Sample Lead", for: .normal)
        createLeadButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        createLeadButton.addTarget(self, action: #selector(didTapCreateLead), for: .touchUpInside)

        statusLabel.numberOfLines = 0
        statusLabel.font = UIFont.preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [welcomeLabel, roleLabel, createLeadButton, statusLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        ])

        // Record activity for session timeout
        container.sessionService.recordActivity()
    }

    @objc private func didTapCreateLead() {
        guard let user = container.sessionService.currentUser else {
            statusLabel.text = "Error: No active session"
            return
        }

        let input = LeadService.CreateLeadInput(
            leadType: .quoteRequest,
            customerName: "Jane Doe",
            phone: "415-555-0123",
            vehicleInterest: "2024 Honda Accord",
            preferredContactWindow: "Morning",
            consentNotes: "Verbal consent given"
        )

        // REAL service call → repository → Core Data
        let result = container.leadService.createLead(by: user, site: site, input: input, operationId: UUID())

        switch result {
        case .success(let lead):
            // Retrieve from service to prove persistence
            if case .success(let retrieved) = container.leadService.findById(by: user, site: site, lead.id) {
                let maskedPhone = LeadService.maskPhone(retrieved?.phone ?? "")

                statusLabel.text = """
                Lead created successfully!
                ID: \(lead.id.uuidString.prefix(8))...
                Status: \(lead.status.rawValue)
                Customer: \(lead.customerName)
                Phone (masked): \(maskedPhone)
                SLA Deadline: \(lead.slaDeadline.map { "\($0)" } ?? "none")
                Persisted: \(retrieved != nil ? "YES" : "NO")
                """
                statusLabel.textColor = .systemGreen
            }
        case .failure(let error):
            statusLabel.text = "Error: \(error.code) — \(error.message)"
            statusLabel.textColor = .systemRed
        }
    }
}
