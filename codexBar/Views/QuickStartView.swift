import SwiftUI
import Combine

/// 快速开始管理器（简化版）
class QuickStartManager: ObservableObject {
    static let shared = QuickStartManager()

    @Published var hasCompleted: Bool = true

    let steps: [QuickStartStep] = []

    func markCompleted() {
        hasCompleted = true
    }
}

struct QuickStartStep {
    let title: String
    let description: String
    let iconName: String
}

/// 快速开始视图（简化版）
struct QuickStartView: View {
    var body: some View {
        Text(L.quickStartTitle)
    }
}