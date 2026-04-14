import Foundation
import os.log

/// Centralized diagnostic logger for all services.
/// Uses os.log / Logger for structured, privacy-safe logging.
/// NEVER logs sensitive data (passwords, phone numbers, PII).
enum ServiceLogger {
    static let auth = Logger(subsystem: "com.dealerops", category: "Auth")
    static let leads = Logger(subsystem: "com.dealerops", category: "Leads")
    static let inventory = Logger(subsystem: "com.dealerops", category: "Inventory")
    static let carpool = Logger(subsystem: "com.dealerops", category: "Carpool")
    static let exceptions = Logger(subsystem: "com.dealerops", category: "Exceptions")
    static let files = Logger(subsystem: "com.dealerops", category: "Files")
    static let sla = Logger(subsystem: "com.dealerops", category: "SLA")
    static let persistence = Logger(subsystem: "com.dealerops", category: "Persistence")

    /// Log a non-critical persistence failure that was previously silently swallowed.
    static func persistenceError(_ logger: Logger, operation: String, error: Error) {
        logger.error("Persistence failed: \(operation) — \(error.localizedDescription)")
    }
}
