import AppKit
import SwiftUI
@main struct RenderCompactMeeting {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.meeting.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/meeting-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let model = FocusTimerModel(pomodoro: false, defaults: defaults)
  defer { model.stop() }
  for theme in VisualTheme.allCases {
   for state in ["ready", "running", "paused", "finished", "custom", "zero", "long"] {
    model.reset()
    model.timer.duration = state == "custom" ? 75 : state == "zero" ? 0 : state == "long" ? 359999 : 1800
    if state == "running" || state == "paused" || state == "finished" { model.toggle() }
    if state == "paused" { model.toggle() }
    if state == "finished" { model.tick(Date().addingTimeInterval(1801)) }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "会議タイマー") { FocusTimerView(model: model) }.defaultAppStorage(defaults))
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
