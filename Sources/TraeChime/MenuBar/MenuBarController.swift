import AppKit

/// 菜单栏控制器：左侧圆角 logo + 文字状态 + 右上角呼吸彩色点。
/// 占用宽度固定，内容左对齐；动画仅保留右上角圆点的呼吸灯。
final class MenuBarController {
    private let statusItem: NSStatusItem
    /// 菜单栏固定占用宽度（pt）
    private let fixedWidth: CGFloat = 60
    /// logo 显示尺寸
    private let logoSize: CGFloat = 16
    /// logo 与文本之间的间距
    private let spacing: CGFloat = 6
    /// 右上角彩色呼吸点
    private var dotLayer: CAShapeLayer?

    /// 当前聚合状态，用于判断是否启用「任务中」逐字跳动动画
    private var currentState: ChimeState = .idle
    /// 「任务中」逐字跳动动画的驱动定时器
    private var textBounceTimer: Timer?
    /// 动画起始时刻（单调时钟），据此计算各字符的跳动相位
    private var textBounceStart: TimeInterval = 0

    var onClick: (() -> Void)?
    var statusButton: NSStatusBarButton? { statusItem.button }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: fixedWidth)
        if let button = statusItem.button {
            button.wantsLayer = true
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp])
        }
        setState(.idle)
    }

    @objc private func handleClick() { onClick?() }

    // MARK: 状态切换

    func setState(_ state: ChimeState) {
        currentState = state
        stopTextBounce()

        guard let button = statusItem.button else { return }
        render(on: button)

        // 仅「需要注意」时显示右上角彩色呼吸点
        dotLayer?.removeFromSuperlayer()
        dotLayer = nil
        if case .attention(let kind) = state {
            installDot(on: button, color: kind.dotColor)
        }

        // 「任务中」启动逐字跳动动画
        if state == .running {
            startTextBounce()
        }
    }

    // MARK: - 合成内容（左对齐 logo + 6px 间距 + 文字）

    /// 刷新菜单栏按钮图片，并根据当前状态决定是否应用逐字跳动偏移
    private func render(on button: NSStatusBarButton) {
        let height = button.bounds.height > 0 ? button.bounds.height : 22
        let text = currentState.menuBarText
        button.image = renderContent(text: text, height: height, charOffsets: bounceOffsets(for: text))
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(text)
    }

    // MARK: - 「任务中」逐字跳动动画

    /// 计算「任务中」各字符当前向上的偏移量；非 running 状态返回 nil 走静态绘制
    private func bounceOffsets(for text: String) -> [CGFloat]? {
        guard currentState == .running, text.count > 1 else { return nil }
        let period = 0.3                               // 单个字符「跳起-落下」的周期（秒）
        let elapsed = CACurrentMediaTime() - textBounceStart
        let active = Int(elapsed / period) % text.count   // 当前活跃字符：任→务→中 依次串行
        let local = (elapsed / period).truncatingRemainder(dividingBy: 1)  // 当前字符内部相位 0~1
        let height = sin(local * .pi) * 2              // 正弦脉冲：0 → 峰值(2pt) → 0，只向上
        return (0..<text.count).map { index in
            index == active ? height : 0
        }
    }

    private func startTextBounce() {
        textBounceStart = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let button = self.statusItem.button else { return }
            self.render(on: button)
        }
        // 加入 common 模式，确保菜单打开等场景下动画依旧持续
        RunLoop.main.add(timer, forMode: .common)
        textBounceTimer = timer
    }

    private func stopTextBounce() {
        textBounceTimer?.invalidate()
        textBounceTimer = nil
    }

    /// 将 logo 与状态文字合成到一张固定宽度图片，保证左对齐与间距可控
    private func renderContent(text: String, height: CGFloat, charOffsets: [CGFloat]?) -> NSImage {
        let image = NSImage(size: NSSize(width: fixedWidth, height: height))
        let appearance = statusItem.button?.effectiveAppearance
            ?? NSApp.appearance
            ?? NSAppearance(named: .aqua)!
        appearance.performAsCurrentDrawingAppearance {
            image.lockFocus()
            // 左侧 logo，垂直居中
            let logoY = (height - logoSize) / 2
            if let logo = Self.loadLogo() {
                logo.draw(in: NSRect(x: 0, y: logoY, width: logoSize, height: logoSize))
            }
            // 文本：logo 右侧 + spacing，左对齐，垂直居中
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Self.roundedFont(size: 11),
                .foregroundColor: NSColor.white
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textX = logoSize + spacing
            // 圆体字形底部有 descender 溢出，光学中心略偏下，微调补偿
            let textY = (height - textSize.height) / 2 + 0.5

            if let offsets = charOffsets, offsets.count == text.count {
                // 逐字绘制：每个字符独立垂直偏移，实现「任→务→中」依次跳动
                var x = textX
                for (index, char) in text.enumerated() {
                    let s = String(char)
                    let w = (s as NSString).size(withAttributes: attrs).width
                    s.draw(at: NSPoint(x: x, y: textY + offsets[index]), withAttributes: attrs)
                    x += w
                }
            } else {
                (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
            }
            image.unlockFocus()
        }
        return image
    }

    /// 圆润字体：优先系统圆体，找不到则回退到菜单栏默认字体
    private static func roundedFont(size: CGFloat) -> NSFont {
        let candidates = [
            "Yuanti SC", "YuantiSC-Regular", "STYuanti-SC-Regular",
            "Hiragino Maru Gothic ProN", "PingFang SC"
        ]
        for name in candidates {
            if let font = NSFont(name: name, size: size) { return font }
        }
        return NSFont.menuBarFont(ofSize: size)
    }

    private static func loadLogo() -> NSImage? {
        // 打包后的 app 资源位于 Contents/Resources，优先从 Bundle.main 读取；
        // 用短路判断避免在 app 中触发 Bundle.module 初始化（其硬编码了开发机 .build 路径）
        if let url = Bundle.main.url(forResource: "traechime-logo-mark", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // 开发阶段（swift run）资源在 SwiftPM resource bundle 中，作为兜底
        if let url = Bundle.module.url(forResource: "traechime-logo-mark", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }

    // MARK: - 右上角彩色呼吸点

    private func installDot(on button: NSStatusBarButton, color: NSColor) {
        let b = button.bounds
        let diameter: CGFloat = 6
        let r = diameter / 2
        let pad: CGFloat = 1

        let dot = CAShapeLayer()
        dot.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: diameter, height: diameter),
                          transform: nil)
        dot.fillColor = color.cgColor
        dot.zPosition = 10
        // 右上角定位（CALayer 坐标 y 向下，顶部为 minY）
        dot.position = CGPoint(x: b.maxX - r - pad + 4, y: b.minY + r + pad + 2)
        button.layer?.addSublayer(dot)
        dotLayer = dot

        // 呼吸灯：透明度与缩放同步脉动
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 0.35; breathe.toValue = 1.0
        breathe.duration = 1.0; breathe.autoreverses = true; breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dot.add(breathe, forKey: "dotBreathe")

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.85; pulse.toValue = 1.12
        pulse.duration = 1.0; pulse.autoreverses = true; pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dot.add(pulse, forKey: "dotPulse")
    }
}
