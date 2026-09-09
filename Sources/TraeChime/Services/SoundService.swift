import AppKit

/// 提示音服务：按事件类型播放系统音效，带升级判定与防抖
final class SoundService {
    private let settings: SettingsStore
    private var previousPriority: Int = -1
    private var lastPlayedAt: Date?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// 聚合状态变化时调用：仅在 attention 优先级上升或同级超过 2s 时播放
    func considerPlaying(for state: ChimeState) {
        guard settings.soundEnabled else {
            previousPriority = -1
            return
        }
        let newPriority = priority(of: state)
        let upgraded = newPriority > previousPriority
        previousPriority = newPriority

        guard case .attention(let kind) = state else { return }

        let now = Date()
        if upgraded {
            lastPlayedAt = now
            play(kind)
        } else if let last = lastPlayedAt, now.timeIntervalSince(last) >= 2 {
            lastPlayedAt = now
            play(kind)
        }
    }

    /// 设置界面中的试听
    func preview(for kind: AttentionKind) {
        play(kind)
    }

    private func priority(of state: ChimeState) -> Int {
        switch state {
        case .idle:               return -1
        case .running:            return 0
        case .attention(let kind): return kind.priority
        }
    }

    private func play(_ kind: AttentionKind) {
        let name: String
        switch kind {
        case .done:    name = settings.soundForDone
        case .confirm: name = settings.soundForConfirm
        case .error:   name = settings.soundForError
        }
        guard !name.isEmpty else { return }
        NSSound(named: name)?.play()
    }
}
