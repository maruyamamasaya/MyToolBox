import AppKit
import SwiftUI
@main struct RenderUserAgentRedesign {
 @MainActor static func main() async throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let suite = "test.ua.redesign.\(UUID().uuidString)"
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let folder = URL(fileURLWithPath: "build/user-agent-redesign-preview")
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)"
  let pasted = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1"
  for theme in VisualTheme.allCases {
   for state in ["overview", "details", "inspect", "loading", "failed", "oversize"] {
    let model = UserAgentModel(automaticallyLoads: false)
    model.userAgent = state == "loading" || state == "failed" ? "" : ua
    model.busy = state == "loading"
    model.status = state == "loading" ? "取得中…" : state == "failed" ? "取得失敗：検証用のエラー" : "更新しました"
    model.fields = model.userAgent.isEmpty ? [] : [
      ("ブラウザ環境", "MyToolBox 内蔵WebKit"), ("UAのブラウザ表記", UserAgentInfo(ua).browser),
      ("UAのOS表記", UserAgentInfo(ua).os), ("実行中のOS", ProcessInfo.processInfo.operatingSystemVersionString),
      ("デバイス種別（UA判定）", "Desktop"), ("画面解像度（CSS px）", "検証用サンプル"),
      ("内蔵WebKitのViewport（CSS px）", "検証用サンプル"), ("Device Pixel Ratio", "取得不可"),
      ("言語", "ja-JP"), ("タイムゾーン", "Asia/Tokyo"), ("Cookie対応", "取得不可"),
      ("接続状態（navigator.onLine）", "取得不可"), ("CPU論理コア数（WebKit公開値）", "取得不可"),
      ("メモリ容量（WebKit公開値）", "取得不可"), ("最大タッチ点数", "取得不可")]
    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "User-Agent Viewer") {
     UserAgentView(model: model, initialTab: state == "details" ? 1 : state == "inspect" || state == "oversize" ? 2 : 0,
        initialPasted: state == "oversize" ? String(repeating: "a", count: 65_537) : pasted)
    }.defaultAppStorage(defaults))
    let size = NSSize(width: 520, height: theme == .windows98 ? 670 : 640)
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
