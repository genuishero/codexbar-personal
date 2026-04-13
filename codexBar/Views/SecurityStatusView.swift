import SwiftUI

/// 安全状态显示视图
struct SecurityStatusView: View {
    @StateObject var manager = SecurityFeatureManager.shared
    
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.securityStatusLabel)
                .font(.headline)
                .padding(.bottom, 8)
            
            SecurityFeatureItem(
                icon: "lock.fill",
                title: L.encryptionEnabled,
                enabled: !manager.useSecureStorage,
                action: { }
            )
            
            SecurityFeatureItem(
                icon: "viewfinder",
                title: L.clipboardProtected,
                enabled: manager.clipboardProtection,
                action: { manager.clipboardProtection.toggle() }
            )
            
            SecurityFeatureItem(
                icon: "arrow.triangle.badge",
                title: L.autoTokenRefresh,
                enabled: manager.autoTokenRefresh,
                action: { manager.autoTokenRefresh.toggle() }
            )
            
            SecurityFeatureItem(
                icon: "exclamationmark.bubble",
                title: L.quotaWarning,
                enabled: manager.quotaWarning,
                action: { manager.quotaWarning.toggle() }
            )
            
            SecurityFeatureItem(
                icon: "keyboard",
                title: L.keyboardShortcuts,
                enabled: manager.keyboardShortcuts,
                action: { manager.keyboardShortcuts.toggle() }
            )
        }
        .padding()
    }
}

struct SecurityFeatureItem: View {
    let icon: String
    let title: String
    @State var enabled: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(enabled ? .green : .red, .gray)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Toggle("", isOn: $enabled)
                .onChange(of: enabled) { _ in action() }
        }
    }
}
