import Foundation
import Carbon
import Combine
import AppKit

/// 快捷键管理器 - Cmd+Shift+1~5 快速切换账号
final class KeyboardShortcutsManager: ObservableObject {
    static let shared = KeyboardShortcutsManager()

    @Published var enabled: Bool = true
    @Published var shortcuts: [Int: String] = [:]

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [Int: EventHotKeyRef] = [:]
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadSettings()
        observeAccountChanges()
    }

    // MARK: - Settings

    private func loadSettings() {
        enabled = SecurityFeatureDefaults.bool(
            forKey: SecurityFeatureDefaults.keyboardShortcutsEnabledKey,
            default: true
        )
    }

    private func observeAccountChanges() {
        // 监听账号列表变化，更新快捷键映射
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateShortcuts()
            }
            .store(in: &cancellables)
    }

    // MARK: - HotKey Registration

    /// 启动快捷键监听
    func startListening() {
        guard enabled else { return }
        guard eventHandler == nil else { return }

        // 安装事件处理器
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<KeyboardShortcutsManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(event)
                return OSStatus(noErr)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        // 注册 Cmd+Shift+1~5
        for i in 1...5 {
            registerHotKey(number: i)
        }
    }

    /// 停止快捷键监听
    func stopListening() {
        // 移除所有热键
        for (_, hotKeyRef) in hotKeys {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeys.removeAll()

        // 移除事件处理器
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func registerHotKey(number: Int) {
        // 键码: 1=0x12, 2=0x13, 3=0x14, 4=0x15, 5=0x17
        let keyCode: UInt32
        switch number {
        case 1: keyCode = UInt32(kVK_ANSI_1)
        case 2: keyCode = UInt32(kVK_ANSI_2)
        case 3: keyCode = UInt32(kVK_ANSI_3)
        case 4: keyCode = UInt32(kVK_ANSI_4)
        case 5: keyCode = UInt32(kVK_ANSI_5)
        default: return
        }

        let modifier = UInt32(cmdKey | shiftKey)
        let hotKeyID = EventHotKeyID(signature: OSType(0x43425348), id: UInt32(number)) // "CBSH"

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifier,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeys[number] = ref
        }
    }

    // MARK: - Event Handling

    private func handleHotKeyEvent(_ event: EventRef?) {
        guard let event = event else { return }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return }

        let number = Int(hotKeyID.id)

        Task { @MainActor in
            self.switchToAccount(number: number)
        }
    }

    private func switchToAccount(number: Int) {
        guard enabled else { return }

        let accounts = TokenStore.shared.accounts
        guard number >= 1 && number <= accounts.count else { return }

        let account = accounts[number - 1]

        // 切换账号
        try? TokenStore.shared.activate(account, reason: .manual)

        // 显示通知
        showSwitchNotification(account: account, number: number)
    }

    private func showSwitchNotification(account: TokenAccount, number: Int) {
        let accountLabel = account.email.isEmpty ? account.accountId : account.email
        CodexBarNotificationCenter.deliver(
            title: L.shortcutGuide,
            subtitle: accountLabel,
            body: L.shortcutDescription(number, accountLabel),
            identifier: "shortcut-switch-\(number)-\(account.accountId)"
        )
    }

    // MARK: - Public API

    /// 更新快捷键映射
    func updateShortcuts() {
        let accounts = TokenStore.shared.accounts
        let count = min(5, accounts.count)

        guard count > 0 else {
            shortcuts = [:]
            return
        }

        shortcuts = Dictionary(uniqueKeysWithValues: (1...count).map { number in
            let account = accounts[number - 1]
            let accountLabel = account.email.isEmpty ? account.accountId : account.email
            return (number, accountLabel)
        })
    }

    /// 设置启用状态
    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        UserDefaults.standard.set(value, forKey: SecurityFeatureDefaults.keyboardShortcutsEnabledKey)

        if value {
            startListening()
        } else {
            stopListening()
        }
    }
}
