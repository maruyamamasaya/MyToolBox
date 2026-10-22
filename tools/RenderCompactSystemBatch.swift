import AppKit
import SwiftUI
import Carbon

@MainActor private final class NoSystemKeys: WindowManagerShortcutRegistration {
 func register(keyCodes: [UInt32], onPress: @escaping (Int) -> Void) -> (Int, OSStatus)? { fatalError("Probe must not register keys") }
 func unregister() {}
}
@main struct RenderCompactSystemBatch {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.compact.system.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/compact-system-batch")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let manager = WindowManagerModel(defaults: defaults, registration: NoSystemKeys(), trustReader: { true }, trackApplications: false, applyOverride: { _ in })
  manager.targetName = "描画用：Example App"
  defer { manager.stop() }
  for theme in VisualTheme.allCases {
   for expanded in [false, true, false] {
    for name in ["window-manager", "video", "video-busy", "server", "server-diagnostics", "server-empty"] {
     let video = VideoCompressorModel()
     video.load([URL(fileURLWithPath: "/Example/描画用の動画.mov")]); video.status = "描画用：選択済み"
     if name == "video-busy" { video.busy = true; video.progress = 0.42; video.status = "描画用：圧縮中（実変換なし）" }
     else { video.results = ["描画用：保存結果 · 100 MB → 60 MB（40%削減）"] }
     let server = ServerManagementModel()
     if name != "server-empty" {
      server.rows = ServerCheck.allCases.map { .init(item: $0, state: .confirmed, detail: "描画用の合成結果。実サーバーの取得は行っていません。", checkedAt: Date()) }
     }
     let view: AnyView
     if name == "window-manager" { view = AnyView(WindowManagerView(model: manager, initiallyExpanded: expanded)) }
     else if name.hasPrefix("video") { view = AnyView(VideoCompressorView(model: video, initiallyExpanded: expanded)) }
     else { view = AnyView(ServerManagementView(model: server, initiallyShowsDiagnostics: name == "server-diagnostics", initiallyShowsMusicDiagnostics: name == "server-diagnostics", refreshOnAppear: false)) }
     let size = NSSize(width: expanded ? 1100 : name.hasPrefix("video") ? 440 : 460,
                       height: (expanded ? 850 : name == "window-manager" ? 620 : name.hasPrefix("video") ? 540 : 640) + (theme == .windows98 ? 30 : 0))
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: name) { view }.defaultAppStorage(defaults))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height, "\(name) \(host.fittingSize)")
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(name)-\(expanded ? "expanded" : "compact").png"))
     precondition(video.urls.count == 1 && video.busy == (name == "video-busy") && server.rows.count == (name == "server-empty" ? 0 : 8))
     print("PASS synthetic \(theme.rawValue) \(name) expanded=\(expanded)")
    }
   }
  }
  for size in [NSSize(width: 460, height: 620), NSSize(width: 440, height: 540), NSSize(width: 460, height: 640)] {
   let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
   let bridge = ExpandableToolWindowSizing.Host(frame: .zero); bridge.compactSize = size; window.contentView = bridge; bridge.apply()
   let initial = window.contentLayoutRect.size; bridge.expanded = true; bridge.apply(); precondition(window.contentLayoutRect.width > initial.width)
   bridge.expanded = false; bridge.apply(); precondition(window.contentLayoutRect.size == initial)
  }
  print("PASS native size roundtrip; no OS keys, AX writes, server requests or video conversion")
 }
}
