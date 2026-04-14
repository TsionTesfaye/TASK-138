import UIKit

/// Reusable base table view controller with loading/error/empty state handling.
/// Supports Dynamic Type, Dark Mode, Safe Area, Auto Layout.
class BaseTableViewController: UITableViewController {

    let container: ServiceContainer
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    init(container: ServiceContainer, style: UITableView.Style = .insetGrouped) {
        self.container = container
        super.init(style: style)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    func applyState(_ state: BaseViewModel.ViewState) {
        switch state {
        case .idle:
            activityIndicator.stopAnimating()
            statusLabel.isHidden = true
            tableView.isHidden = false
        case .loading:
            activityIndicator.startAnimating()
            statusLabel.isHidden = true
            tableView.isHidden = true
        case .loaded:
            activityIndicator.stopAnimating()
            statusLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        case .empty(let message):
            activityIndicator.stopAnimating()
            statusLabel.text = message
            statusLabel.textColor = .secondaryLabel
            statusLabel.isHidden = false
            tableView.isHidden = true
        case .error(let message):
            activityIndicator.stopAnimating()
            statusLabel.text = message
            statusLabel.textColor = .systemRed
            statusLabel.isHidden = false
            tableView.isHidden = true
        }
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showSuccess(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
