import AppKit
import SwiftUI
@main struct RenderCompactColorPalette {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.ua.redesign.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/palette-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defaults.set("#4CAF50 緑\n#833AB4 紫", forKey: "tools.colorPalette.notes.v1")
  for theme in VisualTheme.allCases {
   for tab in 0...2 {
    for expanded in [false, true] {
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "カラーパレット") {
     ColorPaletteView(initiallyExpanded: expanded, initialTab: tab)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: expanded ? 1100 : 380, height: (expanded ? 850 : 560) + (theme == .windows98 ? 30 : 0))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(tab)-\(expanded ? "expanded" : "compact").png"))
    precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
    print("PASS \(theme.rawValue) tab=\(tab) expanded=\(expanded)")
    }
   }
  }
  precondition(defaults.string(forKey: "tools.colorPalette.notes.v1") == "#4CAF50 緑\n#833AB4 紫")
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 560), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 380, height: 560); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / isolated notes preserved")
 }
}
