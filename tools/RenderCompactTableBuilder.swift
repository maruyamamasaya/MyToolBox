import AppKit
import SwiftUI
@main struct RenderCompactTableBuilder {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.table.builder.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/table-builder-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let model = CSVModel(editable: true)
  model.rows = [["項目", "数量", "メモ"], ["りんご", "3", "青森"], ["みかん", "5", "愛媛"]]
  model.edit(row: 1, column: 2, value: "引用符\"と,カンマ\n改行")
  let saved = model.rows
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  for format in SmallDataTools.Format.allCases {
    let output = SmallDataTools.export(saved, format: format, header: true, alignment: .left)
    let url = directory.appendingPathComponent(format.rawValue)
    try output.write(to: url, atomically: true, encoding: .utf8)
    let loaded = try String(contentsOf: url, encoding: .utf8); precondition(loaded == output)
    if format == .csv { let reopened = try SmallDataTools.tableCSV(Data(contentsOf: url)); precondition(reopened == saved) }
  }
  for theme in VisualTheme.allCases {
   for format in SmallDataTools.Format.allCases {
    for expanded in [false, true, false] {
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "表ビルダー") {
     TableBuilderView(model: model, initiallyExpanded: expanded, initialFormat: format)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: expanded ? 1100 : 420, height: (expanded ? 850 : 600) + (theme == .windows98 ? 30 : 0))
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(format.rawValue)-\(expanded ? "expanded" : "compact").png"))
    precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
    print("PASS \(theme.rawValue) format=\(format.rawValue) expanded=\(expanded)")
    }
   }
  }
  precondition(model.rows == saved && model.dirty)
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 420, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / edited data preserved / 3 file formats roundtrip")
 }
}
