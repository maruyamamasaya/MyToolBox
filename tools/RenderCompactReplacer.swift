import AppKit
import SwiftUI
@main struct RenderCompactReplacer {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.replacer.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/replacer-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["search", "replace", "delete", "rules", "invalid"] {
    let model = ReplacerModel()
    model.options.mode = state == "replace" ? .replace : state == "delete" ? .delete : state == "rules" ? .rules : .search
    model.input = "apple banana\napple orange"
    model.options.query = state == "invalid" ? "[" : "apple"
    model.options.replacement = "りんご"
    model.options.rules = "apple => りんご\nbanana => バナナ"
    model.options.regex = state == "invalid"
    model.run()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "検索・置換") { ReplacerView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 360, height: theme == .windows98 ? 470 : 440)
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
