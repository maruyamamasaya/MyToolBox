import AppKit
import SwiftUI
@main struct RenderCompactNumberSummary {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.summary.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/number-summary-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["ready", "standard", "ignored", "invalid", "overflow"] {
    let numbers = state == "ignored" ? "11 19 38 42 46 invalid NaN" : state == "invalid" ? "abc" : state == "overflow" ? "1e308 1e308" : "11\n19\n38\n42\n46"
    let summary: Result<EverydayCalculators.Summary, Error>? = state == "ready" ? nil : Result { try EverydayCalculators.summarize(numbers) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "数値集計") {
     CompactNumberSummaryView(numbers: numbers, summary: summary)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 410 : 380)
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
