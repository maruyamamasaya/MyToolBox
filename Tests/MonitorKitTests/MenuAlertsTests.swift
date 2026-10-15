import XCTest
@testable import MonitorKit
final class MenuAlertsTests: XCTestCase {
    func snapshot(_ section: String, _ metrics: [String: Metric], _ time: Double = 0) -> Snapshot {
        Snapshot(date: Date(), uptime: time, readings: [Reading(section, section, metrics)])
    }
    func testBatteryBoundariesAndPowerState() {
        var alerts = MenuAlerts()
        for (percent, expected) in [(51.0, MenuSeverity.normal), (50, .warning), (21, .warning), (20, .critical), (0, .critical)] {
            XCTAssertEqual(alerts.levels(snapshot("battery", ["残量": Metric(percent), "電源接続": Metric(0), "充電中": Metric(0)]))["battery"], expected)
        }
        for power in [Metric(1), Metric(.unavailable, "missing")] {
            XCTAssertNil(alerts.levels(snapshot("battery", ["残量": Metric(10), "電源接続": power, "充電中": Metric(0)]))["battery"])
        }
        XCTAssertNil(alerts.levels(snapshot("battery", ["残量": Metric(10), "電源接続": Metric(0), "充電中": Metric(1)]))["battery"])
    }
    func testLoadDurationRecoveryAndReset() {
        var alerts = MenuAlerts()
        func sample(_ v: Double, _ time: Double) -> MenuSeverity? {
            alerts.levels(snapshot("cpu", ["使用率": Metric(v)], time))["cpu"]
        }
        XCTAssertEqual(sample(96, 0), .normal)
        XCTAssertEqual(sample(96, 4), .normal)
        XCTAssertEqual(sample(96, 5), .warning)
        XCTAssertEqual(sample(96, 10), .critical)
        XCTAssertEqual(sample(89, 11), .critical)
        XCTAssertEqual(sample(89, 16), .warning)
        XCTAssertEqual(sample(74, 17), .warning)
        XCTAssertEqual(sample(74, 22), .normal)
        XCTAssertEqual(sample(96, 23), .normal)
        XCTAssertEqual(sample(96, 28), .warning)
        XCTAssertEqual(sample(96, 50), .normal) // interruption breaks continuity
        XCTAssertEqual(sample(96, 49), .normal) // clock regression
        alerts.reset()
        XCTAssertEqual(sample(96, 55), .normal)
        _ = alerts.levels(snapshot("cpu", ["使用率": Metric(.unavailable, "missing")], 56))
        XCTAssertEqual(sample(96, 60), .normal)
    }
    func testPressureStorageAndTemperature() {
        var alerts = MenuAlerts()
        for (v, expected) in [(1.0, MenuSeverity.normal), (2, .warning), (4, .critical), (3, .normal)] {
            XCTAssertEqual(alerts.levels(snapshot("memory", ["使用率": Metric(99), "プレッシャー": Metric(v)]))["memory"], expected)
        }
        for (free, total, expected) in [(50e9, 500e9, MenuSeverity.normal), (49e9, 500e9, .warning), (19e9, 100e9, .critical), (40e9, 1e12, .critical)] {
            XCTAssertEqual(alerts.levels(snapshot("storage", ["空き容量": Metric(free), "総容量": Metric(total)]))["storage"], expected)
        }
        XCTAssertNil(alerts.levels(snapshot("storage", ["空き容量": Metric(.unavailable, "missing"), "総容量": Metric(1e12)]))["storage"])
        for (v, expected) in [(79.9, MenuSeverity.normal), (80, .warning), (95, .critical)] {
            XCTAssertEqual(alerts.levels(snapshot("sensors", ["CPU温度": Metric(v, "°C")]))["CPU温度"], expected)
        }
    }
}
