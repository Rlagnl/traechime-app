import AppKit

/// TraeChime 菜单栏铃铛图标。
/// 形状直接取自设计稿规范 `menubar-bell-spec.md §8.2` 的 SVG path 精确坐标，
/// 不再手调贝塞尔曲线，保证与设计稿 100% 一致。
enum BellIcon {

    // MARK: - SVG 路径数据（viewBox 0 0 120 120，y 向下，坐标对用空格分隔）

    private static let bodyD = "61.5,8.4 63.5,9.0 65.1,10.1 66.4,11.9 67.3,14.8 68.0,18.1 69.7,20.6 72.6,22.2 76.3,24.0 80.0,26.4 83.2,29.0 85.6,31.6 87.1,33.9 88.3,35.8 89.2,38.1 90.0,42.3 90.6,51.2 90.9,63.1 91.2,72.0 91.5,75.9 91.9,77.5 92.2,78.3 92.3,78.9 92.4,79.7 92.9,81.2 94.1,83.3 95.4,85.2 96.7,86.9 97.8,88.6 98.7,90.2 99.5,91.4 100.1,92.0 100.5,92.5 100.9,93.3 101.1,94.3 96.0,95.4 75.4,96.1 44.6,96.1 24.0,95.4 19.4,93.7 21.2,90.1 24.1,85.3 26.4,81.0 27.5,76.6 27.9,68.1 28.2,56.7 28.4,48.2 28.6,43.9 29.2,41.0 30.1,38.1 31.3,35.3 32.8,32.8 34.2,30.8 35.4,29.4 36.6,28.5 38.0,27.2 39.9,25.6 42.2,23.9 44.9,22.6 47.6,21.6 49.9,20.6 51.2,19.0 51.6,16.8 51.8,14.9 52.2,13.4 52.8,12.2 53.6,11.4 54.3,10.6 54.9,9.9 55.9,9.1 57.5,8.5 59.3,8.2"

    private static let clapperD = "49.0,102.2 55.2,102.3 64.5,102.7 70.5,103.3 71.6,104.4 70.7,105.9 69.3,107.6 67.7,109.1 66.5,110.1 65.6,110.6 64.3,111.1 62.7,111.6 60.7,111.9 58.4,111.8 56.2,111.3 54.2,110.5 52.3,109.2 50.6,107.7 49.3,106.1 48.4,104.4 47.8,102.9"

    // MARK: - 包围盒常量（从 SVG 数据测得）

    private static let bodyW: CGFloat = 81.7    // 主体宽 = 101.1 - 19.4
    private static let bodyH: CGFloat = 87.9    // 主体高 = 96.1 - 8.2
    private static let bodyCX: CGFloat = 60.25  // 主体中心 x
    private static let bodyCY: CGFloat = 52.15  // 主体中心 y
    private static let wholeCY: CGFloat = 60.05 // 整体（含铃舌）中心 y

    // MARK: - 坐标映射

    /// 缩放系数：让主体宽度占图标宽度的 62%
    private static func scale(in rect: CGRect) -> CGFloat {
        rect.width * 0.62 / bodyW
    }

    /// SVG 坐标（y 向下）→ CALayer/CAShapeLayer 坐标（同样 y 向下，原点左上），仅做居中平移、不翻转 y
    private static func map(_ p: CGPoint, _ s: CGFloat, _ rect: CGRect) -> CGPoint {
        CGPoint(x: (p.x - bodyCX) * s + rect.midX,
                y: (p.y - wholeCY) * s + rect.midY)
    }

    private static func points(_ d: String) -> [CGPoint] {
        d.split(separator: " ").map {
            let c = $0.split(separator: ",").map { CGFloat(Double($0)!) }
            return CGPoint(x: c[0], y: c[1])
        }
    }

    private static func path(_ d: String, in rect: CGRect) -> NSBezierPath {
        let s = scale(in: rect)
        let pts = points(d)
        let p = NSBezierPath()
        p.move(to: map(pts[0], s, rect))
        for pt in pts.dropFirst() { p.line(to: map(pt, s, rect)) }
        p.close()
        return p
    }

    // MARK: - 铃铛本体 + 铃舌

    static func bellPath(in rect: CGRect) -> NSBezierPath { path(bodyD, in: rect) }
    static func clapperPath(in rect: CGRect) -> NSBezierPath { path(clapperD, in: rect) }

    /// 铃铛整体剪影（本体 + 铃舌），供 CAShapeLayer 使用
    static func silhouettePath(in rect: CGRect) -> NSBezierPath {
        let p = bellPath(in: rect)
        p.append(clapperPath(in: rect))
        return p
    }

    // MARK: - 声波弧（执行中：铃铛右侧 2 道扇形灰弧，spec §4）

    static func wavePaths(in rect: CGRect) -> [NSBezierPath] {
        let s = scale(in: rect)
        let H = bodyH * s                        // 主体高
        // 圆心：铃铛主体中心上方 0.18H（y 向下，上方 = y 更小）
        let center = CGPoint(x: rect.midX,
                             y: rect.midY - (wholeCY - bodyCY) * s - 0.18 * H)
        let radii: [CGFloat] = [0.25 * H, 0.5 * H]   // 半径（相对 spec 调小）
        let start: CGFloat = -48 * .pi / 180         // 右下
        let end: CGFloat = 48 * .pi / 180            // 右上（对称，开口朝右）
        return radii.map {
            let p = NSBezierPath()
            p.appendArc(withCenter: center, radius: $0,
                        startAngle: start, endAngle: end, clockwise: false)
            return p
        }
    }

    /// 声波弧线宽（调小）
    static func waveLineWidth(in rect: CGRect) -> CGFloat {
        bodyH * scale(in: rect) * 0.05
    }

    // MARK: - 彩色状态点（attention，spec §5）

    /// 返回点相对图标中心的偏移与直径（标准铃铛宽 w = size*0.62 为基准）。
    /// 文档点中心相对 attention 主体中心偏移 (+202,-145)、直径 0.19×attention 宽；
    /// attention 放大 1.5×，故换算到标准宽：offset (0.633, 0.455)、直径 0.19。
    static func dotMetrics(size: CGFloat) -> (offset: CGPoint, diameter: CGFloat) {
        let w = size * 0.62
        return (CGPoint(x: w * 0.633, y: w * 0.455), w * 0.19)
    }

    // MARK: - 生成 template 图标

    static func image(size: CGFloat, wave: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.isTemplate = true
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)

        // 铃铛本体 + 铃舌（纯黑剪影）
        NSColor.black.setFill()
        bellPath(in: rect).fill()
        clapperPath(in: rect).fill()

        // 声波（灰色 → template 映射为半透明）
        if wave {
            NSColor(calibratedWhite: 0.5, alpha: 1).setStroke()
            for p in wavePaths(in: rect) {
                p.lineWidth = bodyH * scale(in: rect) * 0.075
                p.lineCapStyle = .round
                p.stroke()
            }
        }

        image.unlockFocus()
        return image
    }
}
