import SwiftUI

@main struct RenderGitBatch {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let model = GitBatchModel()
        // Synthetic display data; no repositories or user settings are changed.
        model.root = "/Example/Development"
        var clean = GitRepositoryStatus(path: "/Example/Development/Clean Project")
        clean.branch = "main"; clean.ahead = 0; clean.behind = 0; clean.result = "ローカル参照と一致"; clean.succeeded = true
        clean.detail = "通信なし。リモート参照は最後の取得時点です。"
        var dirty = GitRepositoryStatus(path: "/Example/Development/変更あり")
        dirty.branch = "main"; dirty.ahead = 1; dirty.behind = 0; dirty.result = "差分あり"; dirty.changes = " M example.txt\n?? new.txt"
        model.rows = [clean, dirty]; model.selected = Set(model.rows.map(\.path)); model.status = "2件を読み込みました。"
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "Git一括管理") { GitBatchView(model: model) })
            let size = NSSize(width: 1000, height: 780)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size); window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 200_000_000)
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
            host.cacheDisplay(in: host.bounds, to: rep)
            let folder = URL(fileURLWithPath: "build/git-batch-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
            print("Rendered \(theme.rawValue)")
        }
    }
}
