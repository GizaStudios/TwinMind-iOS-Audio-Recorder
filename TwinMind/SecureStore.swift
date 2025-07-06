import Foundation
import Security

/// Lightweight wrapper around iOS Keychain for storing small secrets like API keys or JWTs.
struct SecureStore {
    enum SecureStoreError: Error {
        case unhandledError(OSStatus)
        case dataConversionFailed
        case itemNotFound
    }

    /// Save / update a secret in keychain.
    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { throw SecureStoreError.dataConversionFailed }

        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]

        let attributes: [String: Any] = [kSecValueData as String: data,
                                         kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]

        SecItemDelete(query as CFDictionary) // Remove existing
        let status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStoreError.unhandledError(status) }
    }

    /// Read a secret from keychain.
    static func read(key: String) throws -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: kCFBooleanTrue!,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { throw SecureStoreError.itemNotFound }
        guard status == errSecSuccess else { throw SecureStoreError.unhandledError(status) }
        guard let data = item as? Data, let string = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.dataConversionFailed
        }
        return string
    }

    /// Delete a secret.
    static func delete(key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: key]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureStoreError.unhandledError(status) }
    }
} 