import Foundation
import SwiftUI

/// 快速开始协调器 - 管理快速开始引导的显示
final class QuickStartCoordinator {
    static let shared = QuickStartCoordinator()

    private var quickStartWindow: NSWindow?

    private init() {}

    @MainActor
    func showQuickStart() {
        guard quickStartWindow == nil else { return }

        let contentView = QuickStartView()
        let hostingView = NSHostingView(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = L.quickStartTitle
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        quickStartWindow = window
    }

    @MainActor
    func closeQuickStart() {
        quickStartWindow?.close()
        quickStartWindow = nil
    }
}