import SwiftUI

/// 快速开始步骤模型
struct QuickStartStep {
    let title: String
    let description: String
    let iconName: String
}

/// 快速开始管理器 - 检测是否首次使用
struct QuickStartManager {
    static let shared = QuickStartManager()
    
    @UserStorage("hasCompletedQuickStart") var hasCompleted: Bool = false
    
    let steps: [QuickStartStep] = [
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
    
    func markCompleted() {
        hasCompleted = true
    }
}

/// 快速开始视图 - 首次启动时显示
struct QuickStartView: View {
    @Environment(\.presentationMode) var presentationMode
    @_STATE var completed: Bool = false
    
    let manager = QuickStartManager.shared
    @State private var currentIndex: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Progress
                HStack {
                    ForEach(0..<manager.steps.count, id: \.self) { index in
                        Circle()
                            .stroke(index <= currentIndex ? Color.blue : Color.gray, lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .background(Circle().fill(index < currentIndex ? Color.green : Color.clear))
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Step Content
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: manager.steps[currentIndex].iconName)
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text(manager.steps[currentIndex].title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(manager.steps[currentIndex].description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
                
                Spacer()
                
                // Buttons
                HStack {
                    if currentIndex > 0 {
                        Button(action: previousStep) {
                            Text("上一步")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    if currentIndex == manager.steps.count - 1 {
                        Button(action: finish) {
                            Text(L.done)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: nextStep) {
                            Text(L.nextStep)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    Button(action: skip) {
                        Text(L.skipTutorial)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .padding(40)
            .frame(minWidth: 500, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
            .navigationTitle(L.quickStartTitle)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { closeItem } }
        }
    }
    
    private var closeItem: some View {
        Button(action: skip) { Image(systemName: "xmark") }
    }
    
    private func nextStep() {
        withAnimation { currentIndex += 1 }
    }
    
    private func previousStep() {
        withAnimation { currentIndex -= 1 }
    }
    
    private func finish() {
        manager.markCompleted()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func skip() {
        manager.markCompleted()
        presentationMode.wrappedValue.dismiss()
    }
}
