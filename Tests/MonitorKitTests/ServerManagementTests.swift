import XCTest
@testable import MonitorKit

final class ServerManagementTests: XCTestCase {
    func testFailureDoesNotClaimServiceStoppedOrExposeOutput() {
        for item in ServerCheck.allCases {
            for result in [SecurityCommandResult(output: "private token", error: "private error", code: 1), SecurityCommandResult(failure: "タイムアウト secret"), SecurityCommandResult(failure: "secret")] {
                let row = ServerManagementCollector.parse(item, result: result)
                XCTAssertEqual(row.state, .unavailable)
                XCTAssertFalse(row.detail.contains("secret")); XCTAssertFalse(row.detail.contains("private"))
            }
        }
    }
    func testHealthRedirectAndMissingListenerAreNotHealthy() {
        XCTAssertEqual(parse(.health, "200").state, .confirmed)
        let timeout = ServerManagementCollector.parse(.health, result: .init(output: "000", code: 28))
        XCTAssertEqual(timeout.state, .unavailable); XCTAssertTrue(timeout.detail.contains("タイムアウト"))
        XCTAssertEqual(parse(.health, "302").state, .attention)
        XCTAssertEqual(parse(.health, "503").state, .attention)
        XCTAssertEqual(parse(.listener, "").state, .unavailable)
        XCTAssertEqual(parse(.launchd, "").state, .unavailable)
        XCTAssertEqual(parse(.launchd, "inefficient").state, .confirmed)
    }
    func testListenerRequiresPortAndSanitizesProcessName() {
        let row = parse(.listener, "p123\ncnode\nn*:8080\np456\ncprivate-command\nn127.0.0.1:8080")
        XCTAssertEqual(row.state, .confirmed); XCTAssertTrue(row.detail.contains("PID 123"))
        XCTAssertTrue(row.detail.contains("別プロセス")); XCTAssertFalse(row.detail.contains("private"))
        XCTAssertEqual(parse(.listener, "p123\ncnode\nn*:9000").state, .unavailable)
    }
    func testVPNRequiresRunningAndSelfOnline() {
        XCTAssertEqual(parse(.tailscale, #"{"BackendState":"Running","Self":{"Online":true,"DNSName":"private"}}"#).state, .confirmed)
        XCTAssertEqual(parse(.tailscale, #"{"BackendState":"Stopped","Self":{"Online":false}}"#).state, .attention)
        XCTAssertEqual(parse(.tailscale, #"{"BackendState":"Running"}"#).state, .attention)
        XCTAssertEqual(parse(.tailscale, "{}").state, .unavailable)
        XCTAssertEqual(parse(.tailscale, "broken").state, .unavailable)
    }
    func testServeMatches443RootAndFlagsFunnelWithoutLeakingHost() {
        let base = #"{"TCP":{"443":{"HTTPS":true}},"Web":{"private.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:8080"}}}},"AllowFunnel":{"private.ts.net:443":false}}"#
        XCTAssertEqual(parse(.serve, base).state, .confirmed)
        XCTAssertFalse(parse(.serve, base).detail.contains("private"))
        XCTAssertEqual(parse(.serve, base.replacingOccurrences(of: ":false", with: ":true")).state, .attention)
        XCTAssertEqual(parse(.serve, base.replacingOccurrences(of: ":8080", with: ":9090")).state, .attention)
        XCTAssertEqual(parse(.serve, base.replacingOccurrences(of: "net:443", with: "net:8443")).state, .attention)
        XCTAssertEqual(parse(.serve, "{}").state, .unavailable)
    }
    func testFixedReadCommandsAndNoCredentials() {
        XCTAssertEqual(ServerCheck.launchd.command.1, ["blame", "system/com.baby-media-web"])
        XCTAssertTrue(ServerCheck.tailscale.command.1.contains("--peers=false"))
        XCTAssertFalse(ServerCheck.health.command.1.contains("--location"))
        XCTAssertTrue(ServerCheck.health.command.1.contains("/dev/null"))
    }
    private func parse(_ item: ServerCheck, _ output: String) -> ServerCheckReading {
        ServerManagementCollector.parse(item, result: .init(output: output))
    }
}
