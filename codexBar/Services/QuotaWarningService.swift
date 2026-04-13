import Foundation
import Combine

/// 用量预警服务 - 监控账号用量并在达到阈值时提醒用户
final class QuotaWarningService: ObservableObject {
    static let shared = QuotaWarningService()

    @Published var threshold: Int = 80
    @Published var enabled: Bool = true

    private var checkedAccounts: Set<String> = []
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSettings()
        observeThresholdChanges()
    }

    // MARK: - Settings

    private func loadSettings() {
        threshold = UserDefaults.standard.integer(forKey: "quotaWarningThreshold")
        if threshold == 0 { threshold = 80 } // 默认 80%

        enabled = UserDefaults.standard.bool(forKey: "quotaWarningEnabled")
        if UserDefaults.standard.object(forKey: "quotaWarningEnabled") == nil {
            enabled = true // 默认启用
        }
    }

    private func observeThresholdChanges() {
        // 当阈值改变时，重置已检查的账号，以便重新检查
        $threshold
            .dropFirst()
            .sink { [weak self] _ in
                self?.checkedAccounts.removeAll()
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitoring

    /// 启动监控
    func startMonitoring() {
        guard enabled else { return }

        // 每 60 秒检查一次
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkAllAccounts()
        }

        // 立即检查一次
        checkAllAccounts()
    }

    /// 停止监控
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// 检查所有账号的用量
    func checkAllAccounts() {
        guard enabled else { return }

        let accounts = TokenStore.shared.accounts
        for account in accounts {
            checkAccount(account)
        }
    }

    /// 检查单个账号的用量
    func checkAccount(_ account: TokenAccount) {
        guard enabled else { return }

        // 检查 Token 是否过期
        if account.tokenExpired {
            return
        }

        // 检查是否已经预警过
        if checkedAccounts.contains(account.accountId) {
            return
        }

        // 获取用量百分比
        let primaryPercent = account.primaryUsedPercent ?? 0
        let secondaryPercent = account.secondaryUsedPercent ?? 0

        // 检查是否超过阈值
        let effectivePercent = max(primaryPercent, secondaryPercent)

        guard effectivePercent >= Double(threshold) else { return }

        // 显示预警通知
        showWarning(account: account, percent: Int(effectivePercent))

        // 记录已检查
        checkedAccounts.insert(account.accountId)
    }

    /// 显示预警通知
    private func showWarning(account: TokenAccount, percent: Int) {
        let content = NSUserNotification()
        content.title = L.quotaWarningTitle
        content.subtitle = account.email ?? account.accountId
        content.informativeText = L.quotaWarningMessage(percent)
        content.soundName = NSUserNotificationDefaultSoundName
        content.deliveryDate = Date()
        content.hasActionButton = true
        content.actionButtonTitle = L.settings

        // 设置标识符以便用户点击时打开设置
        content.identifier = "quota-warning-\(account.accountId)"

        NSUserNotificationCenter.default.deliver(content)
    }

    // MARK: - Public API

    /// 设置阈值
    func setThreshold(_ value: Int) {
        threshold = max(10, min(99, value)) // 限制在 10-99 范围
        UserDefaults.standard.set(threshold, forKey: "quotaWarningThreshold")
        checkedAccounts.removeAll()
    }

    /// 设置启用状态
    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: "quotaWarningEnabled")

        if value {
            startMonitoring()
        } else {
            stopMonitoring()
            checkedAccounts.removeAll()
        }
    }

    /// 重置预警状态（用于账号恢复后）
    func resetWarning(for accountId: String) {
        checkedAccounts.remove(accountId)
    }

    /// 重置所有预警状态（用于用量重置周期后）
    func resetAllWarnings() {
        checkedAccounts.removeAll()
    }
}