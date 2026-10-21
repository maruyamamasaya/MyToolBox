import AppKit
import SwiftUI
@main struct RenderCompactLinuxCommands {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.linux.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/linux-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defaults.set("[\"ls\",\"grep\"]", forKey: "tools.linuxCommands.favorites.v1")
  defaults.set("[\"ssh\",\"ls\"]", forKey: "tools.linuxCommands.history.v1")
  precondition(CommandReference.entries.count >= 165)
  precondition(CommandReference.entries.contains { $0.matches("ｓｓｈ") })
  let cases = [("list", "", "ls", 0), ("search", "ネットワーク", "ip", 0), ("detail", "ssh", "ssh", 1), ("empty", "no_such_command_938572", "ls", 0)]
  for theme in VisualTheme.allCases {
   for (name, query, selected, tab) in cases {
    for expanded in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "Linuxコマンド辞典") {
      LinuxCommandView(initiallyExpanded: expanded, initialQuery: query, initialSelection: selected, initialDetailTab: tab)
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
  precondition(defaults.string(forKey: "tools.linuxCommands.favorites.v1") == "[\"ls\",\"grep\"]")
  precondition(defaults.string(forKey: "tools.linuxCommands.history.v1") == "[\"ssh\",\"ls\"]")
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 420, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / actual command search / isolated favorites and history preserved")
 }
}
