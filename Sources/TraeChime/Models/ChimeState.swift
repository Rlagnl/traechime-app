import AppKit

/// 菜单栏图标的三种聚合状态
enum ChimeState: Equatable {
    case idle                         // 空闲：铃铛静止
    case running                      // 执行中：铃铛 + 声波，缓慢轻摆
    case attention(AttentionKind)     // 需要注意：放大 + 急晃 + 彩色呼吸点
}

/// 「需要注意」的三种语义，决定右上角点的颜色与优先级
enum AttentionKind: Int, Equatable {
    case done = 1      // 任务完成 → 绿
    case confirm = 2   // 等待人工确认 → 橙
    case error = 3     // 执行异常 → 红

    /// 聚合优先级，数值越大越优先
    var priority: Int { rawValue }

    /// 对应系统语义色，深浅色模式下自动保证对比度
    var dotColor: NSColor {
        switch self {
        case .done:    return .systemGreen
        case .confirm: return .systemOrange
        case .error:   return .systemRed
        }
    }

    /// 无障碍描述，供 VoiceOver 读出当前状态
    var accessibilityLabel: String {
        switch self {
        case .done:    return "任务已完成"
        case .confirm: return "等待人工确认"
        case .error:   return "任务执行异常"
        }
    }

    /// 面板中展示的短文案
    var displayText: String {
        switch self {
        case .done:    return "已完成"
        case .confirm: return "待确认"
        case .error:   return "异常"
        }
    }

    /// 菜单栏文字状态
    var menuBarText: String {
        switch self {
        case .done:    return "已完成"
        case .confirm: return "待确认"
        case .error:   return "有异常"
        }
    }
}

extension ChimeState {
    /// 菜单栏文字状态
    var menuBarText: String {
        switch self {
        case .idle:              return "空闲"
        case .running:           return "任务中"
        case .attention(let k):  return k.menuBarText
        }
    }
}
