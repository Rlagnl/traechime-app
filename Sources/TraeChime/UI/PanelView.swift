import SwiftUI
import AppKit

/// 下拉面板：品牌区 + agent 卡片列表 + 底部操作区
struct PanelView: View {
    @ObservedObject var registry: AgentRegistry
    @ObservedObject var settings: SettingsStore
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if registry.records.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: 320)
    }

    // MARK: 品牌区

    private var header: some View {
        HStack(spacing: 10) {
            if let logo = Self.logoImage() {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("TraeChime")
                    .font(.headline)
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    private var summaryText: String {
        if registry.attentionCount == 0 && registry.runningCount == 0 {
            return "空闲中"
        }
        return "\(registry.attentionCount) 个待处理 · \(registry.runningCount) 个运行中"
    }

    // MARK: 空状态

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("暂无运行中的 Agent")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // MARK: 列表

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(registry.records) { record in
                    AgentRow(
                        record: record,
                        onDismiss: { registry.dismiss(record.id) },
                        onJump: { jump(to: record.source) }
                    )
                }
            }
            .padding(12)
        }
    }

    // MARK: 底部操作区

    private var footer: some View {
        HStack {
            Button("全部清除") { registry.clearAll() }
            Spacer()
            Button("设置") { onOpenSettings() }
            Button("退出") { onQuit() }
        }
        .padding(12)
    }

    // MARK: 跳转来源应用

    private func jump(to source: String) {
        let bundleID = source == "traecode" ? settings.traeCodeBundleID : settings.traeWorkBundleID
        if !bundleID.isEmpty, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        // 未配置 Bundle ID 时，按名称/Bundle ID 关键字激活已运行实例（兼容「TraeCode CN」等命名）
        let keyword = source == "traecode" ? "traecode" : "traework"
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(keyword)
                || ($0.bundleIdentifier ?? "").localizedCaseInsensitiveContains(keyword)
        }) {
            app.activate(options: [.activateAllWindows])
        }
    }

    static func logoImage() -> NSImage? {
        let candidates: [URL?] = [
            Bundle.module.url(forResource: "traechime-logo-chime-word-rounded-v3", withExtension: "jpg"),
            Bundle.main.url(forResource: "traechime-logo-chime-word-rounded-v3", withExtension: "jpg")
        ]
        for url in candidates {
            if let url = url, let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }
}

/// 单条 agent 状态卡片
private struct AgentRow: View {
    let record: AgentRecord
    var onDismiss: () -> Void
    var onJump: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 顶部：状态点 + 标题 + 来源标签
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                Text(record.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 来源标签暂隐藏：当前仅 TraeCode 一个来源，等 TraeWork 支持 Hook 后再展示
                // sourceBadge
            }

            // 元信息行：状态 + 耗时
            HStack(spacing: 6) {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(elapsedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 16)

            Divider()

            // 底部操作区：跳转居左（低饱和蓝底白字）、清除居右（低饱和红底白字）
            HStack(spacing: 8) {
                Button("跳转") { onJump() }
                    .tint(Color(red: 0.44, green: 0.56, blue: 0.68))
                Spacer()
                Button("清除") { onDismiss() }
                    .tint(Color(red: 0.73, green: 0.46, blue: 0.46))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // 暂隐藏的来源标签视图：等 TraeWork 支持 Hook 后，恢复 body 中的 sourceBadge 渲染即可
    private var sourceBadge: some View {
        Text(sourceLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(nsColor: .quaternaryLabelColor))
            .clipShape(Capsule())
    }

    private var sourceLabel: String {
        switch record.source {
        case "traecode": return "TraeCode"
        case "traework": return "TraeWork"
        default:         return record.source
        }
    }

    private var statusText: String {
        switch record.status {
        case .running:            return "执行中"
        case .attention(let kind): return kind.displayText
        }
    }

    private var statusColor: Color {
        switch record.status {
        case .running:
            return Color.gray
        case .attention(let kind):
            switch kind {
            case .done:    return .green
            case .confirm: return .orange
            case .error:   return .red
            }
        }
    }

    private var elapsedText: String {
        let interval = Int(Date().timeIntervalSince(record.startedAt))
        if interval < 60 { return "\(interval)s" }
        return "\(interval / 60)m\(interval % 60)s"
    }
}
