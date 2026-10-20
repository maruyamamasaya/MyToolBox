import AppKit
import SwiftUI
@main struct RenderCompactNumberBase {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.base.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/base-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["decimal", "hex", "zero", "large", "invalid", "base60"] {
    let input = state == "hex" ? "-0xff" : state == "zero" ? "0" : state == "large" ? String(repeating: "9", count: 200) : state == "invalid" ? "1.5" : state == "base60" ? "a" : "255"
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "進数変換") {
     CompactNumberBaseConverterView(input: input, sourceBase: state == "hex" ? 16 : state == "base60" ? 60 : 10, targetBase: 8)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 390 : 360)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + "-" + state + ".png"))
    print("PASS \(theme.rawValue) \(state) fitting \(host.fittingSize)")
   }
  }
 }
}
