import AppKit
import SwiftUI
@main struct RenderCompactTimerBoard {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.board.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/timer-board-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let model = TimerBoardModel(defaults: defaults)
  defer { model.stop() }
  for theme in VisualTheme.allCases {
   for state in ["empty", "three", "twelve"] {
    model.timers = []; model.message = ""
    let count = state == "empty" ? 0 : state == "three" ? 3 : 12
    for i in 0..<count {
     model.add()
     model.timers[i].name = i == 2 ? "ストップウォッチ" : "タイマー \(i + 1)"
     model.timers[i].duration = Double((i + 1) * 300)
     if i == 1 { model.toggle(i) }
     if i == 2 { model.timers[i].countdown = false; model.timers[i].elapsed = 90 }
    }
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "タイマーボード") { TimerBoardView(model: model) }.defaultAppStorage(defaults))
    let size = NSSize(width: 320, height: theme == .windows98 ? 310 : 280)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
    host.cacheDisplay(in: host.bounds, to: rep)
    try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + "-" + state + ".png"))
    print("PASS \(theme.rawValue) \(state) fitting \(host.fittingSize)")
   }
  }
  model.save()
  let restored = TimerBoardModel(defaults: defaults)
  defer { restored.stop() }
  guard restored.timers.map(\.id) == model.timers.map(\.id) else { fatalError("restore") }
  model.duplicate(0); guard model.timers.count == 12 else { fatalError("limit") }
  model.remove(11); model.duplicate(0); model.move(0, by: 1)
  guard Set(model.timers.map(\.id)).count == 12 else { fatalError("duplicate identity") }
  model.pauseAll(); model.resetAll(finishedOnly: false)
  guard model.timers.allSatisfy({ $0.startedAt == nil && $0.elapsed == 0 }) else { fatalError("pause/reset") }
  print("PASS restore / limit / remove / duplicate / reorder / pause / reset")
 }
}
