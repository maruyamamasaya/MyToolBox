import AppKit
import SwiftUI
@main struct RenderCompactSLA {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.sla.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/sla-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["standard", "five-nines", "full", "zero", "invalid", "outside"] {
    let rate = state == "five-nines" ? "99.999" : state == "full" ? "100" : state == "zero" ? "0" : state == "invalid" ? "abc" : state == "outside" ? "100.1" : "99.9"
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "SLA計算") {
     CompactSLACalculatorView(rate: rate)
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
