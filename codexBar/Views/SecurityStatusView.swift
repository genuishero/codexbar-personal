import SwiftUI

/// 安全状态显示视图
struct SecurityStatusView: View {
    @ObservedObject var manager = SecurityFeatureManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 总体状态
            overallStatusSection

            Divider()

            // 各项功能状态
            featuresSection
        }
        .padding()
    }

    // MARK: - Overall Status

    private var overallStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: manager.overallStatusIcon)
                .font(.system(size: 28))
                .foregroundColor(manager.overallStatusColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(L.securityStatusLabel)
                    .font(.system(size: 14, weight: .semibold))

                Text(manager.overallStatusText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("安全功能")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            // 剪贴板保护
            SecurityFeatureRow(
                icon: "clipboard",
                title: L.clipboardProtected,
                description: "30秒后自动清除敏感信息",
                enabled: manager.clipboardProtection,
                canToggle: true,
                onToggle: { manager.clipboardProtection.toggle() }
            )

            // 自动 Token 刷新
            SecurityFeatureRow(
                icon: "arrow.triangle.2.circlepath",
                title: L.autoTokenRefresh,
                description: "自动刷新即将过期的 Token",
                enabled: manager.autoTokenRefresh,
                canToggle: true,
                onToggle: { manager.autoTokenRefresh.toggle() }
            )

            // 用量预警
            SecurityFeatureRow(
                icon: "bell.fill",
                title: L.quotaWarning,
                description: "用量达到阈值时提醒",
                enabled: manager.quotaWarning,
                canToggle: true,
                onToggle: { manager.quotaWarning.toggle() }
            )

            // 快捷键支持
            SecurityFeatureRow(
                icon: "keyboard",
                title: L.keyboardShortcuts,
                description: "Cmd+Shift+1~5 快速切换账号",
                enabled: manager.keyboardShortcuts,
                canToggle: true,
                onToggle: { manager.keyboardShortcuts.toggle() }
            )
        }
    }
}

/// 单个安全功能行视图
struct SecurityFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let enabled: Bool
    let canToggle: Bool
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(enabled ? .green : .gray)
                .frame(width: 20)

            // 标题和描述
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 开关
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { _ in onToggle?() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(enabled ? 0.05 : 0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    SecurityStatusView()
        .frame(width: 300)
}
