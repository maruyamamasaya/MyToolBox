import AppKit
import SwiftUI
@main struct RenderCompactSimpleCalculator {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.simple.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/simple-calculator-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["standard", "parentheses", "large", "invalid", "zero-division"] {
    let expression = state == "parentheses" ? "(20 + 5) × 4" : state == "large" ? "1e100 * 2" : state == "invalid" ? "abc" : state == "zero-division" ? "1 / 0" : "1000 + 250 × 2"
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "シンプル電卓") {
     CompactSimpleCalculatorView(expression: expression)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 300, height: theme == .windows98 ? 270 : 240)
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
