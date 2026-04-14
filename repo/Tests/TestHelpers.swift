import Foundation

/// Shared test helpers to create consistent test fixtures.
struct TestHelpers {

    static func makeAdmin(id: UUID = UUID()) -> User {
        User(
            id: id,
            username: "admin",
            passwordHash: "hash",
            passwordSalt: "salt",
            role: .administrator,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )
    }

    static func makeSalesAssociate(id: UUID = UUID(), username: String = "sales1") -> User {
        User(
            id: id,
            username: username,
            passwordHash: "hash",
            passwordSalt: "salt",
            role: .salesAssociate,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )
    }

    static func makeInventoryClerk(id: UUID = UUID()) -> User {
        User(
            id: id,
            username: "clerk1",
            passwordHash: "hash",
            passwordSalt: "salt",
            role: .inventoryClerk,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )
    }

    static func makeComplianceReviewer(id: UUID = UUID()) -> User {
        User(
            id: id,
            username: "reviewer1",
            passwordHash: "hash",
            passwordSalt: "salt",
            role: .complianceReviewer,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: true
        )
    }

    static func makeInactiveUser(id: UUID = UUID()) -> User {
        User(
            id: id,
            username: "inactive",
            passwordHash: "hash",
            passwordSalt: "salt",
            role: .salesAssociate,
            biometricEnabled: false,
            failedAttempts: 0,
            lastFailedAttempt: nil,
            lockoutUntil: nil,
            createdAt: Date(),
            isActive: false
        )
    }

    /// Track failure count for exit code
    static var failureCount = 0

    /// Assert a ServiceResult is success. Terminates test on failure.
    static func assertSuccess<T>(_ result: ServiceResult<T>, file: String = #file, line: Int = #line) -> T? {
        switch result {
        case .success(let val):
            return val
        case .failure(let err):
            failureCount += 1
            fatalError("FAIL [\(file):\(line)]: Expected success, got \(err.code): \(err.message)")
        }
    }

    /// Assert a ServiceResult is failure with expected code. Terminates on mismatch.
    static func assertFailure<T>(_ result: ServiceResult<T>, code: String, file: String = #file, line: Int = #line) {
        switch result {
        case .success:
            failureCount += 1
            fatalError("FAIL [\(file):\(line)]: Expected failure with code \(code), got success")
        case .failure(let err):
            if err.code != code {
                failureCount += 1
                fatalError("FAIL [\(file):\(line)]: Expected code \(code), got \(err.code)")
            }
        }
    }

    /// Assert condition. Terminates on failure.
    static func assert(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if !condition {
            failureCount += 1
            fatalError("FAIL [\(file):\(line)]: \(message)")
        }
    }
}
