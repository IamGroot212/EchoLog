import Foundation
import Security

enum KeychainHelper {
    static func save(key: String, service: String) -> Bool {
        let data = Data(key.utf8)

        // Delete existing item first
        delete(service: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func load(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

extension KeychainHelper {
    static let claudeAPIKeyService = "com.echoLog.claudeAPIKey"
    static let openAIAPIKeyService = "com.echoLog.openaiAPIKey"

    static var claudeAPIKey: String? {
        get { load(service: claudeAPIKeyService) }
        set {
            if let value = newValue {
                _ = save(key: value, service: claudeAPIKeyService)
            } else {
                delete(service: claudeAPIKeyService)
            }
        }
    }

    static var openAIAPIKey: String? {
        get { load(service: openAIAPIKeyService) }
        set {
            if let value = newValue {
                _ = save(key: value, service: openAIAPIKeyService)
            } else {
                delete(service: openAIAPIKeyService)
            }
        }
    }

    static let notionTokenService = "com.echoLog.notionToken"

    static var notionToken: String? {
        get { load(service: notionTokenService) }
        set {
            if let value = newValue {
                _ = save(key: value, service: notionTokenService)
            } else {
                delete(service: notionTokenService)
            }
        }
    }
}
