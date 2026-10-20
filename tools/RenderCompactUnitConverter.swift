import AppKit
import SwiftUI
@main struct RenderCompactUnitConverter {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.unit.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/unit-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for group in EverydayCalculators.unitGroups.indices {
    let state = String(group)
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "単位変換") {
     CompactUnitConverterView(group: group, value: "100", rate: group == 9 ? "0.0067" : "")
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 370 : 340)
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
