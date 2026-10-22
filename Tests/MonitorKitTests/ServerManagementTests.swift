import XCTest
import Darwin
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
    func testMusicListenerRequiresExpectedRuntimeAndPort() {
        XCTAssertEqual(parse(.musicListener, "p123\ncPython\nn192.168.0.35:8768").state, .confirmed)
        XCTAssertEqual(parse(.musicListener, "p123\ncPython\nn127.0.0.1:8769").state, .unavailable)
        XCTAssertEqual(parse(.musicListener, "p123\ncother-secret\nn*:8768").state, .attention)
        XCTAssertFalse(parse(.musicListener, "p123\ncother-secret\nn*:8768").detail.contains("secret"))
        XCTAssertEqual(parse(.musicListener, "p123\ncPython\nn*:8768\np124\ncnode\nn127.0.0.1:8768").state, .attention)
        XCTAssertEqual(parse(.musicListener, "cPython\nn*:8768").state, .unavailable)
    }
    func testIndicatorRejectsMissingStaleAndFutureReadings() {
        let now = Date(timeIntervalSince1970: 1000)
        func row(_ age: TimeInterval, _ state: ServerCheckState = .confirmed) -> ServerCheckReading {
            .init(item: .health, state: state, detail: "", checkedAt: now.addingTimeInterval(-age))
        }
        XCTAssertNil(ServerIndicator.state(for: .health, readings: [], now: now))
        XCTAssertNil(ServerIndicator.state(for: .musicListener, readings: [row(0)], now: now))
        XCTAssertEqual(ServerIndicator.state(for: .health, readings: [row(150)], now: now), .confirmed)
        XCTAssertNil(ServerIndicator.state(for: .health, readings: [row(151)], now: now))
        XCTAssertNil(ServerIndicator.state(for: .health, readings: [row(-1)], now: now))
        XCTAssertEqual(ServerIndicator.state(for: .health, readings: [row(0, .unavailable)], now: now), .unavailable)
        XCTAssertEqual(ServerIndicator.state(for: .health, readings: [row(0, .attention)], now: now), .attention)
    }
    func testMusicInternalListenerRequiresLoopbackAndExpectedRuntime() {
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncPython\nn127.0.0.1:8769").state, .confirmed)
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncpython3.15\nn[::1]:8769").state, .confirmed)
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncPython\nn*:8769").state, .attention)
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncPython\nn192.168.0.35:8769").state, .attention)
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncprivate\nn127.0.0.1:8769").state, .attention)
        XCTAssertFalse(parse(.musicLocalListener, "p123\ncprivate\nn127.0.0.1:8769").detail.contains("private"))
        XCTAssertEqual(parse(.musicLocalListener, "p123\ncPython\nn127.0.0.1:8768").state, .unavailable)
        XCTAssertEqual(parse(.musicLocalListener, "").state, .unavailable)
    }
    func testMusicLaunchdUsesOnlyBoundedDiagnosticResponse() {
        XCTAssertEqual(parse(.musicLaunchd, "").state, .unavailable)
        let row = parse(.musicLaunchd, "private-environment")
        XCTAssertEqual(row.state, .confirmed)
        XCTAssertFalse(row.detail.contains("private"))
        XCTAssertEqual(ServerCheck.musicLaunchd.command.0, "/bin/launchctl")
        XCTAssertEqual(ServerCheck.musicLaunchd.command.1.first, "blame")
        XCTAssertTrue(ServerCheck.musicLaunchd.command.1.last!.hasSuffix("/local.mymusic.cardinal-server"))
        XCTAssertTrue(ServerCheck.musicLaunchd.command.1.last!.hasPrefix("gui/"))
    }
    func testTaskRelayRequiresApprovedAddressPortAndPython() {
        XCTAssertEqual(parse(.taskRelayListener, "p123\ncPython\nn192.168.0.35:8778").state, .confirmed)
        for address in ["*:8778", "127.0.0.1:8778", "192.168.0.36:8778", "[::]:8778"] {
            XCTAssertEqual(parse(.taskRelayListener, "p123\ncpython3.15\nn" + address).state, .attention)
        }
        XCTAssertEqual(parse(.taskRelayListener, "p123\ncPython\nn192.168.0.35:8768").state, .unavailable)
        XCTAssertEqual(parse(.taskRelayListener, "cPython\nn192.168.0.35:8778").state, .unavailable)
        XCTAssertEqual(parse(.taskRelayListener, "").state, .unavailable)
        let other = parse(.taskRelayListener, "p123\ncprivate-secret\nn192.168.0.35:8778")
        XCTAssertEqual(other.state, .attention)
        XCTAssertFalse(other.detail.contains("secret"))
        XCTAssertEqual(parse(.taskRelayListener, "p123\ncPython\nn192.168.0.35:8778\np124\ncnode\nn*:8778").state, .attention)
    }
    func testTaskRelayLaunchdUsesFixedUserServiceWithoutExposingOutput() {
        XCTAssertEqual(ServerCheck.taskRelayLaunchd.command.1, ["blame", "gui/\(getuid())/local.CalendarTaskApp.DotLocalRelay"])
        XCTAssertEqual(ServerCheck.taskRelayListener.command.1, ["-nP", "-a", "-iTCP:8778", "-sTCP:LISTEN", "-Fpcn"])
        XCTAssertEqual(parse(.taskRelayLaunchd, "").state, .unavailable)
        let row = parse(.taskRelayLaunchd, "private-secret")
        XCTAssertEqual(row.state, .confirmed)
        XCTAssertFalse(row.detail.contains("secret"))
    }
    private func parse(_ item: ServerCheck, _ output: String) -> ServerCheckReading {
        ServerManagementCollector.parse(item, result: .init(output: output))
    }
}
