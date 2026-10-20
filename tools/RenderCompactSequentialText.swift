import AppKit
import SwiftUI
@main struct RenderCompactSequentialText {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.sequential.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/sequential-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["standard", "negative", "end", "invalid", "empty"] {
    let model = TextTransformModel()
    model.start = state == "negative" ? "-3" : state == "invalid" ? "abc" : "1"
    model.options.atEnd = state == "end"
    model.options.digits = state == "negative" ? 3 : 1
    model.input = state == "empty" ? "" : "りんご\nみかん\n\nぶどう"
    model.update()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "連番テキスト生成") { SequentialTextView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 340, height: theme == .windows98 ? 390 : 360)
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
