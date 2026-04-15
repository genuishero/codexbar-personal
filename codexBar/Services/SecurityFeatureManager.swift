import Combine
import Foundation
import SwiftUI

enum SecurityFeatureDefaults {
    static let clipboardProtectionKey = "clipboardProtection"
    static let autoTokenRefreshKey = "autoTokenRefresh"
    static let quotaWarningEnabledKey = "quotaWarningEnabled"
    static let keyboardShortcutsEnabledKey = "keyboardShortcutsEnabled"

    static func bool(
        forKey key: String,
        default defaultValue: Bool,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}

/// 安全功能管理器 - 管理各项安全功能的状态
@MainActor
final class SecurityFeatureManager: ObservableObject {
    static let shared = SecurityFeatureManager()

    @Published var clipboardProtection: Bool = true
    @Published var autoTokenRefresh: Bool = true
    @Published var quotaWarning: Bool = true
    @Published var keyboardShortcuts: Bool = true

    private var cancellables = Set<AnyCancellable>()

    private init() {
        self.loadSettings()
        self.applyDisabledSettings()
        self.observeChanges()
    }

    private func loadSettings() {
        self.clipboardProtection = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.clipboardProtectionKey,
            default: true
        )
        self.autoTokenRefresh = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.autoTokenRefreshKey,
            default: true
        )
        self.quotaWarning = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.quotaWarningEnabledKey,
            default: true
        )
        self.keyboardShortcuts = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.keyboardShortcutsEnabledKey,
            default: true
        )
    }

    private func applyDisabledSettings() {
        if self.clipboardProtection == false {
            ClipboardManager.shared.setEnabled(false)
        }
        if self.autoTokenRefresh == false {
            AutoTokenRefreshService.shared.setEnabled(false)
        }
        if self.quotaWarning == false {
            QuotaWarningService.shared.setEnabled(false)
        }
        if self.keyboardShortcuts == false {
            KeyboardShortcutsManager.shared.setEnabled(false)
        }
    }

    private func observeChanges() {
        self.$clipboardProtection
            .dropFirst()
            .sink { value in
                ClipboardManager.shared.setEnabled(value)
            }
            .store(in: &self.cancellables)

        self.$autoTokenRefresh
            .dropFirst()
            .sink { value in
                AutoTokenRefreshService.shared.setEnabled(value)
            }
            .store(in: &self.cancellables)

        self.$quotaWarning
            .dropFirst()
            .sink { value in
                QuotaWarningService.shared.setEnabled(value)
            }
            .store(in: &self.cancellables)

        self.$keyboardShortcuts
            .dropFirst()
            .sink { value in
                KeyboardShortcutsManager.shared.setEnabled(value)
            }
            .store(in: &self.cancellables)
    }

    var overallStatus: SecurityStatus {
        let features: [Bool] = [
            self.clipboardProtection,
            self.autoTokenRefresh,
            self.quotaWarning,
            self.keyboardShortcuts,
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
        switch self.overallStatus {
        case .secure: return "checkmark.shield.fill"
        case .partial: return "shield.fill"
        case .warning: return "exclamationmark.shield.fill"
        }
    }

    var overallStatusColor: Color {
        switch self.overallStatus {
        case .secure: return .green
        case .partial: return .yellow
        case .warning: return .red
        }
    }

    var overallStatusText: String {
        switch self.overallStatus {
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
