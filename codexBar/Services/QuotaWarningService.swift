import Foundation

/// 用量预警服务（简化版）
final class QuotaWarningService {
    static let shared = QuotaWarningService()

    var threshold: Int = 80

    private init() {}

    func checkAllAccounts(_ accounts: [TokenAccount]) {}
    func checkAccount(_ account: TokenAccount) {}
    func startMonitoring() {}
    func stopMonitoring() {}
}