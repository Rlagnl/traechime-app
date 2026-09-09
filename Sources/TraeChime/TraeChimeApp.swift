import SwiftUI
import AppKit
import Combine

@main
struct TraeChimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore!
    private var registry: AgentRegistry!
    private var sound: SoundService!
    private var menuBar: MenuBarController!
    private var panel: PanelController!
    private var settingsWindow: SettingsWindowController!
    private var eventServer: EventServer!
    private var onboarding: OnboardingWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceObserver: NSObjectProtocol?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 尽早隐藏 Dock 图标，避免启动瞬间闪烁
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = SettingsStore()
        registry = AgentRegistry()
        sound = SoundService(settings: settings)
        menuBar = MenuBarController()
        panel = PanelController(registry: registry, settings: settings)
        settingsWindow = SettingsWindowController(settings: settings, sound: sound)
        eventServer = EventServer(registry: registry, settings: settings)

        panel.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        panel.onQuit = { NSApp.terminate(nil) }

        menuBar.onClick = { [weak self] in
            self?.panel.toggle(relativeTo: self?.menuBar.statusButton)
        }

        // 聚合状态 → 菜单栏动画 + 提示音
        registry.$aggregateState
            .removeDuplicates()
            .sink { [weak self] state in
                self?.menuBar.setState(state)
                self?.sound.considerPlaying(for: state)
            }
            .store(in: &cancellables)

        // 端口变更即时重启服务
        settings.$port
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] port in
                self?.eventServer.start(port: port)
            }
            .store(in: &cancellables)

        // 启动事件服务
        eventServer.start(port: settings.port)

        // 监听应用焦点切换：切回 Trae 系应用时自动清除「已完成」状态
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.handleApplicationActivation(app)
        }

        // 首次启动引导（未接入且未展示过引导时弹出一次）
        showOnboardingIfNeeded()
    }

    /// 应用获得焦点时回调：若为 Trae 系应用则自动清除对应来源的「已完成」状态
    private func handleApplicationActivation(_ app: NSRunningApplication) {
        let bundle = (app.bundleIdentifier ?? "").lowercased()
        let name = (app.localizedName ?? "").lowercased()
        // 排除 TraeChime 自身，只对 Trae 系应用（TraeCode/TraeWork/Trae SOLO 等）生效
        guard bundle != "com.traechime.app" else { return }
        guard name.contains("trae") || bundle.contains("trae") else { return }
        // 含 work 的归为 TraeWork，其余归为 TraeCode，按来源分别清除「已完成」，互不干扰
        let source = (name.contains("work") || bundle.contains("work")) ? "traework" : "traecode"
        registry.autoDismissDone(source: source)
    }

    /// 首次启动引导：仅在未接入 Trae 且未展示过引导时弹出一次
    private func showOnboardingIfNeeded() {
        let key = "hasShownOnboarding"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        guard !HookInstaller.isInstalled() else { return }

        let controller = OnboardingWindowController(onFinish: { [weak self] in
            // 用户处理完引导（稍后 / 接入成功）后再标记，避免窗口未正常展示也误标记
            UserDefaults.standard.set(true, forKey: key)
            self?.onboarding = nil
        })
        onboarding = controller
        controller.show()
    }
}
