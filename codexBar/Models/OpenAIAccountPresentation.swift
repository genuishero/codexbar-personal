import Foundation

struct OpenAIAccountRowState: Equatable {
    let isNextUseTarget: Bool
    let runningThreadCount: Int

    var showsUseAction: Bool {
        self.isNextUseTarget == false
    }

    var useActionTitle: String {
        L.useBtn
    }

    var runningThreadBadgeTitle: String? {
        guard self.runningThreadCount > 0 else { return nil }
        return L.runningThreads(self.runningThreadCount)
    }
}

enum OpenAIAccountPresentation {
    static func rowState(
        for account: TokenAccount,
        attribution: OpenAILiveSessionAttribution,
        now: Date = Date()
    ) -> OpenAIAccountRowState {
        self.rowState(for: account, summary: attribution.liveSummary(now: now))
    }

    static func rowState(
        for account: TokenAccount,
        summary: OpenAILiveSessionAttribution.LiveSummary
    ) -> OpenAIAccountRowState {
        self.rowState(
            for: account,
            runningThreadCount: summary.inUseSessionCount(for: account.accountId)
        )
    }

    static func rowState(
        for account: TokenAccount,
        summary: OpenAIRunningThreadAttribution.Summary
    ) -> OpenAIAccountRowState {
        self.rowState(
            for: account,
            runningThreadCount: summary.runningThreadCount(for: account.accountId)
        )
    }

    static func runningThreadSummaryText(
        summary: OpenAIRunningThreadAttribution.Summary
    ) -> String {
        if summary.isUnavailable {
            return L.runningThreadUnavailable
        }

        if summary.totalRunningThreadCount == 0 {
            return L.runningThreadNone
        }

        let base = L.runningThreadSummary(
            summary.totalRunningThreadCount,
            summary.runningAccountCount
        )
        guard summary.unknownThreadCount > 0 else { return base }
        return "\(base) · \(L.runningThreadUnknown(summary.unknownThreadCount))"
    }

    private static func rowState(
        for account: TokenAccount,
        runningThreadCount: Int
    ) -> OpenAIAccountRowState {
        OpenAIAccountRowState(
            isNextUseTarget: account.isActive,
            runningThreadCount: runningThreadCount
        )
    }

    static func inUseSummaryText(
        attribution: OpenAILiveSessionAttribution,
        now: Date = Date()
    ) -> String {
        self.inUseSummaryText(summary: attribution.liveSummary(now: now))
    }

    static func inUseSummaryText(
        summary: OpenAILiveSessionAttribution.LiveSummary
    ) -> String {
        if summary.totalInUseSessionCount == 0 {
            return summary.unknownSessionCount > 0
                ? L.inUseUnknownSessions(summary.unknownSessionCount)
                : L.inUseNone
        }

        let base = L.inUseSummary(
            summary.totalInUseSessionCount,
            summary.inUseAccountCount
        )
        guard summary.unknownSessionCount > 0 else { return base }
        return "\(base) · \(L.inUseUnknownSessions(summary.unknownSessionCount))"
    }
}
