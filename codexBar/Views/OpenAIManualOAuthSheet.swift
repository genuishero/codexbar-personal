import SwiftUI

struct OpenAIManualOAuthSheet: View {
    let authURL: String
    let isAuthenticating: Bool
    let errorMessage: String?
    @Binding var callbackInput: String
    let onComplete: (String) -> Void
    let onOpenBrowser: () -> Void
    let onCopyLink: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L.oauthDialogTitle)
                .font(.headline)

            Text(L.oauthStep1)
                .font(.system(size: 12))
            Text(L.oauthStep2)
                .font(.system(size: 12))
            Text(L.oauthStep3)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            ScrollView {
                Text(authURL.isEmpty ? L.authorizationLinkNotReady : authURL)
                    .textSelection(.enabled)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 72)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            )

            HStack {
                Button(L.openBrowserBtn, action: onOpenBrowser)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Open Browser")
                    .accessibilityIdentifier("codexbar.oauth.open-browser")
                Button(L.copyLinkBtn, action: onCopyLink)
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Copy Login Link")
                    .accessibilityIdentifier("codexbar.oauth.copy-link")
            }

            TextEditor(text: $callbackInput)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 110)
                .padding(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .accessibilityLabel("OAuth Callback Input")
                .accessibilityIdentifier("codexbar.oauth.callback-input")
                .accessibilityHint(L.oauthPasteHint)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }

            HStack {
                Spacer()
                Button(L.cancel) {
                    onCancel()
                }
                .accessibilityLabel("Cancel Login")
                .accessibilityIdentifier("codexbar.oauth.cancel")
                Button(L.completeLoginBtn) {
                    onComplete(callbackInput)
                }
                .buttonStyle(.borderedProminent)
                .disabled(callbackInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isAuthenticating)
                .accessibilityLabel("Complete Login")
                .accessibilityIdentifier("codexbar.oauth.complete-login")
            }
        }
        .padding(16)
        .frame(width: 520)
    }
}
