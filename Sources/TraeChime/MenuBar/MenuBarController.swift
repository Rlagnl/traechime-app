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
        guard let button = statusItem.button else { return }
        let height = button.bounds.height > 0 ? button.bounds.height : 22
        button.image = renderContent(text: state.menuBarText, height: height)
        button.imagePosition = .imageOnly
        button.setAccessibilityLabel(state.menuBarText)

        // 仅「需要注意」时显示右上角彩色呼吸点
        dotLayer?.removeFromSuperlayer()
        dotLayer = nil
        if case .attention(let kind) = state {
            installDot(on: button, color: kind.dotColor)
        }
    }

    // MARK: - 合成内容（左对齐 logo + 6px 间距 + 文字）

    /// 将 logo 与状态文字合成到一张固定宽度图片，保证左对齐与间距可控
    private func renderContent(text: String, height: CGFloat) -> NSImage {
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
            (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
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
        let candidates: [URL?] = [
            Bundle.module.url(forResource: "traechime-logo-mark", withExtension: "png"),
            Bundle.main.url(forResource: "traechime-logo-mark", withExtension: "png")
        ]
        for url in candidates {
            if let url = url, let image = NSImage(contentsOf: url) {
                return image
            }
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
