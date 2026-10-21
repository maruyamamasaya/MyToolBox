import Foundation
import Darwin

public enum ServerCheck: String, CaseIterable, Sendable, Identifiable {
    case health, musicListener, musicLaunchd, musicLocalListener, launchd, listener, tailscale, serve
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .health: return "写真サーバー /health"
        case .musicListener: return "音楽サーバー TCP 8768"
        case .musicLaunchd: return "常駐サービス：MyMusic LAN Cardinal"
        case .musicLocalListener: return "内部ポート TCP 8769"
        case .launchd: return "launchd：com.baby-media-web"
        case .listener: return "TCP 8080 の待受"
        case .tailscale: return "Tailscale 接続"
        case .serve: return "Tailscale Serve"
        }
    }
    var command: (String, [String]) {
        let cli = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        switch self {
        case .health: return ("/usr/bin/curl", ["--disable", "--noproxy", "*", "--proxy", "", "--silent", "--max-time", "3", "--output", "/dev/null", "--write-out", "%{http_code}", "http://127.0.0.1:8080/health"])
        // blame does not retrieve the job's environment, unlike launchctl print.
        case .launchd: return ("/bin/launchctl", ["blame", "system/com.baby-media-web"])
        case .musicLaunchd: return ("/bin/launchctl", ["blame", "gui/\(getuid())/local.mymusic.cardinal-server"])
        case .musicLocalListener: return ("/usr/sbin/lsof", ["-nP", "-a", "-iTCP:8769", "-sTCP:LISTEN", "-Fpcn"])
        case .musicListener: return ("/usr/sbin/lsof", ["-nP", "-a", "-iTCP:8768", "-sTCP:LISTEN", "-Fpcn"])
        case .listener: return ("/usr/sbin/lsof", ["-nP", "-a", "-iTCP:8080", "-sTCP:LISTEN", "-Fpcn"])
        case .tailscale: return (cli, ["status", "--json", "--peers=false"])
        case .serve: return (cli, ["serve", "status", "--json"])
        }
    }
}

public enum ServerCheckState: String, Sendable {
    case confirmed = "確認済み", attention = "要確認", unavailable = "取得不可"
}

public struct ServerCheckReading: Sendable, Identifiable {
    public let item: ServerCheck
    public let state: ServerCheckState
    public let detail: String
    public let checkedAt: Date
    public var id: String { item.rawValue }
}

