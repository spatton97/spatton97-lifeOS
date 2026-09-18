import Foundation
import Security

/// Stores Gmail OAuth tokens in the Keychain, keyed by mailbox UUID — never in SwiftData.
enum MailKeychain {
    private static let service = "com.lifeos.app.gmail"

    struct TokenBundle: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date?
        var tokenType: String?
        var scope: String?
    }

    static func save(tokens: TokenBundle, mailboxID: UUID) throws {
        let data = try JSONEncoder().encode(tokens)
        let account = mailboxID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(mailboxID: UUID) throws -> TokenBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: mailboxID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.loadFailed(status)
        }
        return try JSONDecoder().decode(TokenBundle.self, from: data)
    }

    static func delete(mailboxID: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: mailboxID.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .saveFailed(let s): return "Keychain save failed (\(s))"
            case .loadFailed(let s): return "Keychain load failed (\(s))"
            }
        }
    }
}
