import AppKit
import SwiftUI

/// 首次启动引导窗口控制器
final class OnboardingWindowController {
    private let window: NSWindow
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        // 先创建窗口，再构建 SwiftUI 视图（闭包需在 self 完全初始化后捕获）
        self.window = NSWindow()
        let hosting = NSHostingController(
            rootView: OnboardingView(onFinish: { [weak self] in self?.finish() })
        )
        window.contentViewController = hosting
        window.title = "TraeChime"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 440, height: 380))
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish() {
        window.close()
        onFinish()
    }
}
