import SwiftUI
import Combine

/// 安全功能管理器 - 管理各项安全功能的状态
class SecurityFeatureManager: ObservableObject {
    static let shared = SecurityFeatureManager()

    // 各安全功能状态
    @Published var clipboardProtection: Bool = true
    @Published var autoTokenRefresh: Bool = true
    @Published var quotaWarning: Bool = true
    @Published var keyboardShortcuts: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSettings()
        observeChanges()
    }

    private func loadSettings() {
        clipboardProtection = UserDefaults.standard.bool(forKey: "clipboardProtection")
        if UserDefaults.standard.object(forKey: "clipboardProtection") == nil {
            clipboardProtection = true
        }

        autoTokenRefresh = UserDefaults.standard.bool(forKey: "autoTokenRefresh")
        if UserDefaults.standard.object(forKey: "autoTokenRefresh") == nil {
            autoTokenRefresh = true
        }

        quotaWarning = UserDefaults.standard.bool(forKey: "quotaWarningEnabled")
        if UserDefaults.standard.object(forKey: "quotaWarningEnabled") == nil {
            quotaWarning = true
        }

        keyboardShortcuts = UserDefaults.standard.bool(forKey: "keyboardShortcutsEnabled")
        if UserDefaults.standard.object(forKey: "keyboardShortcutsEnabled") == nil {
            keyboardShortcuts = true
        }
    }

    private func observeChanges() {
        $clipboardProtection
            .dropFirst()
            .sink { _ in }
            .store(in: &cancellables)

        $autoTokenRefresh
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "autoTokenRefresh") }
            .store(in: &cancellables)

        $quotaWarning
            .dropFirst()
            .sink { QuotaWarningService.shared.setEnabled($0) }
            .store(in: &cancellables)

        $keyboardShortcuts
            .dropFirst()
            .sink { KeyboardShortcutsManager.shared.setEnabled($0) }
            .store(in: &cancellables)
    }

    /// 获取整体安全状态
    var overallStatus: SecurityStatus {
        let features: [Bool] = [
            clipboardProtection,
            autoTokenRefresh,
            quotaWarning,
            keyboardShortcuts
        ]

        let enabledCount = features.filter { $0 }.count

        if enabledCount >= features.count {
            return .secure
        } else if enabledCount >= features.count / 2 {
            return .partial
        } else {
            return .warning
        }
    }

    var overallStatusIcon: String {
        switch overallStatus {
        case .secure: return "checkmark.shield.fill"
        case .partial: return "shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        }
    }

    var overallStatusColor: Color {
        switch overallStatus {
        case .secure: return .green
        case .partial: return .yellow
        case .warning: return .red
        }
    }

    var overallStatusText: String {
        switch overallStatus {
        case .secure: return "安全状态良好"
        case .partial: return "部分安全功能已启用"
        case .warning: return "建议启用更多安全功能"
        }
    }
}

enum SecurityStatus {
    case secure
    case partial
    case warning
}

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