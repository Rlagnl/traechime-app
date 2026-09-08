import Foundation

/// 单个 agent 在注册表中的运行态
enum AgentStatus {
    case running
    case attention(AttentionKind)

    /// 优先级：attention(error/confirm/done) > running
    var priority: Int {
        switch self {
        case .running:            return 0
        case .attention(let kind): return kind.priority
        }
    }
}

/// 单个 agent 的聚合记录
struct AgentRecord: Identifiable {
    let id: String
    var source: String
    var title: String
    var status: AgentStatus
    var startedAt: Date
    var lastEventAt: Date
}
