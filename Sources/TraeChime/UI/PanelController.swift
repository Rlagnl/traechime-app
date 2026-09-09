import AppKit
import SwiftUI

/// 下拉面板控制器：NSPopover 内嵌 SwiftUI 视图
final class PanelController {
    private let popover = NSPopover()
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    init(registry: AgentRegistry, settings: SettingsStore) {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: PanelView(
                registry: registry,
                settings: settings,
                onOpenSettings: { [weak self] in self?.onOpenSettings?() },
                onQuit: { [weak self] in self?.onQuit?() }
            )
        )
    }

    func toggle(relativeTo button: NSStatusBarButton?) {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
