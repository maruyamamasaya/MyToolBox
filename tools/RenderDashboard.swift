// Real samples rendered offscreen. Does not interact with the desktop or persist preferences.
import SwiftUI
import AppKit
@main struct RenderDashboard {
    @MainActor static func main() async throws {
        let selectedTheme = ProcessInfo.processInfo.arguments.dropFirst().first.map { VisualTheme.resolve($0) } ?? .blueCosmos
        let outputDirectory = "evidence/themes/" + selectedTheme.rawValue
        try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let store = MonitorStore(); store.suspend()
        let engine = MonitorEngine()
        for _ in 0..<3 {
            let sample = await engine.sample()
            store.snapshot = sample; store.history.append(sample)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        store.sleeping = false
        NSApp.applicationIconImage = NSImage(contentsOfFile: "Resources/MyToolBox.icns")
        for selection in ["tools", "overview", "cpu", "memory", "settings"] {
            store.selected = selection
            let root = selection == "tools" ? AnyView(ToolLauncher(openTool: { _ in }, openMonitorSettings: {})) : AnyView(Dashboard(store: store, openTools: {}))
            let host = NSHostingView(rootView: ThemeRoot(override: selectedTheme) { root })
            let size = selection == "tools" ? NSSize(width: 440, height: ToolLauncher.preferredHeight) : NSSize(width: 390, height: 620)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: selectedTheme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host
            host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 500_000_000)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "RenderDashboard", code: 1) }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "RenderDashboard", code: 2) }
            try png.write(to: URL(fileURLWithPath: "\(outputDirectory)/popover-\(selection).png"))
            print("Rendered \(selection): \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
        }
    }
}
