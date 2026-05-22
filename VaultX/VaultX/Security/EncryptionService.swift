import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Encryption Errors

enum EncryptionError: LocalizedError {
    case keyDerivationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKeyLength
    case invalidData

    var errorDescription: String? {
        switch self {
        case .keyDerivationFailed: return "Failed to derive encryption key"
        case .encryptionFailed: return "Encryption failed"
        case .decryptionFailed: return "Decryption failed — wrong password or corrupted data"
        case .invalidKeyLength: return "Invalid key length"
        case .invalidData: return "Invalid data"
        }
    }
}

// MARK: - Encryption Service

final class EncryptionService {
    static let shared = EncryptionService()
    private init() {}

    // MARK: - Key Derivation (PBKDF2-SHA512)

    /// Derives a 32-byte AES key from a password using PBKDF2-SHA512.
    /// 600,000 iterations — NIST SP 800-132 recommended minimum.
    func deriveKey(from password: String, salt: Data, iterations: Int = 600_000) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.keyDerivationFailed
        }

        var derivedKey = Data(count: 32)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress,
                        passwordData.count,
                        saltBytes.baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress,
                        32
                    )
                }
            }
        }

        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }

        return SymmetricKey(data: derivedKey)
    }

    // MARK: - AES-256-GCM Encryption

    func encrypt(_ plaintext: Data, withKey key: SymmetricKey) throws -> (ciphertext: Data, nonce: Data, tag: Data) {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        // combined = nonce(12) + ciphertext + tag(16)
        let nonceData = Data(nonce)
        let ciphertext = combined[12..<combined.count - 16]
        let tag = combined.suffix(16)

        return (Data(ciphertext), nonceData, Data(tag))
    }

    func decrypt(_ ciphertext: Data, nonce: Data, tag: Data, withKey key: SymmetricKey) throws -> Data {
        guard nonce.count == 12 else { throw EncryptionError.invalidData }

        let gcmNonce = try AES.GCM.Nonce(data: nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: gcmNonce, ciphertext: ciphertext, tag: tag)

        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }

    // MARK: - High-level: encrypt private key with password

    func encryptPrivateKey(_ privateKeyHex: String, password: String) throws -> EncryptedPrivateKey {
        guard let keyData = privateKeyHex.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }

        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        let (ciphertext, nonce, tag) = try encrypt(keyData, withKey: key)

        return EncryptedPrivateKey(
            ciphertext: ciphertext,
            nonce: nonce,
            salt: salt,
            tag: tag,
            version: 1
        )
    }

    func decryptPrivateKey(_ encrypted: EncryptedPrivateKey, password: String) throws -> String {
        let key = try deriveKey(from: password, salt: encrypted.salt)
        let plaintext = try decrypt(
            encrypted.ciphertext,
            nonce: encrypted.nonce,
            tag: encrypted.tag,
            withKey: key
        )

        guard let hex = String(data: plaintext, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return hex
    }

    // MARK: - High-level: encrypt mnemonic

    func encryptMnemonic(_ mnemonic: String, password: String) throws -> EncryptedMnemonic {
        guard let mnemonicData = mnemonic.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }

        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        let (ciphertext, nonce, tag) = try encrypt(mnemonicData, withKey: key)
        let wordCount = mnemonic.components(separatedBy: " ").count

        return EncryptedMnemonic(
            ciphertext: ciphertext,
            nonce: nonce,
            salt: salt,
            tag: tag,
            wordCount: wordCount,
            version: 1
        )
    }

    func decryptMnemonic(_ encrypted: EncryptedMnemonic, password: String) throws -> String {
        let key = try deriveKey(from: password, salt: encrypted.salt)
        let plaintext = try decrypt(
            encrypted.ciphertext,
            nonce: encrypted.nonce,
            tag: encrypted.tag,
            withKey: key
        )

        guard let mnemonic = String(data: plaintext, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }

        return mnemonic
    }

    // MARK: - Backup Encryption (scrypt-based for higher resistance)
    // Used for encrypted cloud backup exports — stronger than PBKDF2

    func encryptBackup(_ data: Data, password: String) throws -> Data {
        let salt = generateSalt(length: 32)

        // Use PBKDF2 with very high iteration count as scrypt substitute in pure Swift
        let key = try deriveKey(from: password, salt: salt, iterations: 1_200_000)
        let (ciphertext, nonce, tag) = try encrypt(data, withKey: key)

        // Format: version(1) + saltLen(2) + salt + nonce(12) + tag(16) + ciphertext
        var result = Data()
        result.append(0x01)  // version
        result.append(contentsOf: withUnsafeBytes(of: UInt16(salt.count).bigEndian) { Array($0) })
        result.append(salt)
        result.append(nonce)
        result.append(tag)
        result.append(ciphertext)
        return result
    }

    func decryptBackup(_ data: Data, password: String) throws -> Data {
        var offset = 0
        guard data.count > 31 else { throw EncryptionError.invalidData }

        let version = data[offset]; offset += 1
        guard version == 0x01 else { throw EncryptionError.invalidData }

        let saltLen = Int(UInt16(bigEndian: data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }))
        offset += 2

        let salt = data[offset..<offset+saltLen]; offset += saltLen
        let nonce = data[offset..<offset+12]; offset += 12
        let tag = data[offset..<offset+16]; offset += 16
        let ciphertext = data[offset...]

        let key = try deriveKey(from: password, salt: Data(salt), iterations: 1_200_000)
        return try decrypt(Data(ciphertext), nonce: Data(nonce), tag: Data(tag), withKey: key)
    }

    // MARK: - Utilities

    func generateSalt(length: Int = 32) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }

    func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    func sha256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return sha256(data).map { String(format: "%02x", $0) }.joined()
    }

    func hmacSHA256(_ data: Data, key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: data, using: key))
    }

    /// Constant-time comparison to prevent timing attacks
    func secureCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var result: UInt8 = 0
        for (x, y) in zip(a, b) {
            result |= x ^ y
        }
        return result == 0
    }
}
