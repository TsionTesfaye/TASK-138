import UIKit

/// Login screen: authenticates via AuthService.
final class LoginViewController: UIViewController {

    private let container: ServiceContainer
    var isReAuth = false

    private let usernameField = UITextField()
    private let passwordField = UITextField()
    private let loginButton = UIButton(type: .system)
    private let biometricButton = UIButton(type: .system)
    private let biometricToggleButton = UIButton(type: .system)
    private let errorLabel = UILabel()

    init(container: ServiceContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isReAuth ? "Session Expired" : "Login"
        view.backgroundColor = .systemBackground

        usernameField.placeholder = "Username"
        usernameField.borderStyle = .roundedRect
        usernameField.autocapitalizationType = .none
        usernameField.font = UIFont.preferredFont(forTextStyle: .body)
        usernameField.adjustsFontForContentSizeCategory = true

        passwordField.placeholder = "Password"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true
        passwordField.font = UIFont.preferredFont(forTextStyle: .body)
        passwordField.adjustsFontForContentSizeCategory = true

        loginButton.setTitle("Login", for: .normal)
        loginButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        loginButton.titleLabel?.adjustsFontForContentSizeCategory = true
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)

        biometricButton.setTitle("Use Face ID / Touch ID", for: .normal)
        biometricButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        biometricButton.addTarget(self, action: #selector(didTapBiometric), for: .touchUpInside)

        biometricToggleButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .footnote)
        biometricToggleButton.addTarget(self, action: #selector(didTapBiometricToggle), for: .touchUpInside)
        biometricToggleButton.isHidden = true

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true

        let stack = UIStackView(arrangedSubviews: [usernameField, passwordField, loginButton, biometricButton, biometricToggleButton, errorLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
        ])

        // Show biometric button only if a biometric-enabled user exists
        let hasBiometricUser = container.sessionService.biometricUser() != nil
        biometricButton.isHidden = !hasBiometricUser && !isReAuth
    }

    @objc private func didTapLogin() {
        let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""

        // Call AuthService.login — real service, real persistence
        let result = container.authService.login(username: username, password: password)
        switch result {
        case .success(let user):
            container.sessionService.startSession(user: user)
            container.currentSite = container.resolvedSite(for: user)
            updateBiometricToggle(for: user)
            if isReAuth {
                dismiss(animated: true)
            } else {
                (UIApplication.shared.delegate as? AppDelegate)?.showMainApp()
            }
        case .failure(let error):
            errorLabel.text = error.message
        }
    }

    @objc private func didTapBiometric() {
        let bioService = BiometricService()

        guard bioService.isBiometricAvailable() else {
            errorLabel.text = "Biometric authentication not available on this device"
            return
        }

        bioService.authenticate(reason: "Log in to DealerOps") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if success {
                    // Look up the persisted biometric user (survives app restart)
                    if let user = self.container.sessionService.biometricUser() {
                        self.container.sessionService.startSession(user: user)
                        self.container.currentSite = self.container.resolvedSite(for: user)
                        if self.isReAuth {
                            self.dismiss(animated: true)
                        } else {
                            (UIApplication.shared.delegate as? AppDelegate)?.showMainApp()
                        }
                    } else {
                        self.errorLabel.text = "Biometric login not enabled. Please log in with password first, then enable biometric."
                    }
                } else {
                    self.errorLabel.text = error ?? "Biometric authentication failed"
                }
            }
        }
    }

    @objc private func didTapBiometricToggle() {
        guard let user = container.sessionService.currentUser else { return }

        let isEnabled = user.biometricEnabled
        let action = isEnabled ? "Disable" : "Enable"
        let alert = UIAlertController(
            title: "\(action) Biometric Login",
            message: "Enter your password to confirm.",
            preferredStyle: .alert
        )
        alert.addTextField { $0.placeholder = "Password"; $0.isSecureTextEntry = true }
        alert.addAction(UIAlertAction(title: action, style: .default) { [weak self] _ in
            guard let self = self, let password = alert.textFields?.first?.text else { return }
            let result: ServiceResult<Void>
            if isEnabled {
                result = self.container.authService.disableBiometric(userId: user.id, password: password)
            } else {
                result = self.container.authService.enableBiometric(userId: user.id, password: password)
            }
            switch result {
            case .success:
                // Refresh user in session to reflect updated biometricEnabled
                if let updated = self.container.sessionService.userRepo?.findById(user.id) {
                    self.container.sessionService.startSession(user: updated)
                }
                self.updateBiometricToggle(for: self.container.sessionService.currentUser)
            case .failure(let err):
                self.errorLabel.text = err.message
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func updateBiometricToggle(for user: User?) {
        guard let user = user else {
            biometricToggleButton.isHidden = true
            return
        }
        let bioService = BiometricService()
        if bioService.isBiometricAvailable() {
            biometricToggleButton.isHidden = false
            let title = user.biometricEnabled ? "Disable Biometric Login" : "Enable Biometric Login"
            biometricToggleButton.setTitle(title, for: .normal)
        } else {
            biometricToggleButton.isHidden = true
        }
    }
}
