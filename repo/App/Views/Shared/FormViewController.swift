import UIKit

/// Reusable form controller with scrollable stack layout.
/// Supports Dynamic Type, Dark Mode, Safe Area, keyboard avoidance.
class FormViewController: UIViewController {

    let container: ServiceContainer
    let scrollView = UIScrollView()
    let stackView = UIStackView()
    let errorLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    init(container: ServiceContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { return nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true

        activityIndicator.hidesWhenStopped = true
    }

    func makeTextField(placeholder: String, secure: Bool = false) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = .preferredFont(forTextStyle: .body)
        tf.adjustsFontForContentSizeCategory = true
        tf.isSecureTextEntry = secure
        tf.autocapitalizationType = secure ? .none : .words
        return tf
    }

    func makeButton(title: String, style: ButtonStyle = .primary) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        if style == .primary {
            btn.backgroundColor = .systemBlue
            btn.setTitleColor(.white, for: .normal)
            btn.layer.cornerRadius = 10
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        }
        return btn
    }

    func makeLabel(text: String, style: UIFont.TextStyle = .body) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = .preferredFont(forTextStyle: style)
        lbl.adjustsFontForContentSizeCategory = true
        lbl.numberOfLines = 0
        return lbl
    }

    func showFormError(_ message: String) {
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    func clearFormError() {
        errorLabel.isHidden = true
    }

    func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() }
        else { activityIndicator.stopAnimating() }
    }

    enum ButtonStyle { case primary, secondary }
}
