import SwiftUI

/// One org/account row under an email group
struct AccountRowView: View {
    let account: TokenAccount
    let rowState: OpenAIAccountRowState
    let isRefreshing: Bool
    let usageDisplayMode: CodexBarUsageDisplayMode
    let defaultManualActivationBehavior: CodexBarOpenAIManualActivationBehavior?
    let onActivate: (OpenAIManualActivationTrigger) -> Void
    let onRefresh: () -> Void
    let onReauth: () -> Void
    let onDelete: () -> Void

    @State private var isHoveringPlanBadge = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            self.planBadge

            usageSummary

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)

            if account.tokenExpired {
                Button(L.reauth, action: onReauth)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.system(size: 12, weight: .medium))
                    .tint(.orange)
            } else if !account.isBanned {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(
                            isRefreshing
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: isRefreshing
                        )
                }
                .buttonStyle(.borderless)
                .foregroundColor(isRefreshing ? .accentColor : .secondary)
                .disabled(isRefreshing)

                if rowState.showsUseAction {
                    Button(rowState.useActionTitle) {
                        onActivate(OpenAIAccountPresentation.primaryManualActivationTrigger)
                    }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackgroundColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(rowBorderColor, lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            if self.rowState.isNextUseTarget {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 4)
                    .padding(.vertical, 6)
            }
        }
        .contextMenu {
            if let defaultManualActivationBehavior,
               rowState.showsUseAction {
                ForEach(
                    OpenAIAccountPresentation.manualActivationContextActions(
                        defaultBehavior: defaultManualActivationBehavior
                    ),
                    id: \.behavior
                ) { action in
                    Button {
                        onActivate(action.trigger)
                    } label: {
                        if action.isDefault {
                            Label(action.title, systemImage: "checkmark")
                        } else {
                            Text(action.title)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var usageSummary: some View {
        HStack(spacing: 10) {
            ForEach(Array(account.usageWindowDisplays(mode: self.usageDisplayMode).enumerated()), id: \.offset) { index, window in
                if index > 0 {
                    Text(L.bulletSeparator)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(window.label)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(Int(window.displayPercent))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(usageColor(window))
                }
            }
        }
    }

    private var planBadge: some View {
        Text(
            OpenAIAccountPresentation.planBadgeTitle(
                for: self.account,
                isHovered: self.isHoveringPlanBadge
            )
        )
        .font(.system(size: 11, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(planBadgeColor.opacity(0.18))
        .foregroundColor(planBadgeColor)
        .cornerRadius(4)
    }

    private var statusColor: Color {
        if account.isBanned { return .red }
        if account.quotaExhausted { return .orange }
        if account.isBelowVisualWarningThreshold() { return .yellow }
        return .green
    }

    private var rowBackgroundColor: Color {
        if self.rowState.isNextUseTarget { return Color.accentColor.opacity(0.14) }
        if account.isBanned { return Color.red.opacity(0.045) }
        if account.quotaExhausted { return Color.orange.opacity(0.05) }
        if account.isBelowVisualWarningThreshold() {
            return Color.yellow.opacity(0.05)
        }
        return Color.secondary.opacity(0.055)
    }

    private var rowBorderColor: Color {
        if self.rowState.isNextUseTarget { return Color.accentColor.opacity(0.28) }
        if account.isBanned { return Color.red.opacity(0.12) }
        if account.quotaExhausted { return Color.orange.opacity(0.14) }
        if account.isBelowVisualWarningThreshold() {
            return Color.yellow.opacity(0.14)
        }
        return Color.primary.opacity(0.08)
    }

    private var planBadgeColor: Color {
        switch account.planType.lowercased() {
        case "team": return .blue
        case "plus": return .purple
        default: return .gray
        }
    }

    private func usageColor(_ window: UsageWindowDisplay) -> Color {
        if window.usedPercent >= 100 { return .red }
        if window.remainingPercent <= OpenAIVisualWarningThreshold.remainingPercent {
            return .orange
        }

        switch self.usageDisplayMode {
        case .remaining:
            return .green
        case .used:
            if window.usedPercent >= 70 { return .orange }
            return .green
        }
    }
}
