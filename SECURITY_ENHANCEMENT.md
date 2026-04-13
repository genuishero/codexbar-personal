# CodexBar 安全增强实施计划

## 已完成部分

### 1. 中文翻译完善 ✅
- 添加了剪贴板清除、快速开始引导、安全状态指示器、用量预警、快捷键相关的所有文案
- commit: `e5c5e43` - chore: 完善中文翻译

---

## 待实施的安全增强功能

### 🔴 P0 - 必须实现（安全性基础）

#### 1. 剪贴板自动清除
**目标**：用户复制敏感信息（API Key / Token）后 30 秒自动清除剪贴板

**实现方案**：
```swift
// ClipboardManager.swift
import AppKit

final class ClipboardManager {
    static let shared = ClipboardManager()
    
    private var clearTimer: Timer?
    private let clearDelay: TimeInterval = 30
    
    func setText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        // 启动清除计时器
        startClearTimer()
    }
    
    func clear() {
        NSPasteboard.general.clearContents()
    }
    
    private func startClearTimer() {
        clearTimer?.invalidate()
        clearTimer = Timer.scheduledTimer(withTimeInterval: clearDelay, repeats: false) { [weak self] _ in
            self?.clear()
        }
    }
}
```

**集成点**：
- 所有复制操作使用 `ClipboardManager.shared.setText()`
- Settings 窗口中绑定快捷键复制 API Key 时触发

---

#### 2. 快速开始引导
**目标**：首次使用时显示 4 步引导卡片

**实现方案**：
```swift
// QuickStartManager.swift
import SwiftUI

struct QuickStartManager {
    static let shared = QuickStartManager()
    
    @UserStorage("hasCompletedQuickStart") var hasCompleted: Bool = false
    
    let steps = [
        QuickStartStep(
            title: L.quickStartStep1,
            description: L.quickStartStep1Desc,
            iconName: "plus.circle"
        ),
        QuickStartStep(
            title: L.quickStartStep2,
            description: L.quickStartStep2Desc,
            iconName: "horse.circle"
        ),
        QuickStartStep(
            title: L.quickStartStep3,
            description: L.quickStartStep3Desc,
            iconName: "keyboard.circle"
        ),
        QuickStartStep(
            title: L.quickStartStep4,
            description: L.quickStartStep4Desc,
            iconName: "bell.circle"
        )
    ]
}

struct QuickStartStep {
    let title: String
    let description: String
    let iconName: String
}
```

**集成点**：
- 在 `ContentView.swift` 首次启动时显示 `QuickStartView`
- 提供 "跳过" 和 "完成" 按钮

---

#### 3. 安全状态指示器
**目标**：设置页显示安全功能开启状态

**实现方案**：
```swift
// SecureSettingsView.swift
struct SecureSettingsView: View {
    @StateObject var store = TokenStore.shared
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(L.securityStatusLabel)
                .font(.headline)
            
            SecureFeatureItem(
                icon: "lock.fill",
                title: L.encryptionEnabled,
                enabled: !FeatureFlags.useSecureStorage,
                action: enableEncryption
            )
            SecureFeatureItem(
                icon: ".viewfinder",
                title: L.clipboardProtected,
                enabled: FeatureFlags.clipboardProtection,
                action: toggleClipboardProtection
            )
            SecureFeatureItem(
                icon: "arrow.triangle.badge",
                title: L.autoTokenRefresh,
                enabled: FeatureFlags.autoTokenRefresh,
                action: toggleAutoRefresh
            )
            SecureFeatureItem(
                icon: "exclamationmark.bubble",
                title: L.quotaWarning,
                enabled: FeatureFlags.quotaWarning,
                action: toggleQuotaWarning
            )
            SecureFeatureItem(
                icon: "keyboard",
                title: L.keyboardShortcuts,
                enabled: FeatureFlags.keyboardShortcuts,
                action: toggleKeyboardShortcuts
            )
        }
        .padding()
    }
}

struct SecureFeatureItem: View {
    let icon: String
    let title: String
    let enabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.green, .gray)
            Text(title)
            Spacer()
            Toggle(isOn: $enabled) {
                // Toggle
            }
            .onChange(of: enabled) { _ in action() }
        }
    }
}
```

**集成点**：
- Settings 窗口中添加 "Security" 标签页或在 Overview 页添加安全状态区块

---

### 🟠 P1 - 强烈推荐

#### 4. 自动 Token 刷新
**目标**：OAuth Token 过期前自动刷新

