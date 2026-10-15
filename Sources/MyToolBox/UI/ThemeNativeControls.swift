import SwiftUI
import AppKit

/// Retain real popup keyboard navigation and selection while drawing classic chrome.
struct ClassicPopup<Value: Hashable>: NSViewRepresentable {
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]
    @Environment(\.isEnabled) private var enabled
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.cell = ClassicPopupCell(textCell: "", pullsDown: false)
        button.target = context.coordinator; button.action = #selector(Coordinator.choose(_:))
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        let titles = options.map(\.1)
        if button.itemTitles != titles { button.removeAllItems(); button.addItems(withTitles: titles) }
        if let index = options.firstIndex(where: { $0.0 == selection }) { button.selectItem(at: index) }
        button.isEnabled = enabled; button.setAccessibilityLabel(title); button.needsDisplay = true
    }
    final class Coordinator: NSObject {
        var parent: ClassicPopup
        init(_ parent: ClassicPopup) { self.parent = parent }
        @objc func choose(_ button: NSPopUpButton) {
            guard parent.options.indices.contains(button.indexOfSelectedItem) else { return }
            parent.selection = parent.options[button.indexOfSelectedItem].0
        }
    }
}
private final class ClassicPopupCell: NSPopUpButtonCell {
    override func draw(withFrame frame: NSRect, in view: NSView) {
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSColor.white.setFill(); frame.fill()
        drawBevel(frame, sunken: true)
        let arrow = NSRect(x: frame.maxX - 19, y: frame.minY + 2, width: 17, height: frame.height - 4)
        NSColor(calibratedWhite: 0.75, alpha: 1).setFill(); arrow.fill(); drawBevel(arrow, sunken: isHighlighted)
        let color: NSColor = isEnabled ? .black : .gray
        color.setFill()
        let triangle = NSBezierPath(); triangle.move(to: NSPoint(x: arrow.midX - 3, y: arrow.midY - 1)); triangle.line(to: NSPoint(x: arrow.midX + 3, y: arrow.midY - 1)); triangle.line(to: NSPoint(x: arrow.midX, y: arrow.midY + 2)); triangle.close(); triangle.fill()
        let textFrame = NSRect(x: frame.minX + 5, y: frame.midY - 7, width: max(0, frame.width - 27), height: 14)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: textFrame, withAttributes: [.font: NSFont(name: "Microsoft Sans Serif", size: 11) ?? .systemFont(ofSize: 11), .foregroundColor: color, .paragraphStyle: paragraph])
        if showsFirstResponder {
            NSColor.black.setStroke(); let dotted = NSBezierPath(rect: frame.insetBy(dx: 4, dy: 4)); dotted.lineWidth = 1; dotted.setLineDash([1, 1], count: 2, phase: 0); dotted.stroke()
        }
    }
    override var cellSize: NSSize { NSSize(width: max(70, super.cellSize.width), height: 23) }
    private func drawBevel(_ rect: NSRect, sunken: Bool) {
        for i in 0..<2 {
            let inset = rect.insetBy(dx: CGFloat(i) + 0.5, dy: CGFloat(i) + 0.5)
            let upper: NSColor = sunken ? (i == 0 ? .gray : .black) : (i == 0 ? .white : NSColor(calibratedWhite: 0.87, alpha: 1))
            let lower: NSColor = sunken ? (i == 0 ? .white : NSColor(calibratedWhite: 0.87, alpha: 1)) : (i == 0 ? .black : .gray)
            upper.setStroke(); let a = NSBezierPath(); a.move(to: NSPoint(x: inset.minX, y: inset.maxY)); a.line(to: NSPoint(x: inset.minX, y: inset.minY)); a.line(to: NSPoint(x: inset.maxX, y: inset.minY)); a.stroke()
            lower.setStroke(); let b = NSBezierPath(); b.move(to: NSPoint(x: inset.minX, y: inset.maxY)); b.line(to: NSPoint(x: inset.maxX, y: inset.maxY)); b.line(to: NSPoint(x: inset.maxX, y: inset.minY)); b.stroke()
        }
    }
}
