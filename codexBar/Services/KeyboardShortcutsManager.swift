import Foundation

/// 快捷键管理器 - Cmd+Shift+1~5 快速切换账号
final class KeyboardShortcutsManager {
    static let shared = KeyboardShortcutsManager()
    
    @UserStorage("keyboardShortcutsEnabled") var enabled: Bool = true
    
    private var monitor: NSEventMonitor?
    @Published private(set) var shortcuts: [Int: String] = [:]
    
    private init() {
        loadShortcuts()
    }
    
    /// 启动快捷键监听
    func startListening() {
        guard enabled else { return }
        
        monitor = NSEventMonitor(scope: .application) { [weak self] event in
            guard event.type == .keyDown else { return nil }
            
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers == [.shift, .command] else { return event }
            
            return self?.handleKeyDown(event)
        }
        monitor?.start()
    }
    
    /// 停止快捷键监听
    func stopListening() {
        monitor?.stop()
        monitor = nil
    }
    
    /// 处理按键事件
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let number = Int(event.characters ?? "") else { return event }
        guard number >= 1 && number <= 5 else { return event }
        
        guard let account = TokenStore.shared.accounts.safe(number - 1) else { return event }
        
        try? TokenStore.shared.activate(account, reason: .keyboardShortcut)
        return nil // 消费事件
    }
    
    /// 加载快捷键配置
    private func loadShortcuts() {
        let count = TokenStore.shared.accounts.count
        shortcuts = Dictionary(uniqueKeysWithValues: (1...min(5, count)).map { ($0, "") })
    }
    
    /// 更新快捷键映射
    func updateShortcuts() {
        loadShortcuts()
    }
}