**实现方案**：
```swift
// TokenRefreshService.swift
final class TokenRefreshService {
    static let shared = TokenRefreshService()
    
    private var timer: Timer?
    private let refreshBuffer: TimeInterval = 3600 * 2 // 提前 2 小时刷新
    
    func start Monitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.checkAndRefresh()
        }
    }
    
    private func checkAndRefresh() {
        guard let expiredToken = store.accounts.first(where: { 
            $0.isTokenExpiring(Within: refreshBuffer) 
        }) else { return }
        
        TokenRefresher.refresh(token: expiredToken) { result in
            switch result {
            case .success:
                L10n.showNotification(L.tokenRefreshed)
            case .failure:
                L10n.showNotification(L.tokenRefreshFailed)
            }
        }
    }
}
```

**集成点**：
- 在 `TokenStore.shared` 初始化时调用 `TokenRefreshService.shared.startMonitoring()`
- 集成到 `CodexSyncService` 的同步流程

---

#### 5. 用量预警
**目标**：当账号用量达到阈值时弹窗提醒

**实现方案**：
```swift
// QuotaWarningService.swift
final class QuotaWarningService {
    static let shared = QuotaWarningService()
    @UserStorage("quotaWarningThreshold") var threshold: Int = 80
    
    func checkQuota(_ account: TokenAccount) {
        guard let usedPercent = account.primaryUsedPercent,
              usedPercent >= threshold,
              !account.hasShownWarning else { return }
        
        NSUserNotificationCenter.default.scheduleNotification(
            title: L.quotaWarningTitle,
            subtitle: L.quotaWarningMessage(Int(usedPercent)),
            userInfo: ["accountId": account.accountId]
        )
        account.hasShownWarning = true
    }
}
```

**集成点**：
- 在 `TokenStore` 的 `publishState()` 中调用 `QuotaWarningService.shared.checkQuota()`
- 配对到设置页的用量阈值配置

---

#### 6. 快捷键支持
**目标**：`Cmd+Shift+1~5` 快速切换账号

**实现方案**：
```swift
// KeyboardShortcuts.swift
struct KeyboardShortcuts {
    static let shared = KeyboardShortcuts()
    @UserStorage("keyboardShortcutsEnabled") var enabled: Bool = true
    
    func register(shortcuts: [KeyboardShortcut]) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.enabled == true else { return event }
            return self?.handle(event) ?? event
        }
    }
    
    private func handle(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == [.shift, .command] else { return event }
        
        guard let number = Int(event.characters ?? ""),
              let account = store.accounts[safe: number - 1] else { return event }
        
        try? store.activate(account, reason: .keyboardShortcut)
        return nil // 消费事件
    }
}

struct KeyboardShortcut {
    let number: Int
    let accountID: String
}
```

**集成点**：
- `MenuBarView` 中注册快捷键监听
- Settings 窗口中提供快捷键配置界面

---

### 🟡 P2 - 可选增强

#### 7. 主密码保护（可选）
**说明**：需要与 Keychain 集成，实现更高级别的安全

#### 8. 应用沙箱（App Sandbox）
**说明**：提升安全性，但可能影响功能

#### 9. 安全日志（Audit Log）
**说明**：记录关键操作，便于追溯

---

## 实施优先级

### 第一阶段（基础安全） - 1-2 周
1. ✅ Chinese localization（已完成）
2. 剪贴板自动清除
3. 快速开始引导
4. 快捷键支持
5. 自动 Token 刷新
6. 用量预警

### 第二阶段（安全增强） - 1-2 周
7. 安全状态指示器（UI）
8. 主密码保护（可选）
9. 应用沙箱（+)App Sandbox）（可选）
10. 安全日志（可选）

### 第三阶段（企业级） - 2-3 周
11. 集中管理后台
12. SSO/SAML 集成
13. 审计日志
14. 团队协作功能

---

## 立即可做的修改

### 1. 添加剪贴板清除功能
- 创建 `ClipboardManager.swift`
- 在所有复制操作处调用 `ClipboardManager.shared.setText()`

### 2. 添加快速开始引导
- 创建 `QuickStartManager.swift` + `QuickStartView.swift`
- 在 `ContentView` 首次启动时显示

### 3. 添加快捷键支持
- 创建 `KeyboardShortcuts.swift`
- 在 `MenuBarView` 中注册监听

### 4. 添加用量预警
- 创建 `QuotaWarningService.swift`
- 在 Token 刷新时检查阈值

### 5. 添加安全状态 UI
- 在设置页添加安全状态区块

---

## 下一步行动

你需要决定：

**选项 A：我帮你逐个实现以上功能**
- 按优先级依次实现，每个功能独立 commit
- 先做基础安全（剪贴板 + 快捷键 + 引导）

**选项 B：你选几个重点功能我来实现**
- 比如只做：剪贴板清除 + 快捷键 + 引导

**选项 C：你想要调整优先级**
- 比如先做主密码保护而不是快捷键

告诉我你的想法，我立即开始 implementation！🚀
