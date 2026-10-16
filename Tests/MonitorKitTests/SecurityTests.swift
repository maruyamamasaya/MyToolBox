import XCTest
@testable import MonitorKit

final class SecurityTests: XCTestCase {
    func testKnownStatesAndFailures() {
        let cases: [(SecurityItem, String, Int32, SecurityState)] = [
            (.firewall, "Firewall is enabled. (State = 1)", 0, .enabled),
            (.firewall, "Firewall is disabled. (State = 0)", 0, .disabled),
            (.gatekeeper, "assessments enabled", 0, .enabled),
            (.gatekeeper, "assessments disabled", 0, .disabled),
            (.fileVault, "FileVault is On.", 0, .enabled),
            (.fileVault, "FileVault is Off.", 1, .disabled),
            (.fileVault, "FileVault is On.\nEncryption in progress: Percent completed = 20", 2, .encrypting),
            (.fileVault, "Decryption in progress: Percent completed = 20", 0, .decrypting),
            (.fileVault, "FileVault is On.", 2, .unavailable),
            (.gatekeeper, "assessments enabled", 1, .unavailable),
            (.firewall, "new output", 0, .unavailable),
            (.fileVault, "Error: Unknown volume or device specifier: '/'.", 1, .unavailable)
        ]
        for (item, output, code, state) in cases {
            let result = SecurityCollector.parse(item, result: SecurityCommandResult(output: output, code: code))
            XCTAssertEqual(result.state, state, output); XCTAssertNotNil(result.checkedAt)
        }
        XCTAssertEqual(SecurityCollector.parse(.gatekeeper, result: SecurityCommandResult(output: "assessments enabled", error: "unexpected warning")).state, .unavailable)
        let denied = SecurityCollector.parse(.fileVault, result: SecurityCommandResult(error: "Permission denied", code: 1))
        XCTAssertEqual(denied.state, .unavailable); XCTAssertTrue(denied.reason.contains("通常権限"))
    }
    func testRunnerTimeoutAndLaunchFailure() {
        let start = Date()
        let timeout = SecurityCommand.run(path: "/bin/sleep", arguments: ["2"], timeout: 0.05)
        XCTAssertTrue(timeout.failure?.contains("タイムアウト") == true)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertNotNil(SecurityCommand.run(path: "/nonexistent/security-tool", arguments: []).failure)
        let result = SecurityCommand.run(path: "/usr/bin/printf", arguments: ["hello"])
        XCTAssertEqual(result.code, 0); XCTAssertEqual(result.output, "hello"); XCTAssertEqual(result.error, "")
    }
}
