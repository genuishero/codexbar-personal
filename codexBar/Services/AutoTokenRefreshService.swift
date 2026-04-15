import Foundation

enum AutoTokenRefreshPolicy {
    static func accountToRefresh(
        accounts: [TokenAccount],
        now: Date,
        refreshBuffer: TimeInterval
    ) -> TokenAccount? {
        accounts
            .filter {
                $0.isSuspended == false &&
                $0.tokenExpired == false &&
                $0.refreshToken.isEmpty == false &&
                $0.isAccessTokenExpiring(within: refreshBuffer, now: now)
            }
            .min {
                ($0.accessTokenExpiresAt ?? .distantFuture) < ($1.accessTokenExpiresAt ?? .distantFuture)
            }
    }
}

@MainActor
final class AutoTokenRefreshService {
    static let shared = AutoTokenRefreshService()

    nonisolated static let defaultCheckInterval: TimeInterval = 5 * 60
    nonisolated static let defaultRefreshBuffer: TimeInterval = 2 * 60 * 60

    private let store: TokenStore
    private let checkInterval: TimeInterval
    private let refreshBuffer: TimeInterval
    private let now: () -> Date
    private let refreshAccountAction: (TokenAccount) async throws -> TokenAccount

    private var loopTask: Task<Void, Never>?
    private(set) var enabled: Bool

    init(
        store: TokenStore? = nil,
        checkInterval: TimeInterval = AutoTokenRefreshService.defaultCheckInterval,
        refreshBuffer: TimeInterval = AutoTokenRefreshService.defaultRefreshBuffer,
        now: @escaping () -> Date = Date.init,
        refreshAccountAction: @escaping (TokenAccount) async throws -> TokenAccount = { account in
            try await OpenAIOAuthFlowService().refreshAccount(account)
        }
    ) {
        self.store = store ?? .shared
        self.checkInterval = checkInterval
        self.refreshBuffer = refreshBuffer
        self.now = now
        self.refreshAccountAction = refreshAccountAction
        self.enabled = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.autoTokenRefreshKey,
            default: true
        )
    }

    func startMonitoring() {
        guard self.enabled else { return }
        guard self.loopTask == nil else { return }

        let sleepDuration = UInt64(max(self.checkInterval, 1) * 1_000_000_000)
        self.loopTask = Task {
            await self.refreshIfNeeded()

            while Task.isCancelled == false {
                do {
                    try await Task.sleep(nanoseconds: sleepDuration)
                } catch {
                    break
                }
                await self.refreshIfNeeded()
            }
        }
    }

    func stopMonitoring() {
        self.loopTask?.cancel()
        self.loopTask = nil
    }

    func setEnabled(_ value: Bool) {
        self.enabled = value
        UserDefaults.standard.set(value, forKey: SecurityFeatureDefaults.autoTokenRefreshKey)

        if value {
            self.startMonitoring()
        } else {
            self.stopMonitoring()
        }
    }

    private func refreshIfNeeded() async {
        guard let account = AutoTokenRefreshPolicy.accountToRefresh(
            accounts: self.store.accounts,
            now: self.now(),
            refreshBuffer: self.refreshBuffer
        ) else {
            return
        }

        do {
            let refreshedAccount = try await self.refreshAccountAction(account)
            self.store.addOrUpdate(refreshedAccount)
        } catch let error as OpenAIOAuthError {
            if case .invalidGrant = error {
                var expiredAccount = account
                expiredAccount.tokenExpired = true
                self.store.addOrUpdate(expiredAccount)
            }
            NSLog("codexbar token refresh failed for %@: %@", account.accountId, error.localizedDescription)
        } catch {
            NSLog("codexbar token refresh failed for %@: %@", account.accountId, error.localizedDescription)
        }
    }
}
