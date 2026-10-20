import AppKit
import SwiftUI
@main struct RenderCompactLineTools {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.lines.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/lines-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["sort", "filter", "duplicates", "empty"] {
    let model = LineToolModel()
    model.mode = state == "filter" ? .filter : state == "duplicates" ? .duplicates : .sort
    model.input = state == "empty" ? "" : "item10\nitem2\nitem1\nitem2"
    if state == "filter" { model.filter.conditions[0].value = "2" }
    model.update()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "行ツール") { LineToolsView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 360, height: theme == .windows98 ? 430 : 400)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + "-" + state + ".png"))
    print("PASS \(theme.rawValue) \(state) fitting \(host.fittingSize)")
    model.stop()
   }
  }
 }
}
