import AppKit
import SwiftUI
@main struct VerifyLargeCSVViews {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.csv.large.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/csv-large-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: temporary) }
  let rows = [["名前", "数量", "メモ"], ["りんご", "3", "青森"], ["みかん", "5", "愛媛"]]
  let inputURL = temporary.appendingPathComponent("source.csv")
  try CSVDocument.encoded(rows).write(to: inputURL)
  let viewer = CSVModel(editable: false), editor = CSVModel(editable: true)
  viewer.read(inputURL); editor.read(inputURL)
  try await wait(viewer); try await wait(editor)
  precondition(viewer.rows == rows && editor.rows == rows)
  viewer.search = "りんご"; precondition(viewer.indices == [1]); viewer.search = ""
  viewer.sort(1); precondition(viewer.indices == [1,2]); viewer.sort(1); precondition(viewer.indices == [2,1]); viewer.sort(1)
  editor.edit(row: 1, column: 2, value: "日本語,と\"引用符\"\n改行")
  let edited = editor.rows, savedURL = temporary.appendingPathComponent("edited.csv")
  editor.save(to: savedURL)
  let reopened = try CSVDocument.parse(CSVDocument.decode(Data(contentsOf: savedURL)).0)
  precondition(reopened == edited && !editor.dirty)
  editor.edit(row: 2, column: 1, value: "6")
  precondition(!editor.confirmClose(decideDiscard: { false }))
  editor.selectedRow = 1; editor.selectedColumn = 2; editor.input = "名前,数量\nぶどう,8"
  let original = try Data(contentsOf: inputURL)
  for theme in VisualTheme.allCases {
   for model in [viewer, editor] {
    let data = model.rows, dirty = model.dirty
    for paste in [false, true] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: model.editable ? "CSVエディター" : "CSVビューワー") {
      CSVToolView(model: model, initiallyShowingPaste: paste)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: 1440, height: theme == .windows98 ? 1030 : 1000)
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(200)); host.layoutSubtreeIfNeeded()
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(model.editable ? "editor" : "viewer")-\(paste ? "paste" : "table").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height && model.rows == data && model.dirty == dirty)
     print("PASS \(theme.rawValue) editor=\(model.editable) paste=\(paste)")
    }
   }
  }
  let sourceAfter = try Data(contentsOf: inputURL); precondition(sourceAfter == original)
  precondition(CSVToolView.gridHeight(viewportHeight: 1200, editable: false, pasteVisible: false, cellEditorVisible: false) > CSVToolView.gridHeight(viewportHeight: 900, editable: false, pasteVisible: false, cellEditorVisible: false))
  print("PASS real read/search/sort/edit/save/reopen, dirty close guard, source preserved and viewport growth")
 }
 @MainActor static func wait(_ model: CSVModel) async throws {
  for _ in 0..<200 { if !model.busy { return }; try await Task.sleep(for: .milliseconds(10)) }
  throw ToolFailure.message("CSV model timeout")
 }
}
