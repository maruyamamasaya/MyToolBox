import XCTest
@testable import MonitorKit
final class SMCTests: XCTestCase {
    func testReadOnlyWireLayout() throws {
        let info = try SMCCodec.request(key: "FNum", command: .info)
        XCTAssertNil(SMCReadCommand(rawValue: 6))
        XCTAssertEqual(info.count, 80)
        XCTAssertEqual(Array(info.prefix(4)), [0x6d,0x75,0x4e,0x46])
        XCTAssertEqual(info[42], 9)
        XCTAssertTrue(info[48...].allSatisfy { $0 == 0 })
        let read = try SMCCodec.request(key: "F0Ac", command: .value, size: 4)
        XCTAssertEqual(read[28], 4); XCTAssertEqual(read[42], 5)
        XCTAssertThrowsError(try SMCCodec.request(key: "F0Ac", command: .value, size: 33))
        XCTAssertThrowsError(try SMCCodec.request(key: "bad", command: .info))
    }
    func testMetadataAndFirmwareErrors() throws {
        var reply = [UInt8](repeating: 0, count: 80)
        reply[28] = 4; reply[32] = 32; reply[33] = 116; reply[34] = 108; reply[35] = 102
        let (size, type) = try SMCCodec.metadata(reply)
        XCTAssertEqual(size, 4); XCTAssertEqual(type, "flt ")
        reply[40] = 0x84
        XCTAssertThrowsError(try SMCCodec.metadata(reply))
        reply[40] = 0; reply[28] = 33
        XCTAssertThrowsError(try SMCCodec.metadata(reply))
        XCTAssertThrowsError(try SMCCodec.check([0,0]))
    }
    func testTypesAndZeroFanValue() throws {
        XCTAssertEqual(try SMCCodec.decode([0,0,0x50,0x42], type: "flt "), 52)
        XCTAssertEqual(try SMCCodec.decode([0x34,0x80], type: "sp78"), 52.5)
        XCTAssertEqual(try SMCCodec.decode([0xff,0x80], type: "sp78"), -0.5)
        XCTAssertEqual(try SMCCodec.decode([0x1f,0x40], type: "fpe2"), 2000)
        XCTAssertEqual(try SMCCodec.decode([0,0,0,0], type: "flt "), 0)
        XCTAssertEqual(try SMCCodec.decode([2], type: "ui8 "), 2)
        XCTAssertThrowsError(try SMCCodec.decode([0,0,0x80,0x7f], type: "flt "))
        XCTAssertThrowsError(try SMCCodec.decode([0,0,0xc0,0x7f], type: "flt "))
        XCTAssertThrowsError(try SMCCodec.decode([1], type: "flt "))
        XCTAssertThrowsError(try SMCCodec.decode([1], type: "bad "))
    }
    func testSensorAggregationDoesNotHideMissingChannels() {
        let good = SensorsMonitor.temperature(52, source: "test")
        let missing = Metric(.unavailable, "test")
        XCTAssertEqual(SensorsMonitor.average([good, good], expected: 2).value, 52)
        XCTAssertNil(SensorsMonitor.average([good, missing], expected: 2).value)
        XCTAssertNil(SensorsMonitor.average([good], expected: 2).value)
        XCTAssertNil(SensorsMonitor.temperature(0, source: "test").value)
        XCTAssertNil(SensorsMonitor.temperature(200, source: "test").value)
        XCTAssertEqual(SensorsMonitor.fan(0, source: "test").value, 0)
        XCTAssertNil(SensorsMonitor.fan(-1, source: "test").value)
        XCTAssertNil(SensorsMonitor.fanCount(1.5)); XCTAssertNil(SensorsMonitor.fanCount(100))
        XCTAssertEqual(SensorsMonitor.fanCount(0), 0)
    }
    func testExistingPreferencesEnableNewSensorsOnce() throws {
        let suite = "MyToolBoxTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var legacy = Preferences(); legacy.hidden = ["sensors", "gpu"]; legacy.interval = 5; legacy.sensorMenuVersion = nil
        legacy.save(to: defaults)
        let migrated = Preferences.load(from: defaults)
        XCTAssertFalse(migrated.hidden.contains("sensors")); XCTAssertTrue(migrated.hidden.contains("gpu"))
        XCTAssertEqual(migrated.interval, 5)
        var edited = migrated; edited.hidden.insert("sensors"); edited.save(to: defaults)
        XCTAssertTrue(Preferences.load(from: defaults).hidden.contains("sensors"))
    }
}
