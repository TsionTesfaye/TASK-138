import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif
#if canImport(Security)
import Security
#endif

/// AES-256-CBC encryption for sensitive fields.
/// design.md section 5: AES encryption for sensitive fields, keys stored in Keychain.
/// Applied at repository layer, not UI.
protocol EncryptionServiceProtocol {
    func encrypt(_ plaintext: String, recordId: UUID) -> String?
    func decrypt(_ ciphertext: String, recordId: UUID) -> String?
}

// The real AES-backed EncryptionService depends on CommonCrypto (Apple-only).
// On Linux, only the protocol and InMemoryEncryptionService (below) are available,
// which is sufficient for the test suite.
#if canImport(CommonCrypto) && canImport(Security)
final class EncryptionService: EncryptionServiceProtocol {

    private let keychainService: KeychainServiceProtocol

    init(keychainService: KeychainServiceProtocol) {
        self.keychainService = keychainService
    }

    /// Encrypt a plaintext string. Generates and stores a per-record key if one doesn't exist.
    func encrypt(_ plaintext: String, recordId: UUID) -> String? {
        guard let data = plaintext.data(using: .utf8) else { return nil }

        let key = getOrCreateKey(recordId: recordId)

        // Generate random IV (16 bytes for AES)
        var iv = Data(count: kCCBlockSizeAES128)
        let ivResult = iv.withUnsafeMutableBytes { ivPtr in
            SecRandomCopyBytes(kSecRandomDefault, kCCBlockSizeAES128, ivPtr.baseAddress!)
        }
        guard ivResult == errSecSuccess else { return nil }

        // Encrypt
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesEncrypted = 0

        let status = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                data.withUnsafeBytes { dataPtr in
                    buffer.withUnsafeMutableBytes { bufferPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, kCCKeySizeAES256,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        buffer.count = numBytesEncrypted

        // Prepend IV to ciphertext, encode as base64
        var combined = iv
        combined.append(buffer)
        return combined.base64EncodedString()
    }

    /// Decrypt a base64-encoded ciphertext string using the per-record key.
    func decrypt(_ ciphertext: String, recordId: UUID) -> String? {
        guard let combined = Data(base64Encoded: ciphertext) else { return nil }
        guard combined.count > kCCBlockSizeAES128 else { return nil }
        guard let key = keychainService.retrieveKey(recordId: recordId) else { return nil }

        let iv = combined.prefix(kCCBlockSizeAES128)
        let encrypted = combined.suffix(from: kCCBlockSizeAES128)

        let bufferSize = encrypted.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var numBytesDecrypted = 0

        let status = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                encrypted.withUnsafeBytes { dataPtr in
                    buffer.withUnsafeMutableBytes { bufferPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, kCCKeySizeAES256,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, encrypted.count,
                            bufferPtr.baseAddress, bufferSize,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { return nil }
        buffer.count = numBytesDecrypted
        return String(data: buffer, encoding: .utf8)
    }

    // MARK: - Key Management

    private func getOrCreateKey(recordId: UUID) -> Data {
        if let existing = keychainService.retrieveKey(recordId: recordId) {
            return existing
        }
        // Generate 256-bit key
        var key = Data(count: kCCKeySizeAES256)
        _ = key.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, ptr.baseAddress!)
        }
        _ = keychainService.storeKey(recordId: recordId, key: key)
        return key
    }
}
#endif

/// In-memory encryption for tests — uses simple reversible encoding, not real AES.
final class InMemoryEncryptionService: EncryptionServiceProtocol {
    private var keys: [UUID: Data] = [:]

    func encrypt(_ plaintext: String, recordId: UUID) -> String? {
        // Simple base64 "encryption" for test verifiability
        let marker = "ENC:"
        return marker + Data(plaintext.utf8).base64EncodedString()
    }

    func decrypt(_ ciphertext: String, recordId: UUID) -> String? {
        let marker = "ENC:"
        guard ciphertext.hasPrefix(marker) else { return ciphertext }
        let b64 = String(ciphertext.dropFirst(marker.count))
        guard let data = Data(base64Encoded: b64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
