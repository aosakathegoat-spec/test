import Foundation
import Security

enum KeychainService {
    private static let service = "com.aria.assistant"

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key)  // remove any existing entry first
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func get(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func exists(_ key: String) -> Bool {
        get(key) != nil
    }
}
