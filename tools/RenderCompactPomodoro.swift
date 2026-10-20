import AppKit
import SwiftUI
@main struct RenderCompactPomodoro {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.pomodoro.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/pomodoro-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let model = FocusTimerModel(pomodoro: true, defaults: defaults)
  defer { model.stop() }
  for theme in VisualTheme.allCases {
   for state in ["ready", "running", "paused", "break", "long"] {
    model.configure(work: state == "long" ? 180 : 25, rest: 5)
    if state == "running" || state == "paused" { model.toggle() }
    if state == "paused" { model.toggle() }
    if state == "break" { model.toggle(); model.tick(Date().addingTimeInterval(1501)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ポモドーロタイマー") { FocusTimerView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 260, height: theme == .windows98 ? 240 : 210)
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
