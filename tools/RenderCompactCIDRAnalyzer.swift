import AppKit
import SwiftUI
@main struct RenderCompactCIDRAnalyzer {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.cidr.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/cidr-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let sample = "192.168.1.10/24\n192.168.1.11/24\n192.168.1.13/20"
  let result = try NetworkBuilders.analyze(sample)
  precondition(result.subnets.count == 3 && result.groups.count == 2 && result.hierarchy.contains("192.168.0.0/20"))
  let formatted = NetworkBuilders.formatCIDR("192.168.1.10 ／ 24\n192.0.2.1 32")
  precondition(formatted == "192.168.1.10/24\n192.0.2.1/32")
  let scenarios: [(String, String, Int, Int)] = [("detail", sample, 0, 0), ("groups", sample, 0, 1), ("hierarchy", sample, 0, 2), ("format", sample, 1, 0), ("mixed", "192.0.2.0/31\n192.0.2.1/32\nbroken", 0, 0)]
  for theme in VisualTheme.allCases {
   for (name, input, tab, resultTab) in scenarios {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "CIDR解析") {
      CIDRAnalyzerView(initiallyExpanded: expanded, initialTab: tab, initialResultTab: resultTab, initialInput: input, initiallyAnalyzed: true, initialSource: "192.168.1.10 ／ 24\n192.0.2.1 32", initiallyFormatted: true)
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
  print("PASS native size roundtrip / actual CIDR grouping and formatting, no network")
 }
}
