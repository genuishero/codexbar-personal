import Foundation
import XCTest

@MainActor
final class UpdateCoordinatorTests: XCTestCase {
    func testManualCheckPromptsAvailableUpdateAndSkipsExecutionWhenCancelled() async {
        let feedLoader = MockFeedLoader(feed: self.makeFeed(version: "1.1.6"))
        let presenter = MockUpdatePresenter()
        presenter.nextChoice = .cancel
        let executor = MockUpdateExecutor()

        let coordinator = UpdateCoordinator(
            feedLoader: feedLoader,
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                architecture: .arm64
            ),
            capabilityEvaluator: MockCapabilityEvaluator(
                blockers: [.feedRequiresGuidedDownload]
            ),
            presenter: presenter,
            actionExecutor: executor
        )

        await coordinator.checkForUpdates(trigger: .manual)

        XCTAssertEqual(feedLoader.loadCount, 1)
        XCTAssertEqual(presenter.promptedTriggers, [.manual])
        XCTAssertTrue(executor.executed.isEmpty)
        XCTAssertEqual(coordinator.pendingAvailability?.release.version, "1.1.6")

        guard case let .updateAvailable(availability) = coordinator.state else {
            return XCTFail("Expected updateAvailable state")
        }
        XCTAssertEqual(availability.release.version, "1.1.6")
    }

    func testToolbarActionReusesPendingUpdateWithoutRefetching() async {
        let feedLoader = MockFeedLoader(feed: self.makeFeed(version: "1.1.6"))
        let presenter = MockUpdatePresenter()
        let executor = MockUpdateExecutor()

        let coordinator = UpdateCoordinator(
            feedLoader: feedLoader,
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                architecture: .arm64
            ),
            capabilityEvaluator: MockCapabilityEvaluator(
                blockers: [.feedRequiresGuidedDownload]
            ),
            presenter: presenter,
            actionExecutor: executor
        )

        presenter.nextChoice = .cancel
        await coordinator.checkForUpdates(trigger: .automaticStartup)
        feedLoader.feed = self.makeFeed(version: "1.1.5")
        presenter.nextChoice = .install

        await coordinator.handleToolbarAction()

        XCTAssertEqual(feedLoader.loadCount, 2)
        XCTAssertEqual(presenter.promptedTriggers, [.automaticStartup])
        XCTAssertEqual(executor.executed.count, 0)
        XCTAssertEqual(presenter.upToDateMessages.count, 1)
        XCTAssertNil(coordinator.pendingAvailability)
    }

    func testAutomaticAndManualChecksUseSameFeedResolution() async {
        let feedLoader = MockFeedLoader(feed: self.makeFeed(version: "1.1.6"))
        let presenter = MockUpdatePresenter()

        let coordinator = UpdateCoordinator(
            feedLoader: feedLoader,
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                architecture: .x86_64
            ),
            capabilityEvaluator: MockCapabilityEvaluator(
                blockers: [.feedRequiresGuidedDownload]
            ),
            presenter: presenter,
            actionExecutor: MockUpdateExecutor()
        )

        presenter.nextChoice = .cancel
        await coordinator.checkForUpdates(trigger: .automaticStartup)
        await coordinator.checkForUpdates(trigger: .manual)

        XCTAssertEqual(feedLoader.loadCount, 2)
        XCTAssertEqual(presenter.promptedTriggers, [.automaticStartup, .manual])
        XCTAssertEqual(presenter.promptedVersions, ["1.1.6", "1.1.6"])
        XCTAssertEqual(coordinator.pendingAvailability?.selectedArtifact.architecture, .x86_64)
    }

    func testManualCheckShowsUpToDateMessageWhenVersionsMatch() async {
        let presenter = MockUpdatePresenter()
        let coordinator = UpdateCoordinator(
            feedLoader: MockFeedLoader(feed: self.makeFeed(version: "1.1.5")),
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                architecture: .arm64
            ),
            capabilityEvaluator: MockCapabilityEvaluator(blockers: []),
            presenter: presenter,
            actionExecutor: MockUpdateExecutor()
        )

        await coordinator.checkForUpdates(trigger: .manual)

        XCTAssertEqual(presenter.upToDateMessages.count, 1)
        XCTAssertEqual(presenter.upToDateMessages.first?.0, "1.1.5")
        XCTAssertEqual(presenter.upToDateMessages.first?.1, "1.1.5")
        XCTAssertNil(coordinator.pendingAvailability)
        guard case let .upToDate(currentVersion, checkedVersion) = coordinator.state else {
            return XCTFail("Expected upToDate state")
        }
        XCTAssertEqual(currentVersion, "1.1.5")
        XCTAssertEqual(checkedVersion, "1.1.5")
    }

    func testCoordinatorFailsWhenCompatibleArtifactIsMissing() async {
        let presenter = MockUpdatePresenter()
        let feed = self.makeFeed(
            version: "1.1.6",
            artifacts: [
                AppUpdateArtifact(
                    architecture: .x86_64,
                    format: .dmg,
                    downloadURL: URL(string: "https://example.com/intel.dmg")!,
                    sha256: nil
                )
            ]
        )

        let coordinator = UpdateCoordinator(
            feedLoader: MockFeedLoader(feed: feed),
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                architecture: .arm64
            ),
            capabilityEvaluator: MockCapabilityEvaluator(blockers: []),
            presenter: presenter,
            actionExecutor: MockUpdateExecutor()
        )

        await coordinator.checkForUpdates(trigger: .manual)

        XCTAssertEqual(
            presenter.failures,
            [L.updateErrorNoCompatibleArtifact("Apple Silicon")]
        )
        guard case let .failed(message) = coordinator.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertEqual(message, L.updateErrorNoCompatibleArtifact("Apple Silicon"))
    }

    func testArtifactSelectorPrefersArmThenUniversal() throws {
        let artifact = try AppUpdateArtifactSelector.selectArtifact(
            for: .arm64,
            artifacts: [
                AppUpdateArtifact(
                    architecture: .universal,
                    format: .dmg,
                    downloadURL: URL(string: "https://example.com/universal.dmg")!,
                    sha256: nil
                ),
                AppUpdateArtifact(
                    architecture: .arm64,
                    format: .zip,
                    downloadURL: URL(string: "https://example.com/arm.zip")!,
                    sha256: nil
                ),
            ]
        )

        XCTAssertEqual(artifact.architecture, .universal)
        XCTAssertEqual(artifact.format, .dmg)
    }

    func testArtifactSelectorPrefersIntelSpecificBuild() throws {
        let artifact = try AppUpdateArtifactSelector.selectArtifact(
            for: .x86_64,
            artifacts: [
                AppUpdateArtifact(
                    architecture: .universal,
                    format: .zip,
                    downloadURL: URL(string: "https://example.com/universal.zip")!,
                    sha256: nil
                ),
                AppUpdateArtifact(
                    architecture: .x86_64,
                    format: .dmg,
                    downloadURL: URL(string: "https://example.com/intel.dmg")!,
                    sha256: nil
                ),
            ]
        )

        XCTAssertEqual(artifact.architecture, .x86_64)
        XCTAssertEqual(artifact.format, .dmg)
    }

    func testBootstrapGateKeeps115InGuidedMode() {
        let evaluator = DefaultAppUpdateCapabilityEvaluator(
            signatureInspector: MockSignatureInspector(
                inspection: AppSignatureInspection(
                    hasUsableSignature: true,
                    summary: "Signature=Developer ID; TeamIdentifier=TEAMID"
                )
            ),
            gatekeeperInspector: MockGatekeeperInspector(
                inspection: AppGatekeeperInspection(
                    passesAssessment: true,
                    summary: "accepted | source=Developer ID"
                )
            ),
            automaticUpdaterAvailable: true
        )

        let blockers = evaluator.blockers(
            for: AppUpdateRelease(
                version: "1.1.6",
                publishedAt: nil,
                summary: nil,
                releaseNotesURL: URL(string: "https://example.com/release-notes")!,
                downloadPageURL: URL(string: "https://example.com/download")!,
                deliveryMode: .automatic,
                minimumAutomaticUpdateVersion: "1.1.6",
                artifacts: []
            ),
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                bundleURL: URL(fileURLWithPath: "/Applications/codexbar.app"),
                architecture: .arm64
            )
        )

        XCTAssertEqual(
            blockers,
            [
                .bootstrapRequired(
                    currentVersion: "1.1.5",
                    minimumAutomaticVersion: "1.1.6"
                )
            ]
        )
    }

    func testPhase0GateIncludesGatekeeperAssessmentBlocker() {
        let evaluator = DefaultAppUpdateCapabilityEvaluator(
            signatureInspector: MockSignatureInspector(
                inspection: AppSignatureInspection(
                    hasUsableSignature: true,
                    summary: "Signature=Developer ID; TeamIdentifier=TEAMID"
                )
            ),
            gatekeeperInspector: MockGatekeeperInspector(
                inspection: AppGatekeeperInspection(
                    passesAssessment: false,
                    summary: "accepted | source=no usable signature"
                )
            ),
            automaticUpdaterAvailable: true
        )

        let blockers = evaluator.blockers(
            for: AppUpdateRelease(
                version: "1.1.6",
                publishedAt: nil,
                summary: nil,
                releaseNotesURL: URL(string: "https://example.com/release-notes")!,
                downloadPageURL: URL(string: "https://example.com/download")!,
                deliveryMode: .automatic,
                minimumAutomaticUpdateVersion: "1.1.5",
                artifacts: []
            ),
            environment: MockUpdateEnvironment(
                currentVersion: "1.1.5",
                bundleURL: URL(fileURLWithPath: "/Applications/codexbar.app"),
                architecture: .arm64
            )
        )

        XCTAssertEqual(
            blockers,
            [.failingGatekeeperAssessment(summary: "accepted | source=no usable signature")]
        )
    }

    private func makeFeed(
        version: String,
        artifacts: [AppUpdateArtifact]? = nil
    ) -> AppUpdateFeed {
        AppUpdateFeed(
            schemaVersion: 1,
            channel: "stable",
            release: AppUpdateRelease(
                version: version,
                publishedAt: nil,
                summary: "Guided release",
                releaseNotesURL: URL(string: "https://example.com/release-notes")!,
                downloadPageURL: URL(string: "https://example.com/download")!,
                deliveryMode: .guidedDownload,
                minimumAutomaticUpdateVersion: "1.1.6",
                artifacts: artifacts ?? [
                    AppUpdateArtifact(
                        architecture: .arm64,
                        format: .dmg,
                        downloadURL: URL(string: "https://example.com/arm.dmg")!,
                        sha256: nil
                    ),
                    AppUpdateArtifact(
                        architecture: .x86_64,
                        format: .dmg,
                        downloadURL: URL(string: "https://example.com/intel.dmg")!,
                        sha256: nil
                    ),
                ]
            )
        )
    }
}

