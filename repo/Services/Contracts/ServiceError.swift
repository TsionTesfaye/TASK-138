import Foundation

/// Unified structured error type across all services.
/// design.md 5.1: reject operation, return structured error with code + message.
struct ServiceError: Error, Equatable {
    let code: String
    let message: String

    // MARK: - Authentication Errors
    static func accountLocked(until: Date) -> ServiceError {
        ServiceError(code: "AUTH_LOCKED", message: "Account locked until \(until)")
    }
    static let invalidCredentials = ServiceError(code: "AUTH_INVALID", message: "Invalid username or password")
    static let accountInactive = ServiceError(code: "AUTH_INACTIVE", message: "Account is deactivated")
    static let biometricNotEnabled = ServiceError(code: "AUTH_BIO_DISABLED", message: "Biometric authentication not enabled")
    static let biometricUnavailable = ServiceError(code: "AUTH_BIO_UNAVAIL", message: "Biometric authentication unavailable on this device")
    static let sessionExpired = ServiceError(code: "SESSION_EXPIRED", message: "Session expired, re-authentication required")
    static let bootstrapAlreadyComplete = ServiceError(code: "AUTH_BOOTSTRAP_DONE", message: "Bootstrap already completed")
    static let passwordReEntryRequired = ServiceError(code: "AUTH_PASS_REQUIRED", message: "Password re-entry required for this action")

    // MARK: - Password Errors
    static let passwordTooShort = ServiceError(code: "PASS_SHORT", message: "Password must be at least 12 characters")
    static let passwordMissingUppercase = ServiceError(code: "PASS_NO_UPPER", message: "Password must contain at least 1 uppercase letter")
    static let passwordMissingLowercase = ServiceError(code: "PASS_NO_LOWER", message: "Password must contain at least 1 lowercase letter")
    static let passwordMissingNumber = ServiceError(code: "PASS_NO_NUMBER", message: "Password must contain at least 1 number")

    // MARK: - Permission Errors
    static let permissionDenied = ServiceError(code: "PERM_DENIED", message: "Permission denied")
    static let scopeDenied = ServiceError(code: "SCOPE_DENIED", message: "Access denied: no valid scope")
    static let adminRequired = ServiceError(code: "PERM_ADMIN_REQ", message: "Administrator role required")

    // MARK: - Validation Errors
    static let missingRequiredField = ServiceError(code: "VAL_REQUIRED", message: "Required field is missing")
    static let invalidEnumValue = ServiceError(code: "VAL_ENUM", message: "Invalid enum value")
    static let invalidTransition = ServiceError(code: "STATE_INVALID", message: "Invalid state transition")
    static func validationFailed(_ field: String, _ reason: String) -> ServiceError {
        ServiceError(code: "VAL_FAILED", message: "\(field): \(reason)")
    }

    // MARK: - Entity Errors
    static let entityNotFound = ServiceError(code: "ENTITY_NOT_FOUND", message: "Entity not found")
    static let duplicateEntity = ServiceError(code: "ENTITY_DUPLICATE", message: "Entity already exists")
    static let duplicateOperation = ServiceError(code: "OP_DUPLICATE", message: "Duplicate operation ignored")

    // MARK: - File Errors
    static let fileTooLarge = ServiceError(code: "FILE_TOO_LARGE", message: "File exceeds size limit")
    static let invalidFileFormat = ServiceError(code: "FILE_FORMAT", message: "Invalid file format")
    static let fileNotFound = ServiceError(code: "FILE_NOT_FOUND", message: "File not found")

    // MARK: - Inventory Errors
    static let approvalRequired = ServiceError(code: "INV_APPROVAL_REQ", message: "Admin approval required for this variance")
    static let invalidScanInput = ServiceError(code: "INV_SCAN_INVALID", message: "Scanner input does not match any inventory item")

    // MARK: - Carpool Errors
    static let noSeatsAvailable = ServiceError(code: "POOL_NO_SEATS", message: "No seats available")
    static let detourExceedsThreshold = ServiceError(code: "POOL_DETOUR", message: "Detour exceeds threshold")
    static let insufficientTimeOverlap = ServiceError(code: "POOL_TIME", message: "Insufficient time overlap")
}

/// Result type used across all services
typealias ServiceResult<T> = Result<T, ServiceError>