/// One bounded, explicit scan. No timer, service control, credentials, or media access.
public actor ServerManagementCollector {
    public init() {}
    public func read(menuOnly: Bool = false) -> [ServerCheckReading] {
        let items: [ServerCheck] = menuOnly ? [.health, .musicListener] : ServerCheck.allCases
        return items.map { item in
            let (path, arguments) = item.command
            let environment = item == .tailscale || item == .serve ? ["TAILSCALE_BE_CLI": "1"] : [:]
            return Self.parse(item, result: SecurityCommand.run(path: path, arguments: arguments, environment: environment))
        }
    }
    static func parse(_ item: ServerCheck, result: SecurityCommandResult) -> ServerCheckReading {
        func reading(_ state: ServerCheckState, _ detail: String) -> ServerCheckReading {
            .init(item: item, state: state, detail: detail, checkedAt: Date())
        }
        // Never surface raw stdout/stderr: CLI output may contain private device metadata.
        if item == .health && result.code == 28 { return reading(.unavailable, "HTTP 確認がタイムアウトしました（3秒）") }
        if result.failure != nil {
            return reading(.unavailable, result.failure?.contains("タイムアウト") == true ? "確認がタイムアウトしました（各コマンド最大5秒）" : "読取コマンドを実行できません")
        }
        guard result.code == 0, result.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return reading(.unavailable, "応答を取得できません（権限・接続・インストール状態を確認）。停止とは断定できません")
        }
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        switch item {
        case .health:
            guard output == "200" else { return reading(.attention, "期待した HTTP 200 応答を確認できません") }
            return reading(.confirmed, "127.0.0.1:8080/health → HTTP 200（ローカル到達性）")
        case .launchd, .musicLaunchd:
            guard !output.isEmpty else { return reading(.unavailable, "launchd の実行理由を取得できません") }
            return reading(.confirmed, "固定サービスの実行理由に応答あり（launchctl blame による参考情報）")
        case .musicListener, .musicLocalListener:
            let port = item == .musicListener ? 8768 : 8769
            var exposed = false
            var pid: Int?, name: String?
            var expected = false, other = false
            for line in output.split(separator: "\n").map(String.init) {
                if line.hasPrefix("p") { pid = Int(line.dropFirst()); name = nil }
                if line.hasPrefix("c") { name = String(line.dropFirst()) }
                if line.hasPrefix("n"), line.hasSuffix(":\(port)"), let pid, pid > 0, let name {
                    if item == .musicLocalListener && line != "n127.0.0.1:8769" && line != "n[::1]:8769" { exposed = true }
                    if name == "Python" || name == "python3" || name.hasPrefix("python3.") { expected = true }
                    else { other = true }
                }
            }
            guard expected || other else { return reading(.unavailable, "TCP \(port) の待受を確認できません。停止とは断定できません") }
            if item == .musicLocalListener {
                return reading(expected && !other && !exposed ? .confirmed : .attention,
                               expected && !other && !exposed ? "Python の TCP 8769 はこのMac内だけで待受。設定画面の内部用ポートです。8768とのPID一致・設定APIの動作は未確認" : "TCP 8769 のプロセスまたは待受範囲が想定と異なります")
            }
            return reading(expected && !other ? .confirmed : .attention,
                           expected && !other ? "Python の TCP 8768 待受を確認。音楽再生・認証・別端末からの到達性は未確認" : "TCP 8768 に想定外のプロセスがあります")
        case .listener:
            var pid: Int?, name: String?, rows: [String] = []
            for line in output.split(separator: "\n").map(String.init) {
                if line.hasPrefix("p") { pid = Int(line.dropFirst()); name = nil }
                if line.hasPrefix("c") { name = String(line.dropFirst()) }
                if line.hasPrefix("n"), let pid, pid > 0, let name,
                   line.hasSuffix(":8080"), rows.count < 8 {
                    // Only display the expected runtime name, never arbitrary process arguments.
                    rows.append("PID \(pid) ／ \(name == "node" ? "node" : "別プロセス") ／ TCP 8080")
                }
            }
            guard !rows.isEmpty else { return reading(.unavailable, "待受情報を取得できません。停止とは断定できません") }
            return reading(.confirmed, rows.joined(separator: "\n") + "\nポートの所有者情報です。launchd の PID との一致は未検証")
        case .tailscale:
            guard let data = output.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let backend = json["BackendState"] as? String,
                  ["Running", "Stopped", "Starting", "NeedsLogin", "NeedsMachineAuth", "NoState", "InUseOtherUser"].contains(backend) else {
                return reading(.unavailable, "Tailscale の接続情報を解釈できません")
            }
            let online = (json["Self"] as? [String: Any])?["Online"] as? Bool
            return reading(backend == "Running" && online == true ? .confirmed : .attention,
                           "接続状態：\(backend) ／ 自端末：\(online.map { $0 ? "オンライン" : "オフライン" } ?? "未確認")\nVPN 経由の端末間到達性は未検証")
        case .serve:
            guard let data = output.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tcp = json["TCP"] as? [String: Any], let web = json["Web"] as? [String: Any] else {
                return reading(.unavailable, "Serve 設定を取得・解釈できません")
            }
            let https = (tcp["443"] as? [String: Any])?["HTTPS"] as? Bool == true
            var proxy = false
            for (host, value) in web where host.hasSuffix(":443") {
                let handlers = (value as? [String: Any])?["Handlers"] as? [String: Any]
                if (handlers?["/"] as? [String: Any])?["Proxy"] as? String == "http://127.0.0.1:8080" { proxy = true }
            }
            guard json["AllowFunnel"] == nil || json["AllowFunnel"] is [String: Bool] else {
                return reading(.unavailable, "Funnel 設定を解釈できません")
            }
            let funnel = (json["AllowFunnel"] as? [String: Bool])?.values.contains(true) == true
            return reading(https && proxy && !funnel ? .confirmed : .attention,
                           "HTTPS 443：\(https ? "設定あり" : "未確認") ／ ルート → 127.0.0.1:8080：\(proxy ? "設定あり" : "未確認")\nFunnel：\(funnel ? "有効な設定あり" : "有効な設定なし")（設定値の確認のみ）")
        }
    }
}

/// Green is only a recent, successful reading; missing/stale data stays unknown.
public enum ServerIndicator {
    public static func state(for item: ServerCheck, readings: [ServerCheckReading], now: Date = Date()) -> ServerCheckState? {
        guard let row = readings.first(where: { $0.item == item }),
              now.timeIntervalSince(row.checkedAt) >= 0,
              now.timeIntervalSince(row.checkedAt) <= 150 else { return nil }
        return row.state
    }
}