private final class MockFeedLoader: AppUpdateFeedLoading {
    var feed: AppUpdateFeed
    var loadCount = 0

    init(feed: AppUpdateFeed) {
        self.feed = feed
    }

    func loadFeed() async throws -> AppUpdateFeed {
        self.loadCount += 1
        return self.feed
    }
}

private struct MockUpdateEnvironment: AppUpdateEnvironmentProviding {
    var currentVersion: String
    var bundleURL: URL = URL(fileURLWithPath: "/Applications/codexbar.app")
    var architecture: UpdateArtifactArchitecture
    var feedURL: URL? = URL(string: "https://example.com/stable.json")
}

private struct MockCapabilityEvaluator: AppUpdateCapabilityEvaluating {
    var blockers: [AppUpdateBlocker]

    func blockers(
        for release: AppUpdateRelease,
        environment: AppUpdateEnvironmentProviding
    ) -> [AppUpdateBlocker] {
        self.blockers
    }
}

private final class MockUpdatePresenter: AppUpdatePresenting {
    var nextChoice: AppUpdatePromptChoice = .cancel
    var promptedTriggers: [UpdateCheckTrigger] = []
    var promptedVersions: [String] = []
    var upToDateMessages: [(String, String)] = []
    var failures: [String] = []
    var guidedDownloadPresentedVersions: [String] = []

