import AppKit
import SwiftUI
@main struct RenderCompactTimeCalculator {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.timecalc.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/time-calculator-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["work", "multiple", "overnight", "invalid", "invalid-multiple"] {
    let view = TimeCalculatorView(multiple: state == "multiple" || state == "invalid-multiple",
      start: state == "overnight" ? "23:00" : state == "invalid" ? "bad" : "09:15",
      end: state == "overnight" ? "02:00" : "18:30",
      ranges: state == "invalid-multiple" ? "bad" : "09:00 - 10:30\n11:15 - 12:00\n13:00 - 16:45")
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "時間計算") { view }.defaultAppStorage(defaults))
    let height = state == "multiple" || state == "invalid-multiple" ? 360 : 320
    let size = NSSize(width: 300, height: CGFloat(height + (theme == .windows98 ? 30 : 0)))
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
