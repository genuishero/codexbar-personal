import Foundation

struct SwitchJournalStore {
    struct ActivationRecord: Equatable {
        let timestamp: Date
        let providerID: String?
        let accountID: String?
        let previousAccountID: String?
        let reason: AutoRoutingSwitchReason
        let automatic: Bool
        let forced: Bool
        let protectedByManualGrace: Bool
    }

    private let customFileURL: URL?
    private let fileManager: FileManager
    private let dateFormatter: ISO8601DateFormatter

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        dateFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) {
        self.customFileURL = fileURL
        self.fileManager = fileManager
        self.dateFormatter = dateFormatter
    }

    func appendActivation(
        providerID: String?,
        accountID: String?,
        previousAccountID: String? = nil,
        reason: AutoRoutingSwitchReason = .manual,
        automatic: Bool = false,
        forced: Bool = false,
        protectedByManualGrace: Bool = false,
        timestamp: Date = Date()
    ) throws {
        let entry: [String: Any] = [
            "timestamp": self.dateFormatter.string(from: timestamp),
            "providerId": providerID as Any,
            "accountId": accountID as Any,
            "previousAccountId": previousAccountID as Any,
            "reason": reason.rawValue,
            "automatic": automatic,
            "forced": forced,
            "protectedByManualGrace": protectedByManualGrace,
            "type": "activation",
        ]
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
        let line = (String(data: data, encoding: .utf8) ?? "{}") + "\n"
        let fileURL = self.resolvedFileURL

        try CodexPaths.ensureDirectories()
        try self.fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if self.fileManager.fileExists(atPath: fileURL.path) == false {
            try CodexPaths.writeSecureFile(Data(line.utf8), to: fileURL)
            return
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
    }

    func activationHistory() -> [ActivationRecord] {
        let fileURL = self.resolvedFileURL
        guard self.fileManager.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        return content
            .split(separator: "\n")
            .compactMap { self.parseActivationRecord(from: String($0)) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private func parseActivationRecord(from line: String) -> ActivationRecord? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["type"] as? String) == "activation",
              let timestampString = object["timestamp"] as? String,
              let timestamp = ISO8601Parsing.parse(timestampString) else {
            return nil
        }

        let reasonRawValue = object["reason"] as? String ?? AutoRoutingSwitchReason.manual.rawValue
        let reason = AutoRoutingSwitchReason(rawValue: reasonRawValue) ?? .manual
        let automatic = object["automatic"] as? Bool ?? reason.isAutomatic

        return ActivationRecord(
            timestamp: timestamp,
            providerID: object["providerId"] as? String,
            accountID: object["accountId"] as? String,
            previousAccountID: object["previousAccountId"] as? String,
            reason: reason,
            automatic: automatic,
            forced: object["forced"] as? Bool ?? reason.isForced,
            protectedByManualGrace: object["protectedByManualGrace"] as? Bool ?? false
        )
    }

    private var resolvedFileURL: URL {
        self.customFileURL ?? CodexPaths.switchJournalURL
    }
}
