import AppKit
import SwiftUI
@main struct VerifyCompactDirectoryTree {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.tree.drag.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let model = DirectoryTreeModel(defaults: defaults)
  let a = DirectoryTree.Node(name: "project")
  var nested = DirectoryTree.Node(name: "src", depth: 1); nested.open = false
  let leaf = DirectoryTree.Node(name: "main.swift", folder: false, depth: 2)
  let b = DirectoryTree.Node(name: "docs")
  let file = DirectoryTree.Node(name: "README.md", folder: false, depth: 1)
  let original = [a, nested, leaf, b, file]
  model.commit(original)
  precondition(!model.canDrop(source: a.id, target: leaf.id, placement: .inside))
  precondition(!model.canDrop(source: nested.id, target: file.id, placement: .inside))
  precondition(!model.canDrop(source: nested.id, target: nested.id, placement: .before))
  precondition(!model.visibleNodes.contains { $0.id == leaf.id })
  model.drop(source: nested.id, target: b.id, placement: .inside)
  precondition(model.error == nil && model.nodes.map(\.id) == [a.id, b.id, file.id, nested.id, leaf.id])
  precondition(model.nodes.last?.depth == 2 && model.selected == nested.id)
  model.history(redo: false); precondition(model.nodes == original)
  model.history(redo: true); precondition(model.nodes.last?.id == leaf.id)
  model.dropToRoot(source: nested.id)
  precondition(model.nodes.suffix(2).map(\.depth) == [0, 1])
  precondition(DirectoryTreeModel(defaults: defaults).nodes == model.nodes)
  model.history(redo: false); precondition(model.nodes.suffix(2).map(\.depth) == [1, 2])
  model.commit(original)
  model.drop(source: b.id, target: a.id, placement: .before)
  precondition(model.nodes.map(\.id) == [b.id, file.id, a.id, nested.id, leaf.id])
  model.drop(source: b.id, target: a.id, placement: .after)
  precondition(model.nodes == original)
  var deep = (0...50).map { DirectoryTree.Node(name: "d\($0)", depth: $0) }
  let extra = DirectoryTree.Node(name: "extra"); deep.append(extra); model.commit(deep)
  precondition(!model.canDrop(source: extra.id, target: deep[50].id, placement: .inside))
  precondition(DirectoryTreeDrop.position(y: 5, folder: true) == .before)
  precondition(DirectoryTreeDrop.position(y: 20, folder: true) == .inside)
  precondition(DirectoryTreeDrop.position(y: 35, folder: true) == .after)
  precondition(DirectoryTreeDrop.position(y: 20, folder: false) == .after)
  model.commit(DirectoryTree.sample); model.discloseAll(true)
  let saved = model.nodes
  let folder = URL(fileURLWithPath: "build/tree-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for tab in 0...1 {
    for expanded in [false, true, false] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ディレクトリツリー") {
      DirectoryTreeView(defaults: defaults, model: model, initiallyExpanded: expanded, initialTab: tab)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 440, height: (expanded ? 850 : 640) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(tab)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height && model.nodes == saved)
     print("PASS \(theme.rawValue) tab=\(tab) expanded=\(expanded)")
    }
   }
  }
  for format in DirectoryTree.Format.allCases { let rendered = try DirectoryTree.render(model.nodes, format: format); precondition(!rendered.isEmpty) }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 640), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 440, height: 640); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS subtree moves, cycles/file/depth rejection, root drop, undo/redo, persistence, seven formats and window roundtrip")
 }
}
