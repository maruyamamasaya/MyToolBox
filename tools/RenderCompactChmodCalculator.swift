import AppKit
import SwiftUI
@main struct RenderCompactChmodCalculator {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.chmod.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/chmod-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for value in 0...0o7777 {
    let permission = try ServerUtilities.permission(String(format: "%04o", value))
    let reopened = try ServerUtilities.permission(permission.symbolic); precondition(reopened.value == value)
  }
  let cases = [("checker", false, "755"), ("generator", true, "755"), ("special", true, "4755"), ("sticky", true, "1777"), ("invalid", false, "888")]
  for theme in VisualTheme.allCases {
   for (name, generating, input) in cases {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "chmod計算") {
      ChmodCalculatorView(initiallyExpanded: expanded, initiallyGenerating: generating, initialCheckerInput: input, initialGeneratorInput: input)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
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
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / 4096 actual permission roundtrips, no file permission changes")
 }
}
