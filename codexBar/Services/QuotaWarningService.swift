import Foundation

/// 用量预警服务
final class QuotaWarningService {
    static let shared = QuotaWarningService()
    
    @UserStorage("quotaWarningThreshold") var threshold: Int = 80
    
    /// 检查所有账号的用量，触发预警
    func checkAllAccounts(_ accounts: [TokenAccount]) {
        for account in accounts {
            checkAccount(account)
        }
    }
    
    /// 检查单个账号的用量
    func checkAccount(_ account: TokenAccount) {
        guard !account.isTokenExpired else { return }
        
        guard let primaryPercent = account.primaryUsedPercent,
              primaryPercent >= Double(threshold),
              !account.hasShownQuotaWarning else { return }
        
        showWarning(account: account, percent: Int(primaryPercent))
        account.hasShownQuotaWarning = true
    }
    
    /// 显示预警通知
    private func showWarning(account: TokenAccount, percent: Int) {
        let content = NSUserNotification()
        content.title = L.quotaWarningTitle
        content.subtitle = L.quotaWarningMessage(percent)
        content.informativeText = "\(account.email) - \(account.planType)"
        content.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.scheduleNotification(content)
    }
    
    /// 启动监控
    func startMonitoring() {
        // 轮询检查（每分钟）
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAllAccounts(TokenStore.shared.accounts)
        }
    }
    
    /// 停止监控
    func stopMonitoring() {
        // Timer 会被 automatically invalidate when the service is deallocated
    }
}

extension TokenAccount {
    @UserStorage("quotaWarning_shown_")
    private(set) var hasShownQuotaWarning: Bool = false
}
