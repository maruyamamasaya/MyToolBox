import AppKit
import SwiftUI
@main struct RenderCompactRegexBuilder {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.regex.builder.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/regex-builder-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for tab in 0...1 {
    for expanded in [false, true] {
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "正規表現ビルダー") {
     RegexBuilderView(initiallyExpanded: expanded, initialTab: tab)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
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

  var literal = RegexWorkbench.Part(); literal.kind = .literal; literal.value = "item-"
  var range = RegexWorkbench.Part(); range.repetition = .range; range.minimum = 1; range.maximum = 5
  var either = RegexWorkbench.Part(); either.kind = .either; either.value = "cat"; either.alternative = "dog"
  var group = RegexWorkbench.Part(); group.kind = .group; group.value = "abc"; group.capture = false
  var character = RegexWorkbench.Part(); character.kind = .characterClass; character.value = "a-z"; character.negate = true
  var invalid = RegexWorkbench.Part(); invalid.kind = .characterClass; invalid.value = "z-a"
  for (name, items) in [("fields", [literal, range, either, group, character]), ("empty", []), ("maximum", Array(repeating: literal, count: 40).map { value in var item = RegexWorkbench.Part(); item.kind = value.kind; item.value = value.value; return item }), ("invalid", [invalid])] {
    let size = NSSize(width: 400, height: 600)
    let host = NSHostingView(rootView: ThemeRoot(override: VisualTheme.allCases[0], windowTitle: name) {
      RegexBuilderView(initialParts: items)
    }.defaultAppStorage(defaults))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
    precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
    print("PASS \(name)")
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip")
 }
}
