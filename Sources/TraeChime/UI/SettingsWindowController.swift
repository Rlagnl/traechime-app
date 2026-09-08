import AppKit
import SwiftUI

/// 设置窗口控制器
final class SettingsWindowController {
    private let window: NSWindow

    init(settings: SettingsStore, sound: SoundService) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, sound: sound))
        window = NSWindow(contentViewController: hosting)
        window.title = "TraeChime 设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 460, height: 520))
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
