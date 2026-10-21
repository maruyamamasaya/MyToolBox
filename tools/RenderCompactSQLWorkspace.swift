import AppKit
import SwiftUI
@main struct RenderCompactSQLWorkspace {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.sql.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/sql-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  var models: [(String, SQLWorkspaceModel)] = []
  for mode in SQLWorkspaceModel.Mode.allCases {
   let model = SQLWorkspaceModel(); model.mode = mode
   model.reset(); try await wait(model)
   if mode == .playground {
    model.input = "CREATE TABLE compact_probe (value TEXT); INSERT INTO compact_probe VALUES ('保持');"
    model.run(); try await wait(model)
    precondition(model.error.isEmpty)
   }
   model.input = SQLMemoryDatabase.sampleQuery
   model.run(); try await wait(model)
   precondition(model.error.isEmpty && !model.copyText.isEmpty)
   if mode == .playground { precondition(model.results.first?.rows.count == 2) }
   models.append((mode == .format ? "format" : mode == .explain ? "explain" : "execute", model))
  }
  let failed = SQLWorkspaceModel(); failed.mode = .playground; failed.reset(); try await wait(failed)
  failed.input = "SELECT missing FROM employees;"; failed.run(); try await wait(failed)
  precondition(!failed.error.isEmpty); models.append(("error", failed))
  defer { for (_, model) in models { model.stop() } }
  for theme in VisualTheme.allCases {
   for (name, model) in models {
    let source = model.input, copied = model.copyText, schema = model.schema.map { $0.rows }
    for expanded in [false, true, false] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "SQLツール") {
      SQLWorkspaceView(model: model, initiallyExpanded: expanded)
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
     precondition(model.input == source && model.copyText == copied && model.schema.map { $0.rows } == schema)
     print("PASS \(theme.rawValue) \(name) expanded=\(expanded)")
    }
   }
  }
  let execution = models.first { $0.0 == "execute" }!.1
  execution.input = "SELECT value FROM compact_probe;"; execution.run(); try await wait(execution)
  precondition(execution.results.first?.rows == [["保持"]])
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 600), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 600); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip / real model output and memory DB preserved")
 }
 @MainActor static func wait(_ model: SQLWorkspaceModel) async throws {
  for _ in 0..<400 { if !model.busy { return }; try await Task.sleep(for: .milliseconds(10)) }
  throw ToolFailure.message("SQL model timeout")
 }
}
