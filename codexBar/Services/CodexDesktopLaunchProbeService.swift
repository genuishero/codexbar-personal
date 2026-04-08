import AppKit
import Foundation

@MainActor
private func defaultCodexDesktopAppLocator() -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
        return url
    }

    let fallback = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)
    guard FileManager.default.fileExists(atPath: fallback.path) else { return nil }
    return fallback
}

@MainActor
private func defaultCodexDesktopLauncher(appURL: URL, environment: [String: String]) async throws -> NSRunningApplication? {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = true
    configuration.environment = environment
    do {
        return try await withThrowingTaskGroup(of: NSRunningApplication?.self) { group in
            group.addTask {
                try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw CodexDesktopLaunchProbeError.launchTimedOut
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw CodexDesktopLaunchProbeError.launchTimedOut
            }
            return result
        }
    } catch let error as CodexDesktopLaunchProbeError {
        throw error
    } catch {
        throw CodexDesktopLaunchProbeError.launchFailed(error.localizedDescription)
    }
}

struct CodexDesktopLaunchProbeState: Codable, Equatable {
    let runID: String
    let launchedAt: Date
}

struct CodexDesktopLaunchProbeHit: Codable, Equatable {
    let runID: String
    let recordedAt: Date
    let argc: Int
}

enum CodexDesktopLaunchProbeError: LocalizedError {
    case codexAppNotFound
    case bundledCodexExecutableMissing
    case launchTimedOut
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .codexAppNotFound:
            return L.codexLaunchProbeAppNotFound
        case .bundledCodexExecutableMissing:
            return L.codexLaunchProbeExecutableMissing
        case .launchTimedOut:
            return L.codexLaunchProbeTimedOut
        case .launchFailed(let message):
            return L.codexLaunchProbeFailed(message)
        }
    }
}

@MainActor
final class CodexDesktopLaunchProbeService {
    static let shared = CodexDesktopLaunchProbeService()

    typealias AppLocator = @MainActor () -> URL?
    typealias Launcher = @MainActor (_ appURL: URL, _ environment: [String: String]) async throws -> NSRunningApplication?

    private let locateCodexApp: AppLocator
    private let launchApp: Launcher
    private let fileManager: FileManager
    private let environment: [String: String]
    private let now: () -> Date
    private let makeUUID: () -> UUID

    init(
        locateCodexApp: @escaping AppLocator = defaultCodexDesktopAppLocator,
        launchApp: @escaping Launcher = defaultCodexDesktopLauncher,
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        now: @escaping () -> Date = Date.init,
        makeUUID: @escaping () -> UUID = UUID.init
    ) {
        self.locateCodexApp = locateCodexApp
        self.launchApp = launchApp
        self.fileManager = fileManager
        self.environment = environment
        self.now = now
        self.makeUUID = makeUUID
    }

    func launchProbe() async throws -> CodexDesktopLaunchProbeState {
        guard let appURL = self.locateCodexApp() else {
            throw CodexDesktopLaunchProbeError.codexAppNotFound
        }

        let codexExecutableURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("codex")

        guard self.fileManager.fileExists(atPath: codexExecutableURL.path) else {
            throw CodexDesktopLaunchProbeError.bundledCodexExecutableMissing
        }

        try CodexPaths.ensureDirectories()

        let runID = self.makeUUID().uuidString.lowercased()
        let state = CodexDesktopLaunchProbeState(
            runID: runID,
            launchedAt: self.now()
        )

        let wrapperURL = CodexPaths.managedLaunchBinURL.appendingPathComponent("codex")
        try self.writeWrapper(
            to: wrapperURL,
            originalCodexExecutableURL: codexExecutableURL
        )
        try self.writeState(state)

        var launchEnvironment = self.environment
        let currentPATH = launchEnvironment["PATH"] ?? ""
        let prefixedPATH = currentPATH.isEmpty
            ? CodexPaths.managedLaunchBinURL.path
            : CodexPaths.managedLaunchBinURL.path + ":" + currentPATH
        launchEnvironment["PATH"] = prefixedPATH
        launchEnvironment["CODEXBAR_DESKTOP_PROBE_RUN_ID"] = runID
        launchEnvironment["CODEXBAR_DESKTOP_PROBE_HITS_DIR"] = CodexPaths.managedLaunchHitsURL.path

        _ = try await self.launchApp(appURL, launchEnvironment)
        return state
    }

    func launchNewInstance() async throws -> NSRunningApplication? {
        guard let appURL = self.locateCodexApp() else {
            throw CodexDesktopLaunchProbeError.codexAppNotFound
        }

        var launchEnvironment = self.environment
        launchEnvironment.removeValue(forKey: "CODEXBAR_DESKTOP_PROBE_RUN_ID")
        launchEnvironment.removeValue(forKey: "CODEXBAR_DESKTOP_PROBE_HITS_DIR")

        return try await self.launchApp(appURL, launchEnvironment)
    }

    func runningCodexApplications() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
    }

    func terminateApplications(withProcessIdentifiers processIdentifiers: Set<pid_t>) {
        guard processIdentifiers.isEmpty == false else { return }

        for application in self.runningCodexApplications()
        where processIdentifiers.contains(application.processIdentifier) {
            if application.terminate() == false {
                _ = application.forceTerminate()
            }
        }
    }

    func latestLaunchState() -> CodexDesktopLaunchProbeState? {
        guard let data = try? Data(contentsOf: CodexPaths.managedLaunchStateURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CodexDesktopLaunchProbeState.self, from: data)
    }

    func latestHit() -> CodexDesktopLaunchProbeHit? {
        guard let urls = try? self.fileManager.contentsOfDirectory(
            at: CodexPaths.managedLaunchHitsURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let sorted = urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        for url in sorted where url.pathExtension == "json" {
            if let hit = self.readHit(at: url) {
                return hit
            }
        }

        return nil
    }

    func hit(for runID: String) -> CodexDesktopLaunchProbeHit? {
        let url = CodexPaths.managedLaunchHitsURL.appendingPathComponent("\(runID).json")
        return self.readHit(at: url)
    }

    private func readHit(at url: URL) -> CodexDesktopLaunchProbeHit? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CodexDesktopLaunchProbeHit.self, from: data)
    }

    private func writeState(_ state: CodexDesktopLaunchProbeState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try CodexPaths.writeSecureFile(data, to: CodexPaths.managedLaunchStateURL)
    }

    private func writeWrapper(
        to wrapperURL: URL,
        originalCodexExecutableURL: URL
    ) throws {
        let hitsDirectory = self.shellSingleQuoted(CodexPaths.managedLaunchHitsURL.path)
        let originalExecutable = self.shellSingleQuoted(originalCodexExecutableURL.path)
        let script = """
        #!/bin/sh
        set -eu
        HITS_DIR="${CODEXBAR_DESKTOP_PROBE_HITS_DIR:-}"
        if [ -z "$HITS_DIR" ]; then
          HITS_DIR=\(hitsDirectory)
        fi
        RUN_ID="${CODEXBAR_DESKTOP_PROBE_RUN_ID:-unknown}"
        mkdir -p "$HITS_DIR"
        RECORDED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        cat > "$HITS_DIR/$RUN_ID.json" <<EOF
        {"runID":"$RUN_ID","recordedAt":"$RECORDED_AT","argc":$#}
        EOF
        exec \(originalExecutable) "$@"
        """

        try self.fileManager.createDirectory(
            at: wrapperURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(script.utf8).write(to: wrapperURL, options: .atomic)
        try self.fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: wrapperURL.path
        )
    }

    private func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}
