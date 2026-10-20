// Exercise the real resizable launcher offscreen, including SwiftUI's unbounded measurements.
import SwiftUI
import AppKit

@main struct VerifyLauncherLayout {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let suite = "local.MyToolBox.verify-launcher-layout"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let output = URL(fileURLWithPath: "evidence/launcher-layout")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for theme in VisualTheme.allCases {
            let root = ThemeRoot(override: theme) {
                ToolLauncher(openTool: { _ in }, openMonitorSettings: {}, resizable: true, toolIcon: { tool in
                    NSImage(contentsOfFile: "Resources/ToolIcons/\(tool.rawValue).icns")
                })
            }.defaultAppStorage(defaults)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            for size in [NSSize(width: 560, height: 480), NSSize(width: 900, height: 740), NSSize(width: 560, height: 740)] {
                window.setContentSize(size)
                host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded()
                host.layoutSubtreeIfNeeded()
                let fitting = host.fittingSize
                precondition(fitting.width.isFinite && fitting.height.isFinite)
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                    throw NSError(domain: "VerifyLauncherLayout", code: 1)
                }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = bitmap.representation(using: .png, properties: [:])!
                try data.write(to: output.appendingPathComponent("\(theme.rawValue)-\(Int(size.width))x\(Int(size.height)).png"))
            }
            print("PASS: resizable launcher, three sizes and fitting measurement: \(theme.rawValue)")
        }
    }
}
