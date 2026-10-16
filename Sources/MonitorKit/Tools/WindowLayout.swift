import Foundation

/// Frames use the Accessibility coordinate system: origin at the top left.
public enum WindowLayout: String, CaseIterable, Identifiable {
    case left, right, top, bottom, thirdLeft, thirdCenter, thirdRight, twoThirdsLeft, twoThirdsRight
    case topLeft, topRight, bottomLeft, bottomRight, center, maximize, restore
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .left: return "左半分"
        case .right: return "右半分"
        case .top: return "上半分"
        case .bottom: return "下半分"
        case .thirdLeft: return "左1/3"
        case .thirdCenter: return "中央1/3"
        case .thirdRight: return "右1/3"
        case .twoThirdsLeft: return "左2/3"
        case .twoThirdsRight: return "右2/3"
        case .topLeft: return "左上1/4"
        case .topRight: return "右上1/4"
        case .bottomLeft: return "左下1/4"
        case .bottomRight: return "右下1/4"
        case .center: return "中央"
        case .maximize: return "最大化"
        case .restore: return "元の位置に戻す"
        }
    }
    public func frame(in area: CGRect, current: CGRect) -> CGRect? {
        let unit: CGRect
        switch self {
        case .left: unit = CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .right: unit = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .top: unit = CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottom: unit = CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .thirdLeft: unit = CGRect(x: 0, y: 0, width: 1.0/3, height: 1)
        case .thirdCenter: unit = CGRect(x: 1.0/3, y: 0, width: 1.0/3, height: 1)
        case .thirdRight: unit = CGRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1)
        case .twoThirdsLeft: unit = CGRect(x: 0, y: 0, width: 2.0/3, height: 1)
        case .twoThirdsRight: unit = CGRect(x: 1.0/3, y: 0, width: 2.0/3, height: 1)
        case .topLeft: unit = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: unit = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: unit = CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: unit = CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .maximize: return area
        case .center:
            let size = CGSize(width: min(current.width, area.width), height: min(current.height, area.height))
            return CGRect(x: area.midX - size.width/2, y: area.midY - size.height/2, width: size.width, height: size.height)
        case .restore: return nil
        }
        let x = (area.minX + unit.minX * area.width).rounded()
        let y = (area.minY + unit.minY * area.height).rounded()
        return CGRect(x: x, y: y, width: (area.minX + unit.maxX * area.width).rounded() - x,
                      height: (area.minY + unit.maxY * area.height).rounded() - y)
    }
    public static func accessibilityFrame(_ frame: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
