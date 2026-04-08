import Foundation
import XCTest

@MainActor
final class OpenAIAccountCSVPanelServiceTests: XCTestCase {
    func testExportCancelAtRiskPromptDoesNotOpenSavePanel() {
        var didActivate = false
        var didRequestSavePanel = false
        let service = OpenAIAccountCSVPanelService(
            activateApp: { didActivate = true },
            confirmSensitiveExportAction: { false },
            requestExportURLAction: { _ in
                didRequestSavePanel = true
                return URL(fileURLWithPath: "/tmp/should-not-exist.csv")
            },
            requestImportURLAction: { nil }
        )

        XCTAssertNil(service.requestExportURL())
        XCTAssertTrue(didActivate)
        XCTAssertFalse(didRequestSavePanel)
    }

    func testExportPassesSuggestedCSVFilenameToSavePanel() {
        var receivedFilename: String?
        let expectedURL = URL(fileURLWithPath: "/tmp/export.csv")
        let service = OpenAIAccountCSVPanelService(
            activateApp: {},
            confirmSensitiveExportAction: { true },
            requestExportURLAction: { suggestedFilename in
                receivedFilename = suggestedFilename
                return expectedURL
            },
            requestImportURLAction: { nil }
        )

        XCTAssertEqual(service.requestExportURL(), expectedURL)
        XCTAssertEqual(receivedFilename?.hasPrefix("openai-accounts-"), true)
        XCTAssertEqual(receivedFilename?.hasSuffix(".csv"), true)
    }

    func testImportCancelReturnsNil() {
        var didActivate = false
        let service = OpenAIAccountCSVPanelService(
            activateApp: { didActivate = true },
            confirmSensitiveExportAction: { true },
            requestExportURLAction: { _ in nil },
            requestImportURLAction: { nil }
        )

        XCTAssertNil(service.requestImportURL())
        XCTAssertTrue(didActivate)
    }

    func testToolbarConstantsStayStable() {
        XCTAssertEqual(OpenAIAccountCSVToolbarUI.symbolName, "arrow.up.arrow.down.circle")
        XCTAssertEqual(OpenAIAccountCSVToolbarUI.accessibilityIdentifier, "codexbar.openai-csv.toolbar")
    }
}
