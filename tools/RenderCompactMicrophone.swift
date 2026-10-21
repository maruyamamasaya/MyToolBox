import AppKit
import SwiftUI
@main struct RenderCompactMicrophone {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.mic.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/microphone-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["idle", "pending", "input", "recording", "recorded", "error"] {
    let model = MicrophoneModel(); model.devices = []
    defer { model.stop(clear: true) }
    // UI fixtures only. Never calls start/record/play, requests access or opens an audio engine.
    if state != "idle" { model.status = "描画用の合成状態（実収録なし）" }
    if state == "pending" { model.pending = true }
    if state == "input" || state == "recording" {
     model.running = true; model.level = 0.126; model.decibels = "−18.0 dBFS"
    }
    if state == "recording" { model.recording = true; model.elapsed = 4.2 }
    if state == "recorded" { model.hasRecording = true; model.elapsed = 10 }
    if state == "error" { model.status = "描画用：マイクへのアクセスが拒否されました。システム設定で確認してください。" }
    let running = model.running, recording = model.recording, recorded = model.hasRecording, elapsed = model.elapsed
    for expanded in [false, true, false] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "マイクチェック") {
      MicrophoneCheckView(model: model, initiallyExpanded: expanded)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 400, height: (expanded ? 850 : 500) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(state)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
     precondition(model.running == running && model.recording == recording && model.hasRecording == recorded && model.elapsed == elapsed)
     print("PASS synthetic \(theme.rawValue) \(state) expanded=\(expanded)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 400, height: 500); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native window roundtrip; NO capture, playback, permission request")
 }
}