    func promptForAvailableUpdate(
        _ availability: AppUpdateAvailability,
        trigger: UpdateCheckTrigger
    ) -> AppUpdatePromptChoice {
        self.promptedTriggers.append(trigger)
        self.promptedVersions.append(availability.release.version)
        return self.nextChoice
    }

    func showUpToDate(
        currentVersion: String,
        checkedVersion: String
    ) {
        self.upToDateMessages.append((currentVersion, checkedVersion))
    }

    func showFailure(
        _ message: String,
        trigger: UpdateCheckTrigger
    ) {
        self.failures.append(message)
    }

    func showGuidedDownloadStarted(_ availability: AppUpdateAvailability) {
        self.guidedDownloadPresentedVersions.append(availability.release.version)
    }
}

private final class MockUpdateExecutor: AppUpdateActionExecuting {
    var executed: [AppUpdateAvailability] = []
    var error: Error?

    func execute(_ availability: AppUpdateAvailability) async throws {
        if let error {
            throw error
        }
        self.executed.append(availability)
    }
}

private struct MockSignatureInspector: AppSignatureInspecting {
    var inspection: AppSignatureInspection

    func inspect(bundleURL: URL) -> AppSignatureInspection {
        self.inspection
    }
}

private struct MockGatekeeperInspector: AppGatekeeperInspecting {
    var inspection: AppGatekeeperInspection

    func inspect(bundleURL: URL) -> AppGatekeeperInspection {
        self.inspection
    }
}
