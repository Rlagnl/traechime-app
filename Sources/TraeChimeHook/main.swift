import Foundation
import CryptoKit

// TraeChime Hook 桥接（无依赖命令行工具）
// 作为 TraeCode 的 Hook 命令运行：从 stdin 读取 Hook 事件 JSON，
// 映射为 TraeChime 事件后 POST 到本机事件服务（http://127.0.0.1:PORT/v1/events）。
//
// 事件映射：
// - UserPromptSubmit                        -> started（开始执行，标题取用户 prompt）
// - Notification(idle_prompt)               -> completed
// - Notification(permission_prompt/document_review/ask_user_question/browser_interaction) -> confirm_required
// - Stop                                    -> completed（兜底）
//
// 说明：不向 stdout 输出任何内容、退出码恒为 0，因此不会注入上下文、也不会阻断智能体流程。

let env = ProcessInfo.processInfo.environment
let port = env["TRAECHIME_PORT"] ?? "17387"
let token = env["TRAECHIME_TOKEN"] ?? ""
let source = env["TRAECHIME_SOURCE"] ?? "traecode"
let baseURL = "http://127.0.0.1:\(port)/v1/events"

// 标题缓存放系统临时目录（沙箱可写），而非 ~/.traechime
let stateDir = URL(fileURLWithPath: env["TMPDIR"] ?? "/tmp", isDirectory: true)
    .appendingPathComponent("traechime", isDirectory: true)

// 读取 stdin 全部内容
let raw = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
guard !raw.isEmpty,
      let data = raw.data(using: .utf8),
      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    exit(0)
}

let eventName = obj["hook_event_name"] as? String ?? ""
let sessionID = obj["session_id"] as? String ?? "unknown"

// 标题缓存路径（session_id 哈希前 16 位 hex）
func statePath(_ id: String) -> URL {
    let digest = SHA256.hash(data: Data(id.utf8))
    let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    return stateDir.appendingPathComponent(hex + ".title")
}

func loadTitle(_ id: String) -> String {
    (try? String(contentsOf: statePath(id), encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func saveTitle(_ id: String, _ title: String) {
    try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
    try? title.write(to: statePath(id), atomically: true, encoding: .utf8)
}

// POST 事件到 TraeChime（失败静默忽略，避免影响智能体流程）
func post(_ body: [String: Any]) {
    guard let url = URL(string: baseURL) else { return }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-TraeChime-Token") }
    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
    req.timeoutInterval = 2

    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { _, _, _ in sem.signal() }.resume()
    _ = sem.wait(timeout: .now() + 2.5)
}

var event: String?
var title = ""

switch eventName {
case "UserPromptSubmit":
    title = String(((obj["prompt"] as? String) ?? "").prefix(40))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if !title.isEmpty { saveTitle(sessionID, title) }
    event = "started"

case "Notification":
    let ntype = obj["notification_type"] as? String ?? ""
    if ntype == "idle_prompt" {
        event = "completed"
    } else if ntype == "permission_prompt" || ntype == "document_review"
              || ntype == "ask_user_question" || ntype == "browser_interaction" {
        event = "confirm_required"
    }
    title = loadTitle(sessionID)
    if title.isEmpty { title = String(((obj["message"] as? String) ?? "").prefix(40)) }

case "PreToolUse":
    // agent 重新发起工具调用，说明已从「待确认」恢复执行
    event = "resumed"
    title = loadTitle(sessionID)
    if title.isEmpty { title = String(sessionID.prefix(12)) }

case "PostToolUse":
    // 被确认的工具执行完成，同样说明已从「待确认」恢复执行
    event = "resumed"
    title = loadTitle(sessionID)
    if title.isEmpty { title = String(sessionID.prefix(12)) }

case "Stop":
    event = "completed"
    title = loadTitle(sessionID)
    if title.isEmpty { title = String(((obj["last_assistant_message"] as? String) ?? "").prefix(40)) }

default:
    break
}

guard let event = event else { exit(0) }
if title.isEmpty { title = String(sessionID.prefix(12)) }

post([
    "source": source,
    "agent_id": sessionID,
    "task_title": title,
    "event": event
])
exit(0)
