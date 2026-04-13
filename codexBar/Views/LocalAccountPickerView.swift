import SwiftUI

/// 本地账号选择视图 - 显示发现的本地账号供用户选择导入
struct LocalAccountPickerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var discoveredAccounts: [DiscoveredLocalAccount] = []
    @State private var selectedAccounts: Set<String> = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(L.localAccountDiscoveryTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 内容
            if discoveredAccounts.isEmpty {
                emptyState
            } else {
                accountList
            }

            Divider()

            // 底部按钮
            footerButtons
        }
        .frame(width: 400, height: 300)
        .onAppear {
            loadDiscoveredAccounts()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text(L.localAccountNoAccountsFound)
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Text(L.localAccountDiscoveryHint)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountList: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(L.localAccountDiscoveryHint)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)

                ForEach(discoveredAccounts) { account in
                    LocalAccountRow(
                        account: account,
                        isSelected: selectedAccounts.contains(account.id),
                        onToggle: {
                            if selectedAccounts.contains(account.id) {
                                selectedAccounts.remove(account.id)
                            } else {
                                selectedAccounts.insert(account.id)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxHeight: .infinity)
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            } else if let success = successMessage {
                Text(success)
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }

            Spacer()

            Button(L.cancel) {
                dismiss()
            }

            if !discoveredAccounts.isEmpty {
                Button {
                    importSelectedAccounts()
                } label: {
                    Text(L.save)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAccounts.isEmpty || isImporting)
            }
        }
        .padding()
    }

    private func loadDiscoveredAccounts() {
        discoveredAccounts = LocalAccountDiscoveryService.shared.discoverLocalAccounts()
    }

    private func importSelectedAccounts() {
        isImporting = true
        errorMessage = nil
        successMessage = nil

        var importedCount = 0
        var failedCount = 0

        for accountId in selectedAccounts {
            guard let account = discoveredAccounts.first(where: { $0.id == accountId }) else {
                continue
            }

            do {
                try LocalAccountDiscoveryService.shared.addDiscoveredAccount(account, activate: false)
                importedCount += 1
            } catch LocalAccountError.alreadyExists {
                failedCount += 1
            } catch {
                failedCount += 1
            }
        }

        isImporting = false

        if importedCount > 0 {
            successMessage = "已导入 \(importedCount) 个账号"
            if failedCount > 0 {
                successMessage! += "，\(failedCount) 个已存在"
            }

            // 刷新 TokenStore
            TokenStore.shared.load()

            // 延迟关闭
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        } else {
            errorMessage = L.localAccountAlreadyExists
        }
    }
}

/// 本地账号行视图
struct LocalAccountRow: View {
    let account: DiscoveredLocalAccount
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 选择图标
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture {
                    onToggle()
                }

            // 账号信息
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.system(size: 12, weight: .medium))

                Text(account.accountId)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 来源标签
            Text(sourceText)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
        )
        .onTapGesture {
            onToggle()
        }
    }

    private var sourceText: String {
        switch account.source {
        case .authJSON:
            return L.localAccountSourceAuthJSON
        case .tokenPool:
            return L.localAccountSourceTokenPool
        }
    }
}

// MARK: - Sheet Presenter

struct LocalAccountPickerSheetModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                LocalAccountPickerView()
            }
    }
}

extension View {
    func localAccountPickerSheet(isPresented: Binding<Bool>) -> some View {
        modifier(LocalAccountPickerSheetModifier(isPresented: isPresented))
    }
}