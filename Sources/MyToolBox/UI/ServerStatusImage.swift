import AppKit

/// Compact menu image: server rack, photo above music, one status dot per service.
@MainActor enum ServerStatusImage {
    static func make(readings: [ServerCheckReading], now: Date = Date()) -> NSImage {
        let states = [ServerCheck.health, .musicListener].map {
            ServerIndicator.state(for: $0, readings: readings, now: now)
        }
        let image = NSImage(size: NSSize(width: 43, height: 22), flipped: false) { _ in
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
            for (index, name) in ["photo", "music.note"].enumerated() {
                let y: CGFloat = index == 0 ? 12 : 1
                symbol(name, in: NSRect(x: 21, y: y, width: 11, height: 9))
                let color: NSColor = states[index] == .confirmed ? .systemGreen : states[index] == .attention ? .systemOrange : .secondaryLabelColor
                color.setFill(); NSBezierPath(ovalIn: NSRect(x: 36, y: y + 2, width: 5, height: 5)).fill()
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "サーバー状態：上段は写真、下段は音楽"
        return image
    }
}
