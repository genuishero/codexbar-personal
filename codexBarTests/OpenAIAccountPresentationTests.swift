import XCTest

final class OpenAIAccountPresentationTests: XCTestCase {
    private var originalLanguageOverride: Bool?

    override func setUp() {
        super.setUp()
        self.originalLanguageOverride = L.languageOverride
        L.languageOverride = false
    }

    override func tearDown() {
        L.languageOverride = self.originalLanguageOverride
        super.tearDown()
    }

    func testRowStateShowsUseActionWhenAccountIsNotNextUseTarget() {
        let account = self.makeAccount(accountId: "acct_idle", isActive: false)

        let state = OpenAIAccountPresentation.rowState(
            for: account,
            attribution: .empty
        )

        XCTAssertTrue(state.showsUseAction)
        XCTAssertEqual(state.useActionTitle, "Use")
        XCTAssertNil(state.inUseBadgeTitle)
    }

    func testRowStateShowsSelectedNextUseStateWithoutUseAction() {
        let account = self.makeAccount(accountId: "acct_next", isActive: true)

        let state = OpenAIAccountPresentation.rowState(
            for: account,
            attribution: .empty
        )

        XCTAssertTrue(state.isNextUseTarget)
        XCTAssertFalse(state.showsUseAction)
    }

    func testRowStateShowsInUseBadgeWhenSessionsAreAttributed() {
        let account = self.makeAccount(accountId: "acct_busy", isActive: false)
        let attribution = OpenAILiveSessionAttribution(
            sessions: [],
            inUseSessionCounts: ["acct_busy": 2],
            unknownSessionCount: 0,
            recentActivityWindow: OpenAILiveSessionAttributionService.defaultRecentActivityWindow
        )

        let state = OpenAIAccountPresentation.rowState(
            for: account,
            attribution: attribution
        )

        XCTAssertEqual(state.inUseSessionCount, 2)
        XCTAssertEqual(state.inUseBadgeTitle, "In Use · 2 sessions")
    }

    func testNextUseAndInUseCanCoexistOnSameAccount() {
        let account = self.makeAccount(accountId: "acct_dual", isActive: true)
        let attribution = OpenAILiveSessionAttribution(
            sessions: [],
            inUseSessionCounts: ["acct_dual": 2],
            unknownSessionCount: 0,
            recentActivityWindow: OpenAILiveSessionAttributionService.defaultRecentActivityWindow
        )

        let state = OpenAIAccountPresentation.rowState(
            for: account,
            attribution: attribution
        )

        XCTAssertTrue(state.isNextUseTarget)
        XCTAssertEqual(state.inUseSessionCount, 2)
        XCTAssertFalse(state.showsUseAction)
        XCTAssertEqual(state.inUseBadgeTitle, "In Use · 2 sessions")
    }

    private func makeAccount(accountId: String, isActive: Bool) -> TokenAccount {
        TokenAccount(
            email: "\(accountId)@example.com",
            accountId: accountId,
            accessToken: "access-\(accountId)",
            refreshToken: "refresh-\(accountId)",
            idToken: "id-\(accountId)",
            isActive: isActive
        )
    }
}
