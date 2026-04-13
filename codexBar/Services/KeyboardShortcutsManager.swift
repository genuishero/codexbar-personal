import Foundation
import Combine

/// 快捷键管理器（简化版）
final class KeyboardShortcutsManager: ObservableObject {
    static let shared = KeyboardShortcutsManager()

    @Published var enabled: Bool = true
    @Published var shortcuts: [Int: String] = [:]

    private init() {}

    func startListening() {}
    func stopListening() {}
    func updateShortcuts() {}
}