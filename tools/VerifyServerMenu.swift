import AppKit
import SwiftUI

@main struct VerifyServerMenu {
    @MainActor static func main() async throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: "build/server-menu-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date()
        let cases: [(String, [ServerCheckReading])] = [
            ("confirmed", [.init(item: .health, state: .confirmed, detail: "HTTP 200", checkedAt: now), .init(item: .musicListener, state: .confirmed, detail: "Python の TCP 8768 待受を確認", checkedAt: now)]),
            ("attention", [.init(item: .health, state: .attention, detail: "HTTP 200 を確認できません", checkedAt: now)]),
            ("stale", [.init(item: .health, state: .confirmed, detail: "", checkedAt: now.addingTimeInterval(-151))]),
            ("unknown", [])
        ]
        for (name, rows) in cases {
            for (appearanceName, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let image = ServerStatusImage.make(readings: rows, now: now)
                precondition(image.size == NSSize(width: 43, height: 22) && !image.isTemplate)
                let preview = NSImage(size: NSSize(width: 63, height: 28))
                NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                    preview.lockFocus()
                    NSColor.windowBackgroundColor.setFill(); NSRect(x: 0, y: 0, width: 63, height: 28).fill()
                    image.draw(at: NSPoint(x: 10, y: 3), from: .zero, operation: .sourceOver, fraction: 1)
                    preview.unlockFocus()
                }
                let bitmap = NSBitmapImageRep(data: preview.tiffRepresentation!)!
                try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name + "-" + appearanceName + ".png"))
            }
        }
        // Actual collector, no credential or media requests. Print sanitized result only.
        let full = ProcessInfo.processInfo.arguments.contains("--full")
        let rows = await ServerManagementCollector().read(menuOnly: !full)
        for row in rows { print(row.item.rawValue, row.state.rawValue, row.detail) }
        precondition(rows.map(\.item) == (full ? ServerCheck.allCases : [.health, .musicListener]))
        print("PASS: actual menu title rendering, missing/stale variants and bounded live collection")
    }
}
