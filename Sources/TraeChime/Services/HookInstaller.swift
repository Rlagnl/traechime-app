import Foundation

/// 负责把 TraeCode Hook 配置（~/.trae-cn/hooks.json）一键接入到 TraeChime
enum HookInstaller {

    /// 需要注册的 Hook 事件
    static let events = ["UserPromptSubmit", "Notification", "PreToolUse", "PostToolUse", "Stop"]

    /// 全局 Hook 配置文件路径
    static var hooksFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".trae-cn")
            .appendingPathComponent("hooks.json")
    }

    /// app 内置桥接二进制路径（若存在）
    static var hookBinaryPath: String? {
        guard let res = Bundle.main.resourceURL else { return nil }
        let bin = res.appendingPathComponent("traechime-hook").path
        return FileManager.default.isExecutableFile(atPath: bin) ? bin : nil
    }

    /// 是否已接入（三个事件都指向本应用的 hook 二进制）
    static func isInstalled() -> Bool {
        guard let data = try? Data(contentsOf: hooksFileURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = obj["hooks"] as? [String: Any] else {
            return false
        }
        for event in events {
            guard let groups = hooks[event] as? [[String: Any]] else { return false }
            let commands = groups
                .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
                .compactMap { $0["command"] as? String }
            if !commands.contains(where: { $0.contains("traechime-hook") }) {
                return false
            }
        }
        return true
    }

    /// 一键接入：合并写入 hooks.json（保留已有配置）
    static func install() throws {
        guard let binary = hookBinaryPath else {
            throw InstallError.hookBinaryMissing
        }
        // 路径加引号，避免含空格时被 shell 拆开
        let command = "\"\(binary)\""

        // 读取已有配置（可能不存在）
        var root: [String: Any]
        if let data = try? Data(contentsOf: hooksFileURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
        } else {
            root = ["version": 1, "hooks": [String: Any]()]
        }
        var hooks = (root["hooks"] as? [String: Any]) ?? [String: Any]()

        for event in events {
            var groups = (hooks[event] as? [[String: Any]]) ?? []
            // 若已包含本应用的 hook，跳过，避免重复写入
            let already = groups.contains { group in
                let cmds = (group["hooks"] as? [[String: Any]]) ?? []
                return cmds.contains { ($0["command"] as? String)?.contains("traechime-hook") == true }
            }
            if !already {
                let group: [String: Any] = [
                    "hooks": [
                        ["type": "command", "command": command, "timeout": 5]
                    ]
                ]
                groups.append(group)
                hooks[event] = groups
            }
        }

        root["hooks"] = hooks
        if root["version"] == nil { root["version"] = 1 }

        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
        try FileManager.default.createDirectory(
            at: hooksFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: hooksFileURL, options: .atomic)
    }

    enum InstallError: LocalizedError {
        case hookBinaryMissing
        var errorDescription: String? {
            switch self {
            case .hookBinaryMissing: return "未找到内置桥接程序（traechime-hook），请重新构建应用"
            }
        }
    }
}
