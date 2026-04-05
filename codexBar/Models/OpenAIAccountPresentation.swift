import Foundation

struct OpenAIAccountRowState: Equatable {
    let isNextUseTarget: Bool
    let inUseSessionCount: Int

    var showsUseAction: Bool {
        self.isNextUseTarget == false
    }

    var useActionTitle: String {
        L.useBtn
    }

    var inUseBadgeTitle: String? {
        guard self.inUseSessionCount > 0 else { return nil }
        return L.inUseSessions(self.inUseSessionCount)
    }
}

enum OpenAIAccountPresentation {
    static func rowState(
        for account: TokenAccount,
        attribution: OpenAILiveSessionAttribution
    ) -> OpenAIAccountRowState {
        OpenAIAccountRowState(
            isNextUseTarget: account.isActive,
            inUseSessionCount: attribution.inUseSessionCount(for: account.accountId)
        )
    }

    static func inUseSummaryText(
        attribution: OpenAILiveSessionAttribution
    ) -> String {
        if attribution.totalInUseSessionCount == 0 {
            return attribution.unknownSessionCount > 0
                ? L.inUseUnknownSessions(attribution.unknownSessionCount)
                : L.inUseNone
        }

        let base = L.inUseSummary(
            attribution.totalInUseSessionCount,
            attribution.inUseAccountCount
        )
        guard attribution.unknownSessionCount > 0 else { return base }
        return "\(base) · \(L.inUseUnknownSessions(attribution.unknownSessionCount))"
    }
}
