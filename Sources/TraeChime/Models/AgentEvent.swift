import Foundation

/// Trae 侧推送的事件类型
enum AgentEventType: String, Codable {
    case started
    case completed
    case confirmRequired = "confirm_required"
    case failed
    case resumed        // 待确认处理完成后，agent 恢复执行
}

/// 本机事件服务接收的 agent 状态事件（对应需求文档「事件协议」）
struct AgentEvent: Codable {
    let source: String      // "traecode" | "traework"
    let agentId: String     // 同一 agent 会话内保持不变
    let taskTitle: String   // 用于面板展示
    let event: AgentEventType
    let timestamp: String?  // 可选，ISO8601，缺省以接收时间为准

    enum CodingKeys: String, CodingKey {
        case source
        case agentId = "agent_id"
        case taskTitle = "task_title"
        case event
        case timestamp
    }

    /// 必填字段校验：source / agentId / taskTitle 均非空
    var isValid: Bool {
        !source.isEmpty && !agentId.isEmpty && !taskTitle.isEmpty
    }
}
