import Foundation

// MARK: - Logger shim
//
// Apple platforms provide `os.Logger`. Linux (e.g. swift:5.9 Docker image used by CI)
// does not have the `os` module. We conditionally import the Apple Logger, and provide
// a minimal `Logger` shim on Linux that forwards to `FileHandle.standardError` using
// the same `info`/`error` API surface the codebase actually uses.
#if canImport(os)
import os.log
#else
/// Linux shim for Apple's os.Logger. Supports the subset of the API used in this project.
struct Logger {
    let subsystem: String
    let category: String

    init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    func info(_ message: @autoclosure () -> String) {
        emit(level: "INFO", message: message())
    }

    func error(_ message: @autoclosure () -> String) {
        emit(level: "ERROR", message: message())
    }

    private func emit(level: String, message: String) {
        let line = "[\(level)] [\(subsystem)/\(category)] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
#endif

/// Centralized diagnostic logger for all services.
/// Uses os.log / Logger for structured, privacy-safe logging on Apple platforms,
/// and a stderr-backed shim on Linux.
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
