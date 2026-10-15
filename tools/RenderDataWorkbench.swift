// Synthetic previews only. Does not read user files or change preferences.
import SwiftUI

@main struct RenderDataWorkbench {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let views: [(String, AnyView)] = [
            ("regex-tester", AnyView(RegexTesterView())),
            ("regex-builder", AnyView(RegexBuilderView())),
            ("table-builder", AnyView(TableBuilderView())),
            ("csv-statistics", AnyView(CSVStatisticsView(sample: true)))
        ]
        for theme in VisualTheme.allCases {
            for (name, view) in views {
                let size = NSSize(width: 1000, height: 1000)
                let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: name) { view })
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("描画失敗") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let folder = URL(fileURLWithPath: "build/data-workbench-preview/\(theme.rawValue)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
                print("Rendered \(theme.rawValue)/\(name)")
            }
        }
    }
}
