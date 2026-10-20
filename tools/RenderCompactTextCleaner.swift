import AppKit
import SwiftUI
@main struct RenderCompactTextCleaner {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.cleaner.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/cleaner-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["clean", "visualize", "inspect", "empty"] {
    let model = TextTransformModel(cleaner: true)
    model.cleanerMode = state == "visualize" ? "可視化" : state == "inspect" ? "文字チェック" : "クリーニング"
    model.input = state == "empty" ? "" : "Hello\u{200B}　世界\n\n・\n項目\t確認"
    model.update()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "テキストクリーナー") { TextCleanerView(model: model) }.defaultAppStorage(defaults))
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
