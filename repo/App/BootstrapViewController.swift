import UIKit

/// One-time bootstrap screen: creates the first Administrator.
/// This screen only appears when User.count == 0.
final class BootstrapViewController: UIViewController {

    private let container: ServiceContainer
    private let usernameField = UITextField()
    private let passwordField = UITextField()
    private let createButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(container: ServiceContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "DealerOps Setup"
        view.backgroundColor = .systemBackground

        usernameField.placeholder = "Username"
        usernameField.borderStyle = .roundedRect
        usernameField.autocapitalizationType = .none
        usernameField.font = UIFont.preferredFont(forTextStyle: .body)
        usernameField.adjustsFontForContentSizeCategory = true

        passwordField.placeholder = "Password (min 12 chars, 1 upper, 1 lower, 1 number)"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.font = UIFont.preferredFont(forTextStyle: .body)
        passwordField.adjustsFontForContentSizeCategory = true

        createButton.setTitle("Create Administrator", for: .normal)
        createButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        createButton.titleLabel?.adjustsFontForContentSizeCategory = true
        createButton.addTarget(self, action: #selector(didTapCreate), for: .touchUpInside)

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [usernameField, passwordField, createButton, errorLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        ])
    }

    @objc private func didTapCreate() {
        let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""

        guard !username.isEmpty else {
            errorLabel.text = "Username is required"
            return
        }

        // Call AuthService.bootstrap — real service, real Core Data
        let result = container.authService.bootstrap(username: username, password: password)
        switch result {
        case .success(let user):
            container.sessionService.startSession(user: user)
            (UIApplication.shared.delegate as? AppDelegate)?.showMainApp()
        case .failure(let error):
            errorLabel.text = error.message
        }
    }
}
