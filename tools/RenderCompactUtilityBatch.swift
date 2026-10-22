import AppKit
import SwiftUI

@main struct RenderCompactUtilityBatch {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.compact.utility-batch.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/compact-utility-batch")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let git = GitBatchModel(defaults: defaults)
  git.root = "/Example/Development"
  var row = GitRepositoryStatus(path: "/Example/Development/My Project")
  row.branch = "main"; row.ahead = 1; row.behind = 0; row.result = "差分あり"
  row.changes = " M example.txt\n?? new.txt"; row.detail = "描画用の合成データ・通信なし"
  git.rows = [row]; git.selected = [row.path]; git.status = "描画用：1件を読み込みました"
  let audit = ShortcutAuditModel()
  audit.rows = [
   .init(owner: "macOS", action: "描画用：システム操作", keyCode: 40, modifiers: 256, global: true, source: "合成データ", availability: .configured),
   .init(owner: "Example App", action: "描画用：メニューの操作", keyCode: 40, modifiers: 256, global: false, source: "合成データ", availability: .enabled),
   .init(owner: "Example App", action: "描画用：今は使用できない操作", keyCode: 8, modifiers: 256, global: false, source: "合成データ", availability: .disabled)]
  audit.coverage = ["描画用：実際のアプリ取得は実施していません。"]
  audit.checkedAt = Date()
  let ua = UserAgentModel(automaticallyLoads: false)
  ua.userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
  ua.fields = [("ブラウザ環境", "描画用：内蔵WebKit"), ("CPU論理コア数", "取得不可")]
  ua.busy = false; ua.status = "描画用の合成データ"
  for theme in VisualTheme.allCases {
   for expanded in [false, true, false] {
    for name in ["user-agent", "user-agent-details", "user-agent-inspect", "shortcut-audit", "git-batch", "git-batch-busy"] {
     let view: AnyView
     if name.hasPrefix("user-agent") { view = AnyView(UserAgentView(model: ua, initialTab: name == "user-agent-details" ? 1 : name == "user-agent-inspect" ? 2 : 0, initialPasted: ua.userAgent, initiallyExpanded: expanded)) }
     else if name == "shortcut-audit" { view = AnyView(ShortcutAuditView(model: audit, initiallyExpanded: expanded)) }
     else { git.busy = name == "git-batch-busy"; view = AnyView(GitBatchView(model: git, initiallyExpanded: expanded)) }
     let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: name) { view }.defaultAppStorage(defaults))
     let size = NSSize(width: expanded ? 1100 : name.hasPrefix("git-batch") ? 480 : name.hasPrefix("user-agent") ? 440 : 460,
                       height: (expanded ? 850 : name.hasPrefix("git-batch") ? 600 : 560) + (theme == .windows98 ? 30 : 0))
     let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
     window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
     window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
     precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height, "\(name) \(host.fittingSize)")
     let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
     host.cacheDisplay(in: host.bounds, to: rep)
     try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(theme.rawValue)-\(name)-\(expanded ? "expanded" : "compact").png"))
     precondition(git.selected == [row.path] && git.rows.count == 1 && audit.rows.count == 3 && !ua.userAgent.isEmpty)
     print("PASS synthetic \(theme.rawValue) \(name) expanded=\(expanded)")
     git.busy = false
    }
   }
  }
  for compact in [NSSize(width: 440, height: 560), NSSize(width: 460, height: 560), NSSize(width: 480, height: 600)] {
   let window = NSWindow(contentRect: NSRect(origin: .zero, size: compact), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
   let bridge = ExpandableToolWindowSizing.Host(frame: .zero)
   bridge.compactSize = compact; window.contentView = bridge; bridge.apply()
   let initial = window.contentLayoutRect.size
   bridge.expanded = true; bridge.apply(); precondition(window.contentLayoutRect.width > initial.width)
   bridge.expanded = false; bridge.apply(); precondition(window.contentLayoutRect.size == initial)
  }
  git.busy = true; precondition(!git.canClose); git.busy = false; precondition(git.canClose)
  print("PASS preserved models and busy close guard; no scan, Git operation or clipboard access")
 }
}
