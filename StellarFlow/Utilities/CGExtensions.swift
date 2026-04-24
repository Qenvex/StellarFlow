import CoreGraphics
import SpriteKit

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }
    static func / (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x / s, y: p.y / s) }

    var length: CGFloat { sqrt(x * x + y * y) }
    var normalized: CGPoint {
        let len = length
        return len > 0 ? CGPoint(x: x / len, y: y / len) : .zero
    }
    func dot(_ other: CGPoint) -> CGFloat { x * other.x + y * other.y }
    func cross(_ other: CGPoint) -> CGFloat { x * other.y - y * other.x }
    func distance(to other: CGPoint) -> CGFloat { (self - other).length }
    var angle: CGFloat { atan2(y, x) }
}

extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}

extension SKColor {
    static func fromHex(_ hex: UInt32, alpha: CGFloat = 1) -> SKColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8)  & 0xFF) / 255.0
        let b = CGFloat( hex        & 0xFF) / 255.0
        return SKColor(red: r, green: g, blue: b, alpha: alpha)
    }
}
