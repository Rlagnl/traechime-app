import SwiftUI
import AppKit

/// 首次启动引导：引导用户一键接入 Trae
struct OnboardingView: View {
    var onFinish: () -> Void   // 「稍后」或接入成功后回调，关闭引导

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            steps
            footer
        }
        .padding(24)
        .frame(width: 440, height: 380)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let logo = PanelView.logoImage() {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("欢迎使用 TraeChime")
                .font(.title2.bold())
            Text("接入 Trae 后，菜单栏图标会随 AI Agent 的任务状态自动变化：执行中轻摆，完成或需确认时放大晃动并伴有提示音。")
                .foregroundStyle(.secondary)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            step("1", "点击「一键接入」，自动写入 Hook 配置")
            step("2", "重启 Trae，在「设置 → Hooks」打开全局 Hook 开关")
            step("3", "完成，开始使用")
        }
    }

    private func step(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(num)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.green.opacity(0.15)))
            Text(text)
                .font(.callout)
        }
    }

    private var footer: some View {
        HStack {
            Button("稍后再说") { onFinish() }
            Spacer()
            Button("一键接入") { install() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }

    private func install() {
        do {
            try HookInstaller.install()
            let alert = NSAlert()
            alert.messageText = "接入成功"
            alert.informativeText = "已写入 Hook 配置。请重启 Trae，并在「设置 → Hooks」中打开全局 Hook 开关。"
            alert.alertStyle = .informational
            alert.runModal()
            onFinish()
        } catch {
            let alert = NSAlert()
            alert.messageText = "接入失败"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
