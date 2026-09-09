import SwiftUI
import AppKit
import ServiceManagement

/// 可选系统音效名称
private let systemSoundNames = [
    "Glass", "Ping", "Basso", "Pop", "Purr",
    "Sosumi", "Submarine", "Tink", "Funk", "Blow"
]

/// 设置界面
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let sound: SoundService

    @State private var portText: String = ""
    @State private var hookStatusText = "未接入"

    var body: some View {
        Form {
            Section("Trae 接入") {
                HStack {
                    Text(hookStatusText)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("一键接入") { installHook() }
                }
                Text("接入后需重启 Trae，并在其「设置 → Hooks」中打开全局 Hook 开关")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("提示音") {
                Toggle("开启提示音", isOn: $settings.soundEnabled)
                soundPicker("完成", selection: $settings.soundForDone, kind: .done)
                soundPicker("待确认", selection: $settings.soundForConfirm, kind: .confirm)
                soundPicker("异常", selection: $settings.soundForError, kind: .error)
            }

            Section("事件服务") {
                TextField("监听端口", text: $portText)
                    .onSubmit { applyPort() }
                    .onChange(of: portText) { _ in applyPort() }
                TextField("令牌（可选，留空不校验）", text: $settings.token)
            }

            Section("来源应用") {
                TextField("TraeCode Bundle ID", text: $settings.traeCodeBundleID)
                // TraeWork 个人版暂不支持 Hook，隐藏该配置项；等支持后再放出来
                // TextField("TraeWork Bundle ID", text: $settings.traeWorkBundleID)
            }

            Section("通用") {
                Toggle("开机自启", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        LoginItemManager.setEnabled(newValue)
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 600)
        .onAppear {
            portText = String(settings.port)
            refreshHookStatus()
        }
    }

    private func soundPicker(_ label: String, selection: Binding<String>, kind: AttentionKind) -> some View {
        HStack {
            Picker(label, selection: selection) {
                ForEach(systemSoundNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            Button("试听") { sound.preview(for: kind) }
        }
    }

    private func applyPort() {
        if let value = UInt16(portText.trimmingCharacters(in: .whitespaces)) {
            settings.port = value
        }
    }

    private func refreshHookStatus() {
        hookStatusText = HookInstaller.isInstalled() ? "已接入" : "未接入"
    }

    private func installHook() {
        do {
            try HookInstaller.install()
            hookStatusText = "已接入"
            let alert = NSAlert()
            alert.messageText = "接入成功"
            alert.informativeText = "已写入 Hook 配置。请重启 Trae，并在「设置 → Hooks」中打开全局 Hook 开关。"
            alert.alertStyle = .informational
            alert.runModal()
        } catch {
            hookStatusText = "接入失败"
            let alert = NSAlert()
            alert.messageText = "接入失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

/// 开机自启：SMAppService.mainApp（需 .app bundle + 稳定路径，失败静默忽略）
enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("开机自启设置失败: \(error)")
        }
    }
}
