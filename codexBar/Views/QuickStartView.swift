import SwiftUI
import Combine

/// 快速开始步骤模型
struct QuickStartStep {
    let title: String
    let description: String
    let iconName: String
    let action: QuickStartAction
}

/// 快速开始步骤动作类型
enum QuickStartAction {
    case addAccount
    case selectAccount
    case configureShortcuts
    case configureQuotaWarning
    case none
}

/// 快速开始管理器 - 检测是否首次使用
class QuickStartManager: ObservableObject {
    static let shared = QuickStartManager()

    @Published var hasCompleted: Bool = false

    let steps: [QuickStartStep] = [
        QuickStartStep(
            title: L.quickStartStep1,
            description: L.quickStartStep1Desc,
            iconName: "plus.circle",
            action: .addAccount
        ),
        QuickStartStep(
            title: L.quickStartStep2,
            description: L.quickStartStep2Desc,
            iconName: "person.circle",
            action: .selectAccount
        ),
        QuickStartStep(
            title: L.quickStartStep3,
            description: L.quickStartStep3Desc,
            iconName: "keyboard",
            action: .configureShortcuts
        ),
        QuickStartStep(
            title: L.quickStartStep4,
            description: L.quickStartStep4Desc,
            iconName: "bell",
            action: .configureQuotaWarning
        )
    ]

    private init() {
        hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedQuickStart")
    }

    func markCompleted() {
        hasCompleted = true
        UserDefaults.standard.set(true, forKey: "hasCompletedQuickStart")
    }

    func reset() {
        hasCompleted = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedQuickStart")
    }
}

/// 快速开始视图 - 首次启动时显示的引导界面
struct QuickStartView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager = QuickStartManager.shared
    @ObservedObject var tokenStore = TokenStore.shared

    @State private var currentStep: Int = 0
    @State private var showingOAuthDialog: Bool = false
    @State private var showingSettingsWindow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            Divider()

            // 进度指示器
            progressIndicator

            // 步骤内容
            stepContent

            Spacer()

            // 底部按钮
            footerButtons
        }
        .frame(width: 520, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(L.quickStartTitle)
                .font(.system(size: 18, weight: .semibold))

            Spacer()

            Button {
                skip()
            } label: {
                Text(L.skipTutorial)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<manager.steps.count, id: \.self) { index in
                stepIndicator(for: index)
            }
        }
        .padding(.vertical, 16)
    }

    private func stepIndicator(for index: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 10, height: 10)

            if index < manager.steps.count - 1 {
                Rectangle()
                    .fill(index < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 2)
            }
        }
    }

    // MARK: - Step Content

    private var stepContent: some View {
        VStack(spacing: 16) {
            // 步骤图标
            Image(systemName: manager.steps[currentStep].iconName)
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            // 步骤标题
            Text(manager.steps[currentStep].title)
                .font(.system(size: 16, weight: .semibold))

            // 步骤描述
            Text(manager.steps[currentStep].description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // 步骤状态指示
            stepStatusIndicator
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var stepStatusIndicator: some View {
        switch manager.steps[currentStep].action {
        case .addAccount:
            if tokenStore.accounts.isEmpty {
                Button {
                    showingOAuthDialog = true
                } label: {
                    Label(L.addOpenAI, systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            } else {
                Label(L.accountUsageModeAggregate, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            }

        case .selectAccount:
            if tokenStore.activeAccount() != nil {
                Label(tokenStore.activeAccount()?.email ?? "已选择", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else if !tokenStore.accounts.isEmpty {
                Text("请从菜单栏选择一个账号")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            } else {
                Text("请先添加账号")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

        case .configureShortcuts:
            let shortcutManager = KeyboardShortcutsManager.shared
            if shortcutManager.enabled {
                Label(L.shortcutSet(min(5, tokenStore.accounts.count)), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Button {
                    showingSettingsWindow = true
                } label: {
                    Label("启用快捷键", systemImage: "gear")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

        case .configureQuotaWarning:
            let quotaService = QuotaWarningService.shared
            if quotaService.enabled {
                Label("预警阈值: \(quotaService.threshold)%", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.green)
            } else {
                Button {
                    showingSettingsWindow = true
                } label: {
                    Label("设置预警", systemImage: "bell")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
            }

        case .none:
            EmptyView()
        }
    }

    // MARK: - Footer Buttons

    private var footerButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("上一步")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                if currentStep == manager.steps.count - 1 {
                    finish()
                } else {
                    withAnimation { currentStep += 1 }
                }
            } label: {
                Text(currentStep == manager.steps.count - 1 ? L.done : L.nextStep)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Actions

    private func finish() {
        manager.markCompleted()
        dismiss()
    }

    private func skip() {
        manager.markCompleted()
        dismiss()
    }
}

// MARK: - Sheet Presenters

struct QuickStartSheetPresenter: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                QuickStartView()
            }
    }
}

extension View {
    func quickStartSheet(isPresented: Binding<Bool>) -> some View {
        modifier(QuickStartSheetPresenter(isPresented: isPresented))
    }
}