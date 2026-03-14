import Foundation
import Security

struct HelperCredentials: Codable, Sendable {
    let email: String
    let password: String
}

enum HelperCredentialsStore {
    private static let service = "com.gongahkia.sagasu.helper.credentials"
    private static let account = "smu-fbs"

    static func loadFromEnvironment() -> HelperCredentials? {
        guard
            let email = ProcessInfo.processInfo.environment["SMU_EMAIL"],
            let password = ProcessInfo.processInfo.environment["SMU_PASSWORD"],
            !email.isEmpty,
            !password.isEmpty
        else {
            return nil
        }

        return HelperCredentials(email: email, password: password)
    }

    static func load() throws -> HelperCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        guard let data = item as? Data else { return nil }
        return try JSONDecoder().decode(HelperCredentials.self, from: data)
    }

    static func save(_ credentials: HelperCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
            }
            return
        }

        var insertQuery = baseQuery
        insertQuery[kSecValueData as String] = data

        let addStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
        }
    }
}
