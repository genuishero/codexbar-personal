import Foundation
import Combine

/// 安全功能配置管理器（简化版）
class SecurityFeatureManager: ObservableObject {
    static let shared = SecurityFeatureManager()

    @Published var clipboardProtection: Bool = true
    @Published var autoTokenRefresh: Bool = true
    @Published var quotaWarning: Bool = true
    @Published var quotaWarningThreshold: Int = 80
    @Published var keyboardShortcuts: Bool = true
    @Published var useSecureStorage: Bool = true
}