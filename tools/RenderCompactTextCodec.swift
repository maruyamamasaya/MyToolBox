import AppKit
import SwiftUI
@main struct RenderCompactTextCodec {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.codec.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/codec-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["encode", "decode", "escape", "restore", "invalid"] {
    let model = TextCodecModel()
    model.mode = state == "decode" || state == "invalid" ? .base64Decode : state == "escape" ? .escape : state == "restore" ? .restore : .base64Encode
    model.input = state == "decode" ? "SGVsbG8sIOS4lueVjA==" : state == "invalid" ? "!!!!" : state == "restore" ? "Hello\\nWorld" : "Hello, 世界\n"
    model.update()
    while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "テキスト変換") { TextCodecView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 390 : 360)
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
