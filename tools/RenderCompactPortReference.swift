import AppKit
import SwiftUI
@main struct RenderCompactPortReference {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.port.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/port-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["all", "https", "udp", "database", "empty"] {
    let query = state == "https" ? "443" : state == "database" ? "database" : state == "empty" ? "not-a-service" : ""
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ポート番号検索") {
     CompactPortReferenceView(query: query, transport: state == "udp" ? "UDP" : "all")
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
