import Foundation
import XCTest

final class CodexBarConfigStoreTests: CodexBarTestCase {
    func testLoadOrMigrateRemapsLegacyOAuthIDsToUserScopedIDs() throws {
        let store = CodexBarConfigStore()
        let journalStore = SwitchJournalStore(fileURL: CodexPaths.switchJournalURL)
        let remoteAccountID = "acct_team_shared"
        let localAccountID = "user-first__acct_team_shared"
        let account = try self.makeOAuthAccount(
            accountID: remoteAccountID,
            email: "first-team@example.com",
            planType: "team",
            localAccountID: localAccountID
        )

        let legacyStored = CodexBarProviderAccount(
            id: remoteAccountID,
            kind: .oauthTokens,
            label: "first-team@example.com",
            email: "first-team@example.com",
            openAIAccountId: remoteAccountID,
            accessToken: account.accessToken,
            refreshToken: account.refreshToken,
            idToken: account.idToken,
            addedAt: Date(timeIntervalSince1970: 42),
            planType: "team"
        )
        let provider = CodexBarProvider(
            id: "openai-oauth",
            kind: .openAIOAuth,
            label: "OpenAI",
            enabled: true,
            activeAccountId: remoteAccountID,
            accounts: [legacyStored]
        )
        let config = CodexBarConfig(
            active: CodexBarActiveSelection(providerId: provider.id, accountId: remoteAccountID),
            openAI: CodexBarOpenAISettings(accountOrder: [remoteAccountID]),
            providers: [provider]
        )
        try store.save(config)
        try journalStore.appendActivation(
            providerID: provider.id,
            accountID: remoteAccountID,
            previousAccountID: remoteAccountID,
            timestamp: Date(timeIntervalSince1970: 100)
        )

        let loaded = try store.loadOrMigrate()
        let migratedProvider = try XCTUnwrap(loaded.oauthProvider())
        let migratedAccount = try XCTUnwrap(migratedProvider.accounts.first)

        XCTAssertEqual(migratedAccount.id, localAccountID)
        XCTAssertEqual(migratedAccount.openAIAccountId, remoteAccountID)
        XCTAssertEqual(loaded.active.accountId, localAccountID)
        XCTAssertEqual(loaded.openAI.accountOrder, [localAccountID])

        let history = journalStore.activationHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.accountID, localAccountID)
        XCTAssertEqual(history.first?.previousAccountID, localAccountID)
    }

    func testLoadOrMigrateSanitizesHistoricalOverWindowResetAt() throws {
        let store = CodexBarConfigStore()
        let lastChecked = Date(timeIntervalSince1970: 1_700_000_000)
        let stored = CodexBarProviderAccount(
            id: "acct_over_window",
            kind: .oauthTokens,
            label: "over-window@example.com",
            email: "over-window@example.com",
            openAIAccountId: "acct_over_window",
            accessToken: "token",
            refreshToken: "refresh",
            idToken: "id",
            addedAt: Date(timeIntervalSince1970: 42),
            planType: "plus",
            primaryUsedPercent: 80,
            secondaryUsedPercent: 0,
            primaryResetAt: lastChecked.addingTimeInterval(8 * 3_600),
            primaryLimitWindowSeconds: 18_000,
            lastChecked: lastChecked
        )
        let provider = CodexBarProvider(
            id: "openai-oauth",
            kind: .openAIOAuth,
            label: "OpenAI",
            enabled: true,
            activeAccountId: stored.id,
            accounts: [stored]
        )
        try store.save(
            CodexBarConfig(
                active: CodexBarActiveSelection(providerId: provider.id, accountId: stored.id),
                providers: [provider]
            )
        )

        let loaded = try store.loadOrMigrate()
        let account = try XCTUnwrap(loaded.oauthProvider()?.accounts.first)

        XCTAssertEqual(account.primaryResetAt, lastChecked.addingTimeInterval(5 * 3_600))
        XCTAssertEqual(account.primaryLimitWindowSeconds, 18_000)
    }
}
