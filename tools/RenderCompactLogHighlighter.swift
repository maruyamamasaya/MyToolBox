import AppKit
import SwiftUI
@main struct RenderCompactLogHighlighter {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.log.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/log-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let text = "INFO server started\nDEBUG connecting to database\nWARN response is slow\nERROR connection timeout\n  retry scheduled\nINFO connection recovered\nTRACE request completed\n"
  let lines = LogHighlighter.parse(text)
  precondition(lines.count == 8)
  precondition(LogHighlighter.visible(lines, levels: [.error], context: 1).map(\.id) == [3, 4, 5])
  precondition(LogHighlighter.matches(lines[3].text, query: "connection").count == 1)
  let scenarios: [(String, String, Bool, Set<LogLevel>, Bool)] = [
   ("all", text, true, Set(LogLevel.allCases), false),
   ("error", text, true, [.fatal, .error], false),
   ("wrap", "ERROR " + String(repeating: "長いログの文字列 ", count: 25), true, Set(LogLevel.allCases), true),
   ("none", text, true, [], false),
   ("empty", "", false, Set(LogLevel.allCases), false)
  ]
  for theme in VisualTheme.allCases {
   for (name, source, analyzed, levels, wrap) in scenarios {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ログハイライター") {
      LogHighlighterView(initiallyExpanded: expanded, initialInput: source, initiallyAnalyzed: analyzed, initialQuery: "connection", initialLevels: levels, initialWrap: wrap)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 420, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(name)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
     print("PASS \(theme.rawValue) \(name) expanded=\(expanded)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 420, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / actual filtering and literal search")
 }
}
