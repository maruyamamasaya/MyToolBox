// Isolated integration check: the same preference updates multiple retained SwiftUI roots.
import SwiftUI
import AppKit

@MainActor final class Observation {
    var themes: [String: VisualTheme] = [:]
    var appearances: [String: Int] = [:]
    var state: [String: String] = [:]
}
private struct Probe: View {
    @Environment(\.appTheme) private var theme
    @State private var input = "編集中の入力"
    let name: String
    let observation: Observation
    var body: some View {
        VStack {
            TextField("入力", text: $input)
            Text(theme.id.rawValue)
            ThemeSettings()
        }.onAppear { observation.appearances[name, default: 0] += 1 }
            .background(Record(name: name, theme: theme.id, input: input, observation: observation))
    }
}
private struct Record: NSViewRepresentable {
    let name: String; let theme: VisualTheme; let input: String; let observation: Observation
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) { observation.themes[name] = theme; observation.state[name] = input }
}
@main struct ThemeSwitchProbe {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let suite = "MyToolBoxThemeProbe.\(UUID())", observation = Observation()
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var windows: [NSWindow] = []
        for name in ["first", "second"] {
            let root = ThemeRoot(windowTitle: name) { Probe(name: name, observation: observation) }.defaultAppStorage(defaults)
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 260), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.contentView = host; host.frame = NSRect(x: 0, y: 0, width: 500, height: 260); windows.append(window)
        }
        for theme in [VisualTheme.blueCosmos, .livingAurora, .windows98, .blueCosmos] {
            theme.save(to: defaults)
            try await Task.sleep(nanoseconds: 400_000_000)
            for (index, window) in windows.enumerated() {
                window.contentView?.layoutSubtreeIfNeeded()
                let name = index == 0 ? "first" : "second"
                guard observation.themes[name] == theme, observation.appearances[name] == 1, observation.state[name] == "編集中の入力" else { throw ToolFailure.message("Theme/state propagation failed: \(name) \(theme.rawValue)") }
                guard (window.standardWindowButton(.closeButton)?.isHidden ?? true) == (theme == .windows98) else { throw ToolFailure.message("Native chrome failed") }
            }
            print("PASS: both retained windows → \(theme.rawValue), input preserved")
        }
        // Recreate a root to check the restored choice (same isolated preferences).
        VisualTheme.windows98.save(to: defaults)
        let restored = ToolWindow(title: "restored", view: Probe(name: "restored", observation: observation), themeDefaults: defaults)
        let window = restored.window!; windows.append(window)
        try await Task.sleep(nanoseconds: 400_000_000)
        guard observation.themes["restored"] == .windows98 && !window.styleMask.contains(.titled) && window.canBecomeKey else { throw ToolFailure.message("Theme restore failed") }
        print("PASS: real ToolWindow restored Windows 98, native title removed, keyboard enabled")
        VisualTheme.blueCosmos.save(to: defaults)
        try await Task.sleep(nanoseconds: 400_000_000)
        guard window.styleMask.contains(.titled) else { throw ToolFailure.message("Real ToolWindow native title restore failed") }
        print("PASS: real ToolWindow native title restored")
        print("Classic font: \(NSFont(name: AppTheme(id: .windows98).fontName, size: 11)?.fontName ?? "system fallback")")
    }
}
