import SwiftUI

@main struct RenderWindowManager {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ウィンドウマネージャー") { WindowManagerView() })
            let size = NSSize(width: 720, height: 690)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 200_000_000)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
            host.cacheDisplay(in: host.bounds, to: rep)
            let folder = URL(fileURLWithPath: "build/window-manager-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
            print("Rendered \(theme.rawValue)")
        }
    }
}
