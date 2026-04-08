import AppKit
import Foundation

enum OpenAIAccountCSVToolbarUI {
    static let symbolName = "arrow.up.arrow.down.circle"
    static let accessibilityIdentifier = "codexbar.openai-csv.toolbar"
}

@MainActor
struct OpenAIAccountCSVPanelService {
    typealias AppActivator = () -> Void
    typealias ExportRiskConfirmation = () -> Bool
    typealias ExportURLRequester = (_ suggestedFilename: String) -> URL?
    typealias ImportURLRequester = () -> URL?

    private let activateApp: AppActivator
    private let confirmSensitiveExportAction: ExportRiskConfirmation
    private let requestExportURLAction: ExportURLRequester
    private let requestImportURLAction: ImportURLRequester

    init(
        activateApp: @escaping AppActivator = OpenAIAccountCSVPanelService.activateApp,
        confirmSensitiveExportAction: @escaping ExportRiskConfirmation = OpenAIAccountCSVPanelService.confirmSensitiveExport,
        requestExportURLAction: @escaping ExportURLRequester = OpenAIAccountCSVPanelService.presentExportPanel(suggestedFilename:),
        requestImportURLAction: @escaping ImportURLRequester = OpenAIAccountCSVPanelService.presentImportPanel
    ) {
        self.activateApp = activateApp
        self.confirmSensitiveExportAction = confirmSensitiveExportAction
        self.requestExportURLAction = requestExportURLAction
        self.requestImportURLAction = requestImportURLAction
    }

    func requestExportURL() -> URL? {
        self.activateApp()
        guard self.confirmSensitiveExportAction() else { return nil }
        return self.requestExportURLAction(self.defaultExportFilename())
    }

    func requestImportURL() -> URL? {
        self.activateApp()
        return self.requestImportURLAction()
    }

    private func defaultExportFilename(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "openai-accounts-\(formatter.string(from: now)).csv"
    }

    private static func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func confirmSensitiveExport() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.openAICSVRiskTitle
        alert.informativeText = L.openAICSVRiskMessage
        alert.addButton(withTitle: L.openAICSVRiskConfirm)
        alert.addButton(withTitle: L.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private static func presentExportPanel(suggestedFilename: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = L.exportOpenAICSVAction
        panel.prompt = L.openAICSVExportPrompt
        panel.canCreateDirectories = true
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = suggestedFilename
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func presentImportPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L.importOpenAICSVAction
        panel.prompt = L.openAICSVImportPrompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowsOtherFileTypes = false
        panel.allowedFileTypes = ["csv"]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
