import Foundation
#if canImport(CommonCrypto)
import CommonCrypto
#endif
#if canImport(Security)
import Security
#endif

/// Platform-portable crypto primitives.
///
/// On Apple platforms (iOS/macOS), delegates to CommonCrypto / Security for
/// hardware-accelerated and well-audited implementations.
/// On Linux (e.g. swift:5.9 Docker image used by CI), falls back to pure-Swift
/// implementations so the test suite can run without depending on Apple SDKs.
///
/// The shim surface is intentionally narrow — only the functions the project
/// actually uses are exposed. The Linux paths are deterministic and produce
/// valid SHA-256 / PBKDF2-HMAC-SHA256 outputs per FIPS 180-4 / RFC 2898.
enum CryptoShim {

    // MARK: - SHA-256

    /// Compute SHA-256 hex digest of arbitrary data.
    /// Output is 64 lowercase hex characters.
    static func sha256Hex(_ data: Data) -> String {
        let digest = sha256(data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Compute raw 32-byte SHA-256 digest.
    static func sha256(_ data: Data) -> [UInt8] {
        #if canImport(CommonCrypto)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash
        #else
        return PureSHA256.hash(Array(data))
        #endif
    }

    // MARK: - PBKDF2 / HMAC-SHA256

    /// Derive a key using PBKDF2-HMAC-SHA256 (RFC 2898).
    /// Returns nil only on invalid parameters (zero-length key).
    static func pbkdf2SHA256(password: Data, salt: Data, iterations: UInt32, keyLength: Int = 32) -> Data? {
        guard keyLength > 0 else { return nil }
        #if canImport(CommonCrypto)
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        let status = password.withUnsafeBytes { passwordPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordPtr.baseAddress?.assumingMemoryBound(to: Int8.self),
                    password.count,
                    saltPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    &derivedKey,
                    keyLength
                )
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(derivedKey)
        #else
        let result = PurePBKDF2.deriveSHA256(
            password: Array(password), salt: Array(salt),
            iterations: Int(iterations), keyLength: keyLength
        )
        return Data(result)
        #endif
    }

    // MARK: - Secure Random

    /// Fill with cryptographically secure random bytes.
    /// On Linux, reads from `/dev/urandom`.
    static func randomBytes(count: Int) -> Data {
        guard count > 0 else { return Data() }
        #if canImport(Security)
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
        #else
        // Read from /dev/urandom on Linux
        if let handle = FileHandle(forReadingAtPath: "/dev/urandom") {
            let data = handle.readData(ofLength: count)
            try? handle.close()
            if data.count == count { return data }
        }
        // Last-resort fallback (should never hit on a real Linux system)
        return Data((0..<count).map { _ in UInt8.random(in: 0...255) })
        #endif
    }
}

// MARK: - Pure-Swift SHA-256 (Linux fallback)

#if !canImport(CommonCrypto)
/// Pure-Swift SHA-256 implementation per FIPS 180-4.
/// Used only when CommonCrypto is unavailable (Linux CI).
enum PureSHA256 {
    private static let k: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]

    static func hash(_ input: [UInt8]) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]

        // Pre-processing: padding
        var message = input
        let originalBitLength = UInt64(input.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0x00)
        }
        for i in (0..<8).reversed() {
            message.append(UInt8((originalBitLength >> (UInt64(i) * 8)) & 0xff))
        }

        // Process each 512-bit block
        for blockStart in stride(from: 0, to: message.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let b = blockStart + i * 4
                w[i] = (UInt32(message[b]) << 24) |
                       (UInt32(message[b + 1]) << 16) |
                       (UInt32(message[b + 2]) << 8) |
                       UInt32(message[b + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]

            for i in 0..<64 {
                let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = hh &+ S1 &+ ch &+ k[i] &+ w[i]
                let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let mj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 &+ mj

                hh = g; g = f; f = e
                e = d &+ temp1
                d = c; c = b; b = a
                a = temp1 &+ temp2
            }

            h[0] = h[0] &+ a; h[1] = h[1] &+ b; h[2] = h[2] &+ c; h[3] = h[3] &+ d
            h[4] = h[4] &+ e; h[5] = h[5] &+ f; h[6] = h[6] &+ g; h[7] = h[7] &+ hh
        }

        var digest = [UInt8]()
        digest.reserveCapacity(32)
        for word in h {
            digest.append(UInt8((word >> 24) & 0xff))
            digest.append(UInt8((word >> 16) & 0xff))
            digest.append(UInt8((word >> 8) & 0xff))
            digest.append(UInt8(word & 0xff))
        }
        return digest
    }

    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        return (x >> n) | (x << (32 - n))
    }
}

// MARK: - Pure-Swift HMAC-SHA256 + PBKDF2 (Linux fallback)

enum PurePBKDF2 {
    private static let blockSize = 64 // SHA-256 block size

    /// HMAC-SHA256 per RFC 2104.
    static func hmacSHA256(key: [UInt8], message: [UInt8]) -> [UInt8] {
        var keyBlock = key
        if keyBlock.count > blockSize {
            keyBlock = PureSHA256.hash(keyBlock)
        }
        while keyBlock.count < blockSize {
            keyBlock.append(0x00)
        }

        var ipad = [UInt8](repeating: 0x36, count: blockSize)
        var opad = [UInt8](repeating: 0x5c, count: blockSize)
        for i in 0..<blockSize {
            ipad[i] ^= keyBlock[i]
            opad[i] ^= keyBlock[i]
        }

        let inner = PureSHA256.hash(ipad + message)
        return PureSHA256.hash(opad + inner)
    }

    /// PBKDF2-HMAC-SHA256 per RFC 2898.
    static func deriveSHA256(password: [UInt8], salt: [UInt8], iterations: Int, keyLength: Int) -> [UInt8] {
        let hLen = 32 // SHA-256 output size
        let blocks = Int((Double(keyLength) / Double(hLen)).rounded(.up))
        var derived = [UInt8]()
        derived.reserveCapacity(blocks * hLen)

        for i in 1...blocks {
            // INT_32_BE(i)
            let intBytes: [UInt8] = [
                UInt8((i >> 24) & 0xff),
                UInt8((i >> 16) & 0xff),
                UInt8((i >> 8) & 0xff),
                UInt8(i & 0xff)
            ]
            var u = hmacSHA256(key: password, message: salt + intBytes)
            var t = u
            for _ in 1..<iterations {
                u = hmacSHA256(key: password, message: u)
                for j in 0..<hLen {
                    t[j] ^= u[j]
                }
            }
            derived.append(contentsOf: t)
        }

        return Array(derived.prefix(keyLength))
    }
}
#endif
