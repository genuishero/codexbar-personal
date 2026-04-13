/// 安全功能配置管理器
struct SecurityFeatureManager {
    static let shared = SecurityFeatureManager()
    
    // 剪贴板保护
    @UserStorage("clipboardProtection") var clipboardProtection: Bool = true
    
    // 自动 Token 刷新
    @UserStorage("autoTokenRefresh") var autoTokenRefresh: Bool = true
    
    // 用量预警
    @UserStorage("quotaWarning") var quotaWarning: Bool = true
    @UserStorage("quotaWarningThreshold") var quotaWarningThreshold: Int = 80
    
    // 快捷键支持
    @UserStorage("keyboardShortcuts") var keyboardShortcuts: Bool = true
}
