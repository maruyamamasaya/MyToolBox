import AppKit
import SwiftUI
@main struct RenderCompactHash {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.hash.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/hash-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["empty", "sha256", "sha512", "base64", "error"] {
    let model = GeneratorModel()
    let algorithm: TextHash.Algorithm = state == "sha512" ? .sha512 : .sha256
    if state != "empty" {
     model.generate {
      try TextHash.generate(state == "error" ? String(repeating: "a", count: 1_048_577) : "abc", algorithm: algorithm, base64: state == "base64")
     }
     while model.busy { try await Task.sleep(for: .milliseconds(10)) }
    }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ハッシュ生成") {
     HashGeneratorView(model: model, input: state == "empty" ? "" : "abc", algorithm: algorithm, base64: state == "base64")
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 390 : 360)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + "-" + state + ".png"))
    print("PASS \(theme.rawValue) \(state) fitting \(host.fittingSize)")
    model.clear()
   }
  }
 }
}
