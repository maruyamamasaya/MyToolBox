import AppKit
import SwiftUI
@main struct RenderCompactClipboard {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.clipboard.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/clipboard-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let table = ClipboardFormatterModel()
  let list = ListConverterModel()
  defer { table.stop(); list.stop() }
  table.input = "名前\t個数\nりんご\t3\nみかん\t2"
  table.parse()
  while table.busy { try await Task.sleep(for: .milliseconds(10)) }
  table.table.rows[1][0] = "ぶどう"
  try await Task.sleep(for: .milliseconds(200))
  while table.busy { try await Task.sleep(for: .milliseconds(10)) }
  guard table.output.contains("ぶどう") else { fatalError("table edit output") }
  list.input = "りんご\nみかん\nりんご"; list.update()
  while list.busy { try await Task.sleep(for: .milliseconds(10)) }
  let savedRows = table.table.rows, savedOutput = table.output, savedList = list.output
  for theme in VisualTheme.allCases {
   for listMode in [false, true] {
    for expanded in [false, true, false] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "クリップボード整形") {
      ClipboardWorkspaceView(table: table, list: list, listMode: listMode, initiallyExpanded: expanded)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 360, height: (expanded ? 850 : 520) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
     guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + (listMode ? "-list" : "-table") + (expanded ? "-expanded" : "-compact") + ".png"))
     guard table.table.rows == savedRows, table.output == savedOutput, list.output == savedList else { fatalError("content lost on resize") }
     print("PASS \(theme.rawValue) list=\(listMode) expanded=\(expanded) fitting \(host.fittingSize)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 360,height: 520), styleMask: [.titled,.resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  window.contentView = bridge
  bridge.expanded = false; bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let expanded = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  guard window.contentLayoutRect.size == compact, expanded.width > compact.width else { fatalError("resize roundtrip") }
  print("PASS native hidden resize roundtrip; table edits and both models retained")
 }
}
