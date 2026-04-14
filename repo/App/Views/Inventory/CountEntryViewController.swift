import UIKit

/// Count entry screen: create batch, enter counts, compute variances.
final class CountEntryViewController: FormViewController {

    private lazy var viewModel = InventoryViewModel(container: container)
    private let taskId: UUID
    private var currentBatchId: UUID?
    private let scanField: UITextField
    private let qtyField: UITextField
    private let locationField: UITextField
    private let custodianField: UITextField
    private let resultsLabel = UILabel()

    init(container: ServiceContainer, taskId: UUID) {
        self.taskId = taskId
        scanField = UITextField()
        qtyField = UITextField()
        locationField = UITextField()
        custodianField = UITextField()
        super.init(container: container)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Count Entry"

        let fields: [(UITextField, String)] = [
            (scanField, "Item Identifier (scanner input)"),
            (qtyField, "Counted Quantity"),
            (locationField, "Counted Location"),
            (custodianField, "Counted Custodian"),
        ]
        for (tf, ph) in fields {
            tf.placeholder = ph; tf.borderStyle = .roundedRect
            tf.font = .preferredFont(forTextStyle: .body)
            tf.adjustsFontForContentSizeCategory = true
            stackView.addArrangedSubview(tf)
        }
        qtyField.keyboardType = .numberPad

        let recordBtn = makeButton(title: "Record Count")
        recordBtn.addTarget(self, action: #selector(didTapRecord), for: .touchUpInside)
        stackView.addArrangedSubview(recordBtn)

        let computeBtn = makeButton(title: "Compute Variances", style: .secondary)
        computeBtn.addTarget(self, action: #selector(didTapCompute), for: .touchUpInside)
        stackView.addArrangedSubview(computeBtn)

        resultsLabel.numberOfLines = 0
        resultsLabel.font = .preferredFont(forTextStyle: .body)
        resultsLabel.adjustsFontForContentSizeCategory = true
        stackView.addArrangedSubview(resultsLabel)
        stackView.addArrangedSubview(errorLabel)

        // Create batch automatically
        createBatchIfNeeded()
    }

    private func createBatchIfNeeded() {
        if currentBatchId == nil {
            switch viewModel.createBatch(taskId: taskId) {
            case .success(let batch): currentBatchId = batch.id
            case .failure(let err): showFormError(err.message)
            }
        }
    }

    @objc private func didTapRecord() {
        clearFormError()
        guard let batchId = currentBatchId else { showFormError("No active batch"); return }
        let identifier = scanField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !identifier.isEmpty else { showFormError("Enter item identifier"); return }
        guard let qty = Int(qtyField.text ?? ""), qty >= 0 else { showFormError("Enter valid quantity"); return }

        // Scanner lookup first
        switch viewModel.scannerLookup(identifier) {
        case .success(let item):
            let loc = locationField.text ?? item.location
            let cust = custodianField.text ?? item.custodian
            switch viewModel.recordEntry(batchId: batchId, itemId: item.id, qty: qty, location: loc, custodian: cust) {
            case .success:
                resultsLabel.text = "Recorded: \(item.identifier) x \(qty)"
                resultsLabel.textColor = .systemGreen
                scanField.text = ""; qtyField.text = ""
            case .failure(let err): showFormError(err.message)
            }
        case .failure(let err): showFormError(err.message)
        }
    }

    @objc private func didTapCompute() {
        clearFormError()
        guard let batchId = currentBatchId else { showFormError("No active batch"); return }
        switch viewModel.computeVariances(batchId: batchId) {
        case .success(let variances):
            if variances.isEmpty {
                resultsLabel.text = "No variances detected"
                resultsLabel.textColor = .systemGreen
            } else {
                let text = variances.map { v in
                    let approval = v.requiresApproval ? " [REQUIRES APPROVAL]" : ""
                    return "\(v.type.rawValue): expected \(v.expectedQty), counted \(v.countedQty)\(approval)"
                }.joined(separator: "\n")
                resultsLabel.text = "Variances:\n\(text)"
                resultsLabel.textColor = .systemOrange
            }
        case .failure(let err):
            showFormError(err.message)
        }
    }
}
