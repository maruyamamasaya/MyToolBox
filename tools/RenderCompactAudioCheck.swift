import AppKit
import SwiftUI
@main struct RenderCompactAudioCheck {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.audio.compact.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/audio-compact-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  for theme in VisualTheme.allCases {
   for state in ["idle", "playing", "error"] {
    let model = SpeakerModel(); model.devices = []
    defer { model.stop() }
    if state == "playing" { model.playing = true; model.status = "描画用の合成再生状態（音出しなし）" }
    if state == "error" { model.status = "描画用：ステレオ出力を利用できません。出力装置を確認してください。" }
    let playing = model.playing, volume = model.volume
    for expanded in [false, true, false] {
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "オーディオチェック") {
      AudioCheckView(model: model, initiallyExpanded: expanded)
     }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : 420, height: (expanded ? 850 : 400) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(150)); host.layoutSubtreeIfNeeded()
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(state)-\(expanded ? "expanded" : "compact").png"))
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height && model.playing == playing && model.volume == volume)
     print("PASS synthetic \(theme.rawValue) \(state) expanded=\(expanded)")
    }
   }
  }
  let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 400), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
  let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
  bridge.compactSize = NSSize(width: 420, height: 400); window.contentView = bridge
  bridge.apply(); let compact = window.contentLayoutRect.size
  bridge.expanded = true; bridge.apply(); let large = window.contentLayoutRect.size
  bridge.expanded = false; bridge.apply()
  precondition(compact == window.contentLayoutRect.size && large.width > compact.width)
  print("PASS native size roundtrip; NO sound playback")
 }
}
