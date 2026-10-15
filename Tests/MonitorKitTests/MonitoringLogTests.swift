import XCTest
@testable import MonitorKit
final class MonitoringLogTests: XCTestCase {
    func testRecordingCadenceResetAndMissingValues() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let logger = MonitoringLog(directory: dir)
        var p = LogPreferences(); p.enabled = true
        var s = Snapshot(date: Date(timeIntervalSince1970: 1_700_000_000), uptime: 1, readings: [Reading("cpu", "CPU", ["使用率": Metric(.unavailable, "test unavailable")])])
        let first = try await logger.append(s, preferences: p); XCTAssertTrue(first)
        s.uptime = 5
        let early = try await logger.append(s, preferences: p); XCTAssertFalse(early)
        s.uptime = 11
        let next = try await logger.append(s, preferences: p); XCTAssertTrue(next)
        await logger.reset()
        let reset = try await logger.append(s, preferences: p); XCTAssertTrue(reset)
        p.enabled = false
        let disabled = try await logger.append(s, preferences: p); XCTAssertFalse(disabled)
        let file = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first)
        let lines = try String(contentsOf: file).split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(MonitoringLog.Record.self, from: Data(lines[0].utf8))
        XCTAssertEqual(record.snapshot.metric("cpu", "使用率")?.state, .unavailable)
        XCTAssertEqual(record.snapshot.metric("cpu", "使用率")?.reason, "test unavailable")
        XCTAssertNil(record.snapshot.metric("cpu", "使用率")?.value)
    }
    func testRetentionOnlyRemovesExpiredOwnedFiles() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["monitor-2020-01-01.jsonl", "keep.txt", "monitor-invalid.jsonl"] { try Data().write(to: dir.appendingPathComponent(name)) }
        let logger = MonitoringLog(directory: dir)
        var p = LogPreferences(); p.enabled = true
        _ = try await logger.append(Snapshot(date: Date(), uptime: 1, readings: []), preferences: p)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("monitor-2020-01-01.jsonl").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("keep.txt").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("monitor-invalid.jsonl").path))
    }
    func testLoggingPreferencesAndWriteFailure() async throws {
        let suite = "MyToolBox.LogTest." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(LogPreferences.load(from: defaults).enabled)
        var p = LogPreferences(); p.enabled = true; p.interval = 60; p.retentionDays = 30; p.save(to: defaults)
        XCTAssertEqual(LogPreferences.load(from: defaults), p)
        p.interval = -1; p.retentionDays = 999; p.save(to: defaults)
        XCTAssertEqual(LogPreferences.load(from: defaults).interval, 10)
        XCTAssertEqual(LogPreferences.load(from: defaults).retentionDays, 7)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        let logger = MonitoringLog(directory: file)
        do {
            _ = try await logger.append(Snapshot(date: Date(), uptime: 1, readings: []), preferences: p)
            XCTFail("File cannot be a log directory")
        } catch { /* surfaced to the UI, does not stop monitoring */ }
    }
}
