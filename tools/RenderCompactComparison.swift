import AppKit
import SwiftUI
@main struct RenderCompactComparison {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.comparison.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/comparison-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for mode in ComparisonModel.Mode.allCases {
    let model = ComparisonModel()
    model.mode = mode; model.left = "りんご\nみかん\nぶどう"; model.right = "りんご\nバナナ\nぶどう"
    model.compare()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let left = model.left, right = model.right
    let diffText = model.diff?.plainText
    let common = model.lists?.common
    for expanded in [false, true, false] {
     let root = ThemeRoot(override: theme, windowTitle: "比較ツール") { ComparisonView(model: model, initiallyExpanded: expanded) }
     let host = NSHostingView(rootView: root.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 360, height: (expanded ? 850 : 520) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + (mode == .diff ? "-diff" : "-lists") + (expanded ? "-expanded" : "-compact") + ".png"))
     guard model.left == left, model.right == right, model.diff?.plainText == diffText, model.lists?.common == common else { fatalError("content lost during layout change") }
     print("PASS \(theme.rawValue) \(mode) expanded=\(expanded) fitting \(host.fittingSize)")
    }
    model.stop()
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 360,height: 520), styleMask: [.titled,.resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  window.contentView = bridge
  bridge.expanded = false; bridge.apply()
  let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply()
  let expanded = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  guard window.contentLayoutRect.size == compact, expanded.width > compact.width, expanded.height > compact.height else { fatalError("resize roundtrip") }
  print("PASS hidden native window resize roundtrip \(compact) -> \(expanded) -> \(compact)")
 }
}
