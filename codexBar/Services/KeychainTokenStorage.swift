import Foundation
import Security

/// Keychain 存储错误
enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed with status: \(status)"
        case .loadFailed(let status):
            return "Keychain load failed with status: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        case .itemNotFound:
            return "Keychain item not found"
        case .invalidData:
            return "Invalid data in Keychain"
        }
    }
}

/// Keychain Token 安全存储服务
/// 将敏感 Token 信息存储到 macOS Keychain 而非明文文件
final class KeychainTokenStorage {
    static let shared = KeychainTokenStorage()

    private let serviceIdentifier = "lzhl.codexbar"
    private let accessTokenPrefix = "accessToken."
    private let refreshTokenPrefix = "refreshToken."
    private let idTokenPrefix = "idToken."
    private let apiKeyPrefix = "apiKey."

    private init() {}

    // MARK: - Token Storage

    /// 保存 Access Token
    func saveAccessToken(_ token: String, for accountID: String) throws {
        try save(token, key: accessTokenPrefix + accountID)
    }

    /// 加载 Access Token
    func loadAccessToken(for accountID: String) -> String? {
        return load(key: accessTokenPrefix + accountID)
    }

    /// 删除 Access Token
    func deleteAccessToken(for accountID: String) throws {
        try delete(key: accessTokenPrefix + accountID)
    }

    /// 保存 Refresh Token
    func saveRefreshToken(_ token: String, for accountID: String) throws {
        try save(token, key: refreshTokenPrefix + accountID)
    }

    /// 加载 Refresh Token
    func loadRefreshToken(for accountID: String) -> String? {
        return load(key: refreshTokenPrefix + accountID)
    }

    /// 删除 Refresh Token
    func deleteRefreshToken(for accountID: String) throws {
        try delete(key: refreshTokenPrefix + accountID)
    }

    /// 保存 ID Token
    func saveIdToken(_ token: String, for accountID: String) throws {
        try save(token, key: idTokenPrefix + accountID)
    }

    /// 加载 ID Token
    func loadIdToken(for accountID: String) -> String? {
        return load(key: idTokenPrefix + accountID)
    }

    /// 删除 ID Token
    func deleteIdToken(for accountID: String) throws {
        try delete(key: idTokenPrefix + accountID)
    }

    /// 保存 API Key
    func saveAPIKey(_ key: String, for accountID: String) throws {
        try save(key, key: apiKeyPrefix + accountID)
    }

    /// 加载 API Key
    func loadAPIKey(for accountID: String) -> String? {
        return load(key: apiKeyPrefix + accountID)
    }

    /// 删除 API Key
    func deleteAPIKey(for accountID: String) throws {
        try delete(key: apiKeyPrefix + accountID)
    }

    // MARK: - Bulk Operations

    /// 保存所有 OpenAI 账号的 Token
    func saveAllTokens(for account: CodexBarProviderAccount) throws {
        if let accessToken = account.accessToken {
            try saveAccessToken(accessToken, for: account.id)
        }
        if let refreshToken = account.refreshToken {
            try saveRefreshToken(refreshToken, for: account.id)
        }
        if let idToken = account.idToken {
            try saveIdToken(idToken, for: account.id)
        }
    }

    /// 加载所有 OpenAI 账号的 Token 并更新到账号对象
    func loadAllTokens(into account: inout CodexBarProviderAccount) {
        account.accessToken = loadAccessToken(for: account.id)
        account.refreshToken = loadRefreshToken(for: account.id)
        account.idToken = loadIdToken(for: account.id)
    }

    /// 删除账号的所有 Token
    func deleteAllTokens(for accountID: String) throws {
        try? deleteAccessToken(for: accountID)
        try? deleteRefreshToken(for: accountID)
        try? deleteIdToken(for: accountID)
        try? deleteAPIKey(for: accountID)
    }

    /// 保存 Provider API Key
    func saveProviderAPIKey(_ key: String, for providerName: String, accountName: String) throws {
        let combinedKey = "\(providerName).\(accountName)"
        try saveAPIKey(key, for: combinedKey)
    }

    /// 加载 Provider API Key
    func loadProviderAPIKey(for providerName: String, accountName: String) -> String? {
        let combinedKey = "\(providerName).\(accountName)"
        return loadAPIKey(for: combinedKey)
    }

    // MARK: - Private Helpers

    func save(_ value: String, key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 先删除旧的（如果存在）
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        guard let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}