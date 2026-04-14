import UIKit

/// Centralized theming constants for consistent UI across the app.
/// All colors use system semantic colors for automatic Dark Mode support.
/// All fonts use preferredFont for Dynamic Type support.
enum Theme {

    // MARK: - Spacing

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24
    static let cornerRadius: CGFloat = 10
    static let minTouchTarget: CGFloat = 44 // Apple HIG minimum

    // MARK: - Colors

    static let primaryAction = UIColor.systemBlue
    static let destructiveAction = UIColor.systemRed
    static let successColor = UIColor.systemGreen
    static let warningColor = UIColor.systemOrange
    static let slaViolation = UIColor.systemRed
    static let slaOk = UIColor.systemGreen

    // MARK: - Buttons

    static func primaryButton(_ title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        btn.backgroundColor = primaryAction
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = cornerRadius
        btn.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        // Ensure minimum touch target
        btn.heightAnchor.constraint(greaterThanOrEqualToConstant: minTouchTarget).isActive = true
        return btn
    }

    static func secondaryButton(_ title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .body)
        btn.titleLabel?.adjustsFontForContentSizeCategory = true
        btn.heightAnchor.constraint(greaterThanOrEqualToConstant: minTouchTarget).isActive = true
        return btn
    }

    // MARK: - TextField

    static func styledTextField(placeholder: String, secure: Bool = false) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.font = .preferredFont(forTextStyle: .body)
        tf.adjustsFontForContentSizeCategory = true
        tf.isSecureTextEntry = secure
        tf.autocapitalizationType = secure ? .none : .words
        tf.heightAnchor.constraint(greaterThanOrEqualToConstant: minTouchTarget).isActive = true
        return tf
    }

    // MARK: - SLA Badge

    static func slaBadgeColor(for lead: Lead) -> UIColor {
        guard lead.status == .new, let deadline = lead.slaDeadline else { return .clear }
        return deadline < Date() ? slaViolation : slaOk
    }
}
