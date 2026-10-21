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
  let start = Date()
  model.configure(work: 1, rest: 1)
  model.toggle(at: start)
  model.tick(start.addingTimeInterval(60))
  precondition(model.isBreak && model.completed == 1 && model.breakCelebrationAt == nil)
  model.toggle(at: start.addingTimeInterval(61))
  let celebration = model.breakCelebrationAt
  precondition(celebration != nil)
  model.toggle(at: start.addingTimeInterval(62))
  model.toggle(at: start.addingTimeInterval(63))
  precondition(model.breakCelebrationAt == celebration, "Resume must not repeat fireworks")
  model.tick(start.addingTimeInterval(123))
  precondition(!model.isBreak && model.breakFinishedAt != nil && model.breakCelebrationAt == nil)
  model.reset()
  precondition(model.breakFinishedAt == nil && model.breakCelebrationAt == nil)
  model.breakEffects = false
  let restored = FocusTimerModel(pomodoro: true, defaults: defaults)
  precondition(!restored.breakEffects && !restored.breakSound)
  restored.stop()
  model.breakEffects = true
  print("PASS break lifecycle, resume, reset, isolated preferences")
  for theme in VisualTheme.allCases {
   for state in ["ready", "running", "paused", "break", "resting", "finished", "effects-off", "long"] {
    model.configure(work: state == "long" ? 180 : 25, rest: 5)
    if state == "running" || state == "paused" { model.toggle() }
    if state == "paused" { model.toggle() }
    model.breakEffects = state != "effects-off"
    if ["break", "resting", "finished", "effects-off"].contains(state) {
     let date = Date()
     model.toggle(at: date.addingTimeInterval(-1501))
     model.tick(date)
     model.toggle(at: date.addingTimeInterval(state == "resting" ? -4 : -0.8))
     model.tick(date)
     if state == "finished" { model.timer.elapsed = model.timer.duration; model.tick(date) }
    }
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
