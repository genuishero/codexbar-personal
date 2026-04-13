import AppKit

/// 剪贴板管理器 - 复制敏感信息后自动清除
final class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var clearTimer: Timer?
    private let clearDelay: TimeInterval = 30
    
    /// 设置剪贴板内容并启动清除计时器
    func setText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        startClearTimer()
    }
    
    /// 立即清除剪贴板
    func clear() {
        NSPasteboard.general.clearContents()
        clearTimer?.invalidate()
        clearTimer = nil
    }
    
    /// 取消清除计时器（用户手动清空时不触发）
    func cancelClearTimer() {
        clearTimer?.invalidate()
        clearTimer = nil
    }
    
    private func startClearTimer() {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: clearDelay, repeats: false) { [weak self] _ in
            self?.clear()
        }
    }
}
