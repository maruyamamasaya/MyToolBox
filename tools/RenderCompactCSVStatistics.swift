import AppKit
import SwiftUI
@main struct RenderCompactCSVStatistics {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.statistics.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/statistics-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let sample = "名前,数量,金額\nりんご,3,450\nみかん,5,500\nぶどう,NULL,800\nみかん,5,500"
  let result = try SmallDataTools.statistics(SmallDataTools.parse(sample), header: true, nullTokens: "NULL,NA,N/A")
  precondition(result.rows == 4 && result.duplicates == 1 && result.nulls == 1)
  precondition(result.columns[1].sum == 13 && result.columns[1].median == 5)
  for theme in VisualTheme.allCases {
   for (name, text, column) in [("number", sample, 1), ("text", sample, 0), ("empty", "", 0), ("invalid", "a,\"unterminated", 0)] {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "CSV統計") {
      CSVStatisticsView(initiallyExpanded: expanded, initialInput: text, initialColumn: column)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(name)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
     print("PASS \(theme.rawValue) \(name) expanded=\(expanded)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / actual sample aggregates")
 }
}
