import Foundation

/// 本地账号发现服务 - 从 ~/.codex 目录发现已登录的账号
final class LocalAccountDiscoveryService {
    static let shared = LocalAccountDiscoveryService()

    private init() {}

    /// 从本地文件发现可用的账号
    func discoverLocalAccounts() -> [DiscoveredLocalAccount] {
        var accounts: [DiscoveredLocalAccount] = []

        // 从 auth.json 读取
        if let authAccounts = discoverFromAuthJSON() {
            accounts.append(contentsOf: authAccounts)
        }

        // 从 token_pool.json 读取
        if let poolAccounts = discoverFromTokenPool() {
            // 合并，避免重复
            for account in poolAccounts {
                if !accounts.contains(where: { $0.accountId == account.accountId }) {
                    accounts.append(account)
                }
            }
        }

        return accounts
    }

    /// 从 ~/.codex/auth.json 发现账号
    private func discoverFromAuthJSON() -> [DiscoveredLocalAccount]? {
        guard FileManager.default.fileExists(atPath: CodexPaths.authURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: CodexPaths.authURL)
            guard let auth = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            var accounts: [DiscoveredLocalAccount] = []

            // 检查 tokens 字段（OAuth 登录）
            if let tokens = auth["tokens"] as? [String: Any],
               let accessToken = tokens["access_token"] as? String,
               let refreshToken = tokens["refresh_token"] as? String,
               let idToken = tokens["id_token"] as? String {

                let account = AccountBuilder.build(
                    from: OAuthTokens(
                        accessToken: accessToken,
                        refreshToken: refreshToken,
                        idToken: idToken
                    )
                )

                let remoteAccountId = tokens["account_id"] as? String ?? ""
                let discovered = DiscoveredLocalAccount(
                    accountId: account.accountId.isEmpty ? remoteAccountId : account.accountId,
                    email: account.email,
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    idToken: idToken,
                    source: .authJSON
                )
                accounts.append(discovered)
            }

            return accounts
        } catch {
            NSLog("codexbar: Failed to read auth.json: %@", error.localizedDescription)
            return nil
        }
    }

    /// 从 ~/.codex/token_pool.json 发现账号
    private func discoverFromTokenPool() -> [DiscoveredLocalAccount]? {
        guard FileManager.default.fileExists(atPath: CodexPaths.tokenPoolURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: CodexPaths.tokenPoolURL)
            let decoder = JSONDecoder()
            let pool = try decoder.decode(TokenPool.self, from: data)

            return pool.accounts.map { account in
                DiscoveredLocalAccount(
                    accountId: account.accountId,
                    email: account.email,
                    accessToken: account.accessToken,
                    refreshToken: account.refreshToken,
                    idToken: account.idToken,
                    source: .tokenPool
                )
            }
        } catch {
            NSLog("codexbar: Failed to read token_pool.json: %@", error.localizedDescription)
            return nil
        }
    }

    /// 将发现的账号添加到 TokenStore
    func addDiscoveredAccount(_ account: DiscoveredLocalAccount, activate: Bool = false) throws {
        let tokenAccount = TokenAccount(
            email: account.email,
            accountId: account.accountId,
            openAIAccountId: account.accountId,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            idToken: account.idToken,
            expiresAt: nil,
            planType: "free",
            primaryUsedPercent: 0,
            secondaryUsedPercent: 0,
            primaryResetAt: nil,
            secondaryResetAt: nil,
            primaryLimitWindowSeconds: nil,
            secondaryLimitWindowSeconds: nil,
            lastChecked: nil,
            isActive: activate,
            isSuspended: false,
            tokenExpired: false,
            organizationName: nil
        )

        let store = TokenStore.shared
        store.load()

        // 检查是否已存在
        if store.accounts.contains(where: { $0.accountId == account.accountId }) {
            throw LocalAccountError.alreadyExists
        }

        // 添加账号（addOrUpdate 内部会保存）
        store.addOrUpdate(tokenAccount)

        // 如果需要激活
        if activate {
            try store.activate(tokenAccount)
        }
    }
}

/// 发现的本地账号
struct DiscoveredLocalAccount: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let accountId: String
    let email: String
    let accessToken: String
    let refreshToken: String
    let idToken: String
    let source: LocalAccountSource

    var displayName: String {
        email.isEmpty ? accountId : email
    }

    static func == (lhs: DiscoveredLocalAccount, rhs: DiscoveredLocalAccount) -> Bool {
        lhs.accountId == rhs.accountId
    }
}

enum LocalAccountSource {
    case authJSON
    case tokenPool
}

enum LocalAccountError: LocalizedError {
    case alreadyExists
    case noAccountsFound
    case importFailed

    var errorDescription: String? {
        switch self {
        case .alreadyExists:
            return "账号已存在"
        case .noAccountsFound:
            return "未找到本地账号"
        case .importFailed:
            return "导入账号失败"
        }
    }
}
