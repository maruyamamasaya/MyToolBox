import AppKit
import SwiftUI
@main struct RenderCompactRegexTester {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.regex.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/regex-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let pattern = #"([A-Za-z]+)-(\d+)"#
  let text = "item-123\norder-456\n日本語のテスト"
  let result = Result { try RegexWorkbench.test(text, pattern: pattern, replacement: "$1: $2") }
  let output = try result.get(); precondition(output.matches.count == 2)

  for theme in VisualTheme.allCases {
   for tab in 0...2 {
    for expanded in [false, true] {
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "正規表現テスター") {
     RegexTesterView(initiallyExpanded: expanded, initialResultTab: tab, initialResult: result)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 560) + (theme == .windows98 ? 30 : 0))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(tab)-\(expanded ? "expanded" : "compact").png"))
    precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
    print("PASS \(theme.rawValue) tab=\(tab) expanded=\(expanded)")
    }
   }
  }

  for (name, view) in [
    ("invalid", AnyView(RegexTesterView(initialPattern: "[", initialResult: Result { try RegexWorkbench.test(text, pattern: "[") }))),
    ("empty", AnyView(RegexTesterView(initialPattern: "absent", initialResult: Result { try RegexWorkbench.test(text, pattern: "absent") }))),
    ("builder", AnyView(RegexBuilderView()))
  ] {
    let size = NSSize(width: name == "builder" ? 1000 : 400, height: name == "builder" ? 1000 : 560)
    let host = NSHostingView(rootView: ThemeRoot(override: VisualTheme.allCases[0], windowTitle: name) { view }.defaultAppStorage(defaults))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
    print("PASS \(name)")
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 560), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 560); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip")
 }
}
