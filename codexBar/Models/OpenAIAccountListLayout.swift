import Foundation

enum OpenAIAccountSortBucket: Int {
    case usable
    case unavailableNonExhausted
    case exhausted
}

private enum OpenAIAccountDisplayPriority: Int {
    case prioritized
    case standard
}

struct OpenAIAccountGroup: Identifiable {
    let email: String
    let accounts: [TokenAccount]

    var id: String { email }
}

extension OpenAIAccountGroup {
    nonisolated var representativeAccount: TokenAccount? {
        accounts.first
    }

    nonisolated func headerQuotaRemark(now: Date = Date()) -> String? {
        representativeAccount?.headerQuotaRemark(now: now)
    }
}

enum OpenAIAccountListLayout {
    static let visibleGroupLimit = 4

    nonisolated static func groupedAccounts(from accounts: [TokenAccount]) -> [OpenAIAccountGroup] {
        Dictionary(grouping: accounts, by: \.email)
            .map { email, groupedAccounts in
                OpenAIAccountGroup(
                    email: email,
                    accounts: groupedAccounts.sorted(by: accountPrecedes)
                )
            }
            .sorted(by: groupPrecedes)
    }

    nonisolated static func groupedAccounts(
        from accounts: [TokenAccount],
        attribution: OpenAILiveSessionAttribution
    ) -> [OpenAIAccountGroup] {
        Dictionary(grouping: accounts, by: \.email)
            .map { email, groupedAccounts in
                OpenAIAccountGroup(
                    email: email,
                    accounts: groupedAccounts.sorted {
                        self.displayAccountPrecedes($0, $1, attribution: attribution)
                    }
                )
            }
            .sorted { self.displayGroupPrecedes($0, $1, attribution: attribution) }
    }

    nonisolated static func visibleGroups(
        from groups: [OpenAIAccountGroup],
        maxAccounts: Int
    ) -> [OpenAIAccountGroup] {
        guard maxAccounts > 0 else { return [] }

        var remaining = maxAccounts
        var visible: [OpenAIAccountGroup] = []

        for group in groups where remaining > 0 {
            let accounts = Array(group.accounts.prefix(remaining))
            guard accounts.isEmpty == false else { continue }
            visible.append(OpenAIAccountGroup(email: group.email, accounts: accounts))
            remaining -= accounts.count
        }

        return visible
    }

    nonisolated static func accountPrecedes(_ lhs: TokenAccount, _ rhs: TokenAccount) -> Bool {
        if lhs.sortBucket != rhs.sortBucket {
            return lhs.sortBucket.rawValue < rhs.sortBucket.rawValue
        }

        if lhs.primaryRemainingPercent != rhs.primaryRemainingPercent {
            return lhs.primaryRemainingPercent > rhs.primaryRemainingPercent
        }

        if lhs.secondaryRemainingPercent != rhs.secondaryRemainingPercent {
            return lhs.secondaryRemainingPercent > rhs.secondaryRemainingPercent
        }

        let lhsEmail = lhs.email.localizedLowercase
        let rhsEmail = rhs.email.localizedLowercase
        if lhsEmail != rhsEmail {
            return lhsEmail < rhsEmail
        }

        return lhs.accountId < rhs.accountId
    }

    nonisolated private static func displayAccountPrecedes(
        _ lhs: TokenAccount,
        _ rhs: TokenAccount,
        attribution: OpenAILiveSessionAttribution
    ) -> Bool {
        let lhsPriority = self.displayPriority(for: lhs, attribution: attribution)
        let rhsPriority = self.displayPriority(for: rhs, attribution: attribution)
        if lhsPriority != rhsPriority {
            return lhsPriority.rawValue < rhsPriority.rawValue
        }

        return self.accountPrecedes(lhs, rhs)
    }

    nonisolated private static func displayPriority(
        for account: TokenAccount,
        attribution: OpenAILiveSessionAttribution
    ) -> OpenAIAccountDisplayPriority {
        if account.isActive || attribution.inUseSessionCount(for: account.accountId) > 0 {
            return .prioritized
        }
        return .standard
    }

    nonisolated private static func groupPrecedes(_ lhs: OpenAIAccountGroup, _ rhs: OpenAIAccountGroup) -> Bool {
        let lhsRepresentative = lhs.accounts.first
        let rhsRepresentative = rhs.accounts.first

        switch (lhsRepresentative, rhsRepresentative) {
        case let (lhsAccount?, rhsAccount?):
            if accountPrecedes(lhsAccount, rhsAccount) {
                return true
            }
            if accountPrecedes(rhsAccount, lhsAccount) {
                return false
            }
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            break
        }

        return lhs.email.localizedLowercase < rhs.email.localizedLowercase
    }

    nonisolated private static func displayGroupPrecedes(
        _ lhs: OpenAIAccountGroup,
        _ rhs: OpenAIAccountGroup,
        attribution: OpenAILiveSessionAttribution
    ) -> Bool {
        let lhsRepresentative = lhs.accounts.first
        let rhsRepresentative = rhs.accounts.first

        switch (lhsRepresentative, rhsRepresentative) {
        case let (lhsAccount?, rhsAccount?):
            if self.displayAccountPrecedes(lhsAccount, rhsAccount, attribution: attribution) {
                return true
            }
            if self.displayAccountPrecedes(rhsAccount, lhsAccount, attribution: attribution) {
                return false
            }
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case (nil, nil):
            break
        }

        return lhs.email.localizedLowercase < rhs.email.localizedLowercase
    }
}
