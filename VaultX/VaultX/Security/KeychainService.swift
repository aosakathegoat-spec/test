import Foundation
import Security
import CryptoKit

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedData
    case unhandledError(OSStatus)

    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Item already exists in Keychain"
        case .itemNotFound: return "Item not found in Keychain"
        case .unexpectedData: return "Unexpected data format"
        case .unhandledError(let status): return "Keychain error: \(status)"
        }
    }
}

// MARK: - Keychain Service

final class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "com.vaultx.wallet"
    private let accessGroup: String? = nil  // Set for app groups / Watch sync

    private init() {}

    // MARK: - Generic CRUD

    func save(_ data: Data, forKey key: String, accessControl: SecAccessControl? = nil) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        if let ac = accessControl {
            query[kSecAttrAccessControl as String] = ac
        } else {
            // Default: accessible after first unlock, not backed up to iCloud
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(data, forKey: key)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status)
        }
    }

    func load(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        return data
    }

    func update(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }

    // MARK: - String Convenience

    func saveString(_ string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.unexpectedData
        }
        try save(data, forKey: key)
    }

    func loadString(forKey key: String) throws -> String {
        let data = try load(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return string
    }

    // MARK: - Secure Enclave Keys

    /// Creates a P-256 key in the Secure Enclave — requires biometric/passcode authentication
    func createSecureEnclaveKey(tag: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
        let key = try SecureEnclave.P256.Signing.PrivateKey(
            compactRepresentable: true,
            accessControl: SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryCurrentSet],
                nil
            )!
        )
        try save(key.dataRepresentation, forKey: "secureenclave.\(tag)")
        return key
    }

    func loadSecureEnclaveKey(tag: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
        let data = try load(forKey: "secureenclave.\(tag)")
        return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
    }

    // MARK: - Private Key Storage (encrypted)

    func saveEncryptedPrivateKey(_ encryptedKey: EncryptedPrivateKey, walletId: String) throws {
        let data = try JSONEncoder().encode(encryptedKey)
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.userPresence],   // requires biometric or passcode on read
            nil
        )!
        try save(data, forKey: "privatekey.\(walletId)", accessControl: accessControl)
    }

    func loadEncryptedPrivateKey(walletId: String) throws -> EncryptedPrivateKey {
        let data = try load(forKey: "privatekey.\(walletId)")
        return try JSONDecoder().decode(EncryptedPrivateKey.self, from: data)
    }

    // MARK: - Mnemonic Storage

    func saveMnemonic(_ encryptedMnemonic: EncryptedMnemonic, hdWalletId: String) throws {
        let data = try JSONEncoder().encode(encryptedMnemonic)
        // Highest security: user presence always required
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.userPresence],
            nil
        )!
        try save(data, forKey: "mnemonic.\(hdWalletId)", accessControl: accessControl)
    }

    func loadMnemonic(hdWalletId: String) throws -> EncryptedMnemonic {
        let data = try load(forKey: "mnemonic.\(hdWalletId)")
        return try JSONDecoder().decode(EncryptedMnemonic.self, from: data)
    }

    func deleteMnemonic(hdWalletId: String) throws {
        try delete(forKey: "mnemonic.\(hdWalletId)")
    }

    // MARK: - Auth Tokens

    func saveAuthToken(_ token: String) throws {
        try saveString(token, forKey: "auth.accessToken")
    }

    func loadAuthToken() throws -> String {
        try loadString(forKey: "auth.accessToken")
    }

    func saveRefreshToken(_ token: String) throws {
        try saveString(token, forKey: "auth.refreshToken")
    }

    func loadRefreshToken() throws -> String {
        try loadString(forKey: "auth.refreshToken")
    }

    func clearAuthTokens() {
        try? delete(forKey: "auth.accessToken")
        try? delete(forKey: "auth.refreshToken")
    }

    // MARK: - TOTP Secret

    func saveTOTPSecret(_ secret: String, userId: String) throws {
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet],
            nil
        )!
        guard let data = secret.data(using: .utf8) else { throw KeychainError.unexpectedData }
        try save(data, forKey: "totp.\(userId)", accessControl: accessControl)
    }

    func loadTOTPSecret(userId: String) throws -> String {
        let data = try load(forKey: "totp.\(userId)")
        guard let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return secret
    }
}

// MARK: - Encrypted Key Containers

struct EncryptedPrivateKey: Codable {
    var ciphertext: Data    // AES-256-GCM encrypted
    var nonce: Data         // 12-byte GCM nonce
    var salt: Data          // 32-byte Argon2id/PBKDF2 salt
    var tag: Data           // GCM auth tag
    var version: Int        // for key rotation
}

struct EncryptedMnemonic: Codable {
    var ciphertext: Data
    var nonce: Data
    var salt: Data
    var tag: Data
    var wordCount: Int      // 12 or 24
    var version: Int
}
