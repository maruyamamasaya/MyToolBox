import AppKit
import SwiftUI

@main struct RenderServerManagement {
    @MainActor static func main() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: "build/server-management-preview")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 1792558800)
        let normal: [ServerCheckReading] = [
            .init(item: .health, state: .confirmed, detail: "127.0.0.1:8080/health → HTTP 200（ローカル到達性）", checkedAt: now),
            .init(item: .musicListener, state: .confirmed, detail: "Python の TCP 8768 待受を確認。音楽再生・認証・別端末からの到達性は未確認", checkedAt: now),
            .init(item: .musicLaunchd, state: .confirmed, detail: "固定サービスの実行理由に応答あり（launchctl blame による参考情報）", checkedAt: now),
            .init(item: .musicLocalListener, state: .confirmed, detail: "Python の TCP 8769 はこのMac内だけで待受。設定画面の内部用ポートです。8768とのPID一致・設定APIの動作は未確認", checkedAt: now),
            .init(item: .taskRelayListener, state: .confirmed, detail: "Python の 192.168.0.35:8778 待受を確認。常駐PIDとの一致・TLS・端末認証・iPhoneからの到達性は未確認", checkedAt: now),
            .init(item: .taskRelayLaunchd, state: .confirmed, detail: "固定サービスの実行理由に応答あり（launchctl blame による参考情報）", checkedAt: now),
            .init(item: .listener, state: .confirmed, detail: "PID 123 ／ node ／ TCP 8080\nポートの所有者情報です。launchd の PID との一致は未検証", checkedAt: now),
            .init(item: .launchd, state: .confirmed, detail: "固定サービスの実行理由に応答あり（launchctl blame による参考情報）", checkedAt: now),
            .init(item: .tailscale, state: .confirmed, detail: "接続状態：Running ／ 自端末：オンライン\nVPN 経由の端末間到達性は未検証", checkedAt: now),
            .init(item: .serve, state: .confirmed, detail: "HTTPS 443：設定あり ／ ルート → 127.0.0.1:8080：設定あり\nFunnel：有効な設定なし（設定値の確認のみ）", checkedAt: now)
        ]
        for theme in VisualTheme.allCases {
            for name in ["normal", "diagnostics", "music-diagnostics", "all-diagnostics", "unavailable", "empty", "updating"] {
                for width in [440.0, 800.0] {
                    let model = ServerManagementModel()
                    model.rows = name == "empty" ? [] : normal
                    if name == "unavailable" {
                        model.rows = [
                            .init(item: .health, state: .attention, detail: "期待した HTTP 200 応答を確認できません", checkedAt: now),
                            .init(item: .musicListener, state: .unavailable, detail: "応答を取得できません（権限・接続・インストール状態を確認）。停止とは断定できません", checkedAt: now)
                        ]
                    }
                    model.busy = name == "updating"
                    let size = NSSize(width: width, height: 620)
                    let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "サーバー管理") {
                        ServerManagementView(model: model, initiallyShowsDiagnostics: name == "diagnostics" || name == "all-diagnostics", initiallyShowsMusicDiagnostics: ["music-diagnostics", "all-diagnostics", "unavailable"].contains(name), refreshOnAppear: false)
                    }.frame(width: size.width, height: size.height))
                    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                    window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                    window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(80)); host.layoutSubtreeIfNeeded()
                    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("render") }
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(theme.rawValue)-\(name)-\(Int(width)).png"))
                    precondition(host.fittingSize.width <= size.width && host.fittingSize.height <= size.height)
                    precondition(model.busy == (name == "updating"))
                    precondition(model.rows.count == (name == "empty" ? 0 : name == "unavailable" ? 2 : 10))
                    print("PASS \(theme.rawValue) \(name) \(width)")
                }
            }
        }
    }
}
