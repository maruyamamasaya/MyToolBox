import AppKit

/// Compact menu image: server rack and a two-column grid, one status dot per service.
@MainActor enum ServerStatusImage {
    static func make(readings: [ServerCheckReading], now: Date = Date()) -> NSImage {
        let states = [ServerCheck.health, .musicListener, .taskRelayListener].map {
            ServerIndicator.state(for: $0, readings: readings, now: now)
        }
        let image = NSImage(size: NSSize(width: 66, height: 22), flipped: false) { _ in
            func symbol(_ name: String, in rect: NSRect) {
                guard let icon = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
                let scale = min(rect.width / icon.size.width, rect.height / icon.size.height)
                let size = NSSize(width: icon.size.width * scale, height: icon.size.height * scale)
                let target = NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
                guard let context = NSGraphicsContext.current?.cgContext else { return }
                context.saveGState(); context.beginTransparencyLayer(auxiliaryInfo: nil)
                icon.draw(in: target)
                let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                (dark ? NSColor.white : NSColor.black).setFill(); target.fill(using: .sourceAtop)
                context.endTransparencyLayer(); context.restoreGState()
            }
            symbol("server.rack", in: NSRect(x: 0, y: 2, width: 16, height: 18))
            for (index, name) in ["photo", "music.note", "checklist"].enumerated() {
                let y: CGFloat = index % 2 == 0 ? 12 : 1
                let x: CGFloat = 21 + CGFloat(index / 2) * 23
                symbol(name, in: NSRect(x: x, y: y, width: 11, height: 9))
                let color: NSColor = states[index] == .confirmed ? .systemGreen : states[index] == .attention ? .systemOrange : .secondaryLabelColor
                color.setFill(); NSBezierPath(ovalIn: NSRect(x: x + 15, y: y + 2, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "サーバー状態：左列は上段が写真・下段が音楽、右列は上段がTaskApp中継"
        return image
    }
}
