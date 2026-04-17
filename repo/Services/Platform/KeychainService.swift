import Foundation
#if canImport(Security)
import Security
#endif

/// Real Keychain integration for storing per-record encryption keys.
protocol KeychainServiceProtocol {
    func storeKey(recordId: UUID, key: Data) -> Bool
    func retrieveKey(recordId: UUID) -> Data?
    func deleteKey(recordId: UUID) -> Bool
}

// The real Keychain-backed implementation depends on the Security framework (Apple-only).
// On Linux, only the protocol and InMemoryKeychainService (below) are available.
#if canImport(Security)
final class KeychainService: KeychainServiceProtocol {

    private let servicePrefix = "com.dealerops.encryption"

    private func account(for recordId: UUID) -> String {
        "\(servicePrefix).\(recordId.uuidString)"
    }

    func storeKey(recordId: UUID, key: Data) -> Bool {
        let acct = account(for: recordId)

        // Delete existing if present
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: acct,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: acct,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    func retrieveKey(recordId: UUID) -> Data? {
        let acct = account(for: recordId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: acct,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func deleteKey(recordId: UUID) -> Bool {
        let acct = account(for: recordId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicePrefix,
            kSecAttrAccount as String: acct,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
#endif

/// In-memory implementation for tests.
final class InMemoryKeychainService: KeychainServiceProtocol {
    private var store: [UUID: Data] = [:]

    func storeKey(recordId: UUID, key: Data) -> Bool {
        store[recordId] = key
        return true
    }
    func retrieveKey(recordId: UUID) -> Data? {
        store[recordId]
    }
    func deleteKey(recordId: UUID) -> Bool {
        store.removeValue(forKey: recordId)
        return true
    }
}
