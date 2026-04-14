import UIKit

/// Create lead form — calls real LeadService.createLead.
final class CreateLeadViewController: FormViewController {

    private lazy var viewModel = LeadViewModel(container: container)
    private let nameField: UITextField
    private let phoneField: UITextField
    private let vehicleField: UITextField
    private let windowField: UITextField
    private let consentField: UITextField
    private let typeControl = UISegmentedControl(items: ["Quote", "Appointment", "Contact"])
    private let submitButton: UIButton

    override init(container: ServiceContainer) {
        nameField = UITextField()
        phoneField = UITextField()
        vehicleField = UITextField()
        windowField = UITextField()
        consentField = UITextField()
        submitButton = UIButton(type: .system)
        super.init(container: container)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Lead"

        let fields: [(UITextField, String)] = [
            (nameField, "Customer Name"),
            (phoneField, "Phone (e.g., 415-555-0123)"),
            (vehicleField, "Vehicle Interest"),
            (windowField, "Preferred Contact Window"),
            (consentField, "Consent Notes"),
        ]
        for (tf, ph) in fields {
            tf.placeholder = ph
            tf.borderStyle = .roundedRect
            tf.font = .preferredFont(forTextStyle: .body)
            tf.adjustsFontForContentSizeCategory = true
            stackView.addArrangedSubview(tf)
        }
        phoneField.keyboardType = .phonePad

        typeControl.selectedSegmentIndex = 0
        stackView.addArrangedSubview(makeLabel(text: "Lead Type", style: .caption1))
        stackView.addArrangedSubview(typeControl)

        submitButton.setTitle("Create Lead", for: .normal)
        submitButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        submitButton.backgroundColor = .systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 10
        submitButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        stackView.addArrangedSubview(submitButton)
        stackView.addArrangedSubview(errorLabel)
    }

    @objc private func didTapSubmit() {
        clearFormError()
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""

        guard !name.isEmpty else { showFormError("Customer name is required"); return }
        guard !phone.isEmpty else { showFormError("Phone is required"); return }

        let type: LeadType
        switch typeControl.selectedSegmentIndex {
        case 1: type = .appointment
        case 2: type = .generalContact
        default: type = .quoteRequest
        }

        let input = LeadService.CreateLeadInput(
            leadType: type, customerName: name, phone: phone,
            vehicleInterest: vehicleField.text ?? "",
            preferredContactWindow: windowField.text ?? "",
            consentNotes: consentField.text ?? ""
        )

        let result = viewModel.createLead(input: input)
        switch result {
        case .success(let lead):
            // Schedule SLA notification
            if let deadline = lead.slaDeadline {
                NotificationService.shared.scheduleLeadSLAAlert(leadId: lead.id, customerName: lead.customerName, deadline: deadline)
            }
            navigationController?.popViewController(animated: true)
        case .failure(let error):
            showFormError(error.message)
        }
    }
}
