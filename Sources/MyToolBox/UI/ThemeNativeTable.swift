import AppKit

final class ThemeTableView: NSTableView {
    var theme = AppTheme()
    override func drawBackground(inClipRect clipRect: NSRect) {
        guard theme.classic else { super.drawBackground(inClipRect: clipRect); return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor.white.setFill(); clipRect.fill()
    }
    override func highlightSelection(inClipRect clipRect: NSRect) {
        guard theme.classic else { super.highlightSelection(inClipRect: clipRect); return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor(calibratedRed: 0, green: 0, blue: 0.5, alpha: 1).setFill()
        for row in selectedRowIndexes { rect(ofRow: row).intersection(clipRect).fill() }
    }
}
final class ClassicHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor(calibratedWhite: 0.75, alpha: 1).setFill(); cellFrame.fill()
        func line(_ from: NSPoint, _ to: NSPoint, _ color: NSColor) {
            color.setStroke(); let path = NSBezierPath(); path.move(to: from); path.line(to: to); path.lineWidth = 1; path.stroke()
        }
        for i in 0..<2 {
            let frame = cellFrame.insetBy(dx: CGFloat(i) + 0.5, dy: CGFloat(i) + 0.5)
            line(NSPoint(x: frame.minX, y: frame.maxY), NSPoint(x: frame.minX, y: frame.minY), i == 0 ? .white : NSColor(calibratedWhite: 0.87, alpha: 1))
            line(NSPoint(x: frame.minX, y: frame.minY), NSPoint(x: frame.maxX, y: frame.minY), i == 0 ? .white : NSColor(calibratedWhite: 0.87, alpha: 1))
            line(NSPoint(x: frame.minX, y: frame.maxY), NSPoint(x: frame.maxX, y: frame.maxY), i == 0 ? .black : .gray)
            line(NSPoint(x: frame.maxX, y: frame.maxY), NSPoint(x: frame.maxX, y: frame.minY), i == 0 ? .black : .gray)
        }
        (stringValue as NSString).draw(in: cellFrame.insetBy(dx: 5, dy: 3), withAttributes: [.font: NSFont(name: "Tahoma", size: 11) ?? NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black])
    }
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView) { draw(withFrame: cellFrame, in: controlView) }
}
