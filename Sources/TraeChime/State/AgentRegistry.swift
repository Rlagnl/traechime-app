import Foundation
import Combine

/// 聚合状态管理器：维护所有 agent 的注册表，计算菜单栏聚合状态与计数
final class AgentRegistry: ObservableObject {
    @Published private(set) var aggregateState: ChimeState = .idle
    @Published private(set) var attentionCount: Int = 0
    @Published private(set) var runningCount: Int = 0
    @Published private(set) var records: [AgentRecord] = []

    private var byID: [String: AgentRecord] = [:]

    /// 应用一条来自 Trae 侧的事件（同一 agent_id 的新事件覆盖旧状态）
    func apply(_ event: AgentEvent) {
        let now = Date()
        var record = byID[event.agentId] ?? AgentRecord(
            id: event.agentId,
            source: event.source,
            title: event.taskTitle,
            status: .running,
            startedAt: now,
            lastEventAt: now
        )
        record.source = event.source
        record.title = event.taskTitle
        record.lastEventAt = now

        switch event.event {
        case .started:        record.status = .running
        case .completed:      record.status = .attention(.done)
        case .confirmRequired: record.status = .attention(.confirm)
        case .failed:         record.status = .attention(.error)
        case .resumed:        record.status = .running
        }

        byID[event.agentId] = record
        recompute()
    }

    /// 用户处理完某条 attention 记录，回到空闲（从注册表移除）
    func dismiss(_ id: String) {
        byID.removeValue(forKey: id)
        recompute()
    }

    /// 来源应用重新获得焦点时，自动清除该来源的「已完成」记录（无需用户手动处理）
    func autoDismissDone(source: String) {
        let doneIDs = byID.compactMap { id, record -> String? in
            if case .attention(.done) = record.status, record.source == source { return id }
            return nil
        }
        guard !doneIDs.isEmpty else { return }
        for id in doneIDs { byID.removeValue(forKey: id) }
        recompute()
    }

    /// 一键清除所有活跃 agent
    func clearAll() {
        byID.removeAll()
        recompute()
    }

    private func recompute() {
        records = byID.values.sorted { a, b in
            if a.status.priority != b.status.priority {
                return a.status.priority > b.status.priority
            }
            return a.lastEventAt > b.lastEventAt
        }

        attentionCount = records.reduce(0) { count, r in
            if case .attention = r.status { return count + 1 }
            return count
        }
        runningCount = records.reduce(0) { count, r in
            if case .running = r.status { return count + 1 }
            return count
        }

        // 排序后 records.first 即最高优先级；有 attention 时优先于 running
        if let top = records.first {
            switch top.status {
            case .attention(let kind): aggregateState = .attention(kind)
            case .running:             aggregateState = .running
            }
        } else {
            aggregateState = .idle
        }
    }
}
