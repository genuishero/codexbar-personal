import SwiftUI

/// 安全状态显示视图（简化版）
struct SecurityStatusView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.securityStatusLabel)
                .font(.headline)
        }
        .padding()
    }
}