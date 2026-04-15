import AppKit

/// 剪贴板管理器 - 复制敏感信息后自动清除
@MainActor
final class ClipboardManager {
    static let shared = ClipboardManager()

    private var clearTimer: Timer?
    private let clearDelay: TimeInterval = 30
    private var enabled: Bool
    private var managedString: String?
    private var managedChangeCount: Int?

    private init() {
        self.enabled = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.clipboardProtectionKey,
            default: true
        )
    }

    /// 设置剪贴板内容并启动清除计时器
    func setText(_ text: String) {
        self.cancelClearTimer()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        guard self.enabled else { return }

        self.managedString = text
        self.managedChangeCount = NSPasteboard.general.changeCount
        self.startClearTimer()
    }

    /// 清除由 codexbar 写入且仍未被其它应用覆盖的剪贴板内容
    func clear() {
        if self.isTrackingCurrentPasteboardContents() {
            NSPasteboard.general.clearContents()
        }
        self.cancelClearTimer()
    }

    func setEnabled(_ value: Bool) {
        self.enabled = value
        UserDefaults.standard.set(value, forKey: SecurityFeatureDefaults.clipboardProtectionKey)
        if value == false {
            self.cancelClearTimer()
        }
    }

    /// 取消清除计时器
    func cancelClearTimer() {
        self.clearTimer?.invalidate()
        self.clearTimer = nil
        self.managedString = nil
        self.managedChangeCount = nil
    }

    private func startClearTimer() {
        self.clearTimer?.invalidate()
        self.clearTimer = Timer.scheduledTimer(withTimeInterval: self.clearDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clear()
            }
        }
    }

    private func isTrackingCurrentPasteboardContents() -> Bool {
        guard let managedString = self.managedString,
              let managedChangeCount = self.managedChangeCount else {
            return false
        }

        guard NSPasteboard.general.changeCount == managedChangeCount else {
            return false
        }

        return NSPasteboard.general.string(forType: .string) == managedString
    }
}
