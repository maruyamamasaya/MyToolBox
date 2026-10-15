import XCTest
@testable import MonitorKit
final class MonitorKitTests: XCTestCase {
    func testAvailableMemoryUsesSameEstimateAndRejectsInvalidValues() {
        XCTAssertEqual(MemoryMonitor.available(total: Metric(32e9, "B"), used: Metric(25.22e9, "B")).value, 6.78e9)
        XCTAssertEqual(MemoryMonitor.available(total: Metric(32e9, "B"), used: Metric(32e9, "B")).value, 0)
        for used in [Metric(.unavailable, "missing"), Metric(33e9, "B"), Metric(-1, "B"), Metric(50, "%")] {
            XCTAssertEqual(MemoryMonitor.available(total: Metric(32e9, "B"), used: used).state, .unavailable)
        }
        XCTAssertNil(MemoryMonitor.available(total: Metric(.unavailable, "missing"), used: Metric(1, "B")).value)
    }
    func testRateUsesElapsedTime() {
        var rate = CounterRate()
        XCTAssertEqual(rate.sample(100, at: 1).state, .waiting)
        XCTAssertEqual(rate.sample(600, at: 3).value, 250)
    }
    func testRateResetAndResume() {
        var rate = CounterRate()
        _ = rate.sample(100, at: 1)
        XCTAssertNil(rate.sample(50, at: 2).value)
        XCTAssertEqual(rate.sample(100, at: 3).value, 50)
        rate.reset(); XCTAssertEqual(rate.sample(200, at: 4).state, .waiting)
    }
    func testRateInvalidTimeAndLongGap() {
        var rate = CounterRate()
        _ = rate.sample(100, at: 5)
        XCTAssertNil(rate.sample(200, at: 5).value)
        XCTAssertNil(rate.sample(300, at: 4).value)
        XCTAssertNil(rate.sample(400, at: 40).value)
    }
    func testInterfaceSwitchDoesNotCreateASpike() {
        var rates = InterfaceRates()
        _ = rates.sample(identity: "en0:1", received: 100, sent: 50, at: 1)
        XCTAssertEqual(rates.sample(identity: "en0:1", received: 300, sent: 150, at: 2).0.value, 200)
        XCTAssertNil(rates.sample(identity: "en1:2", received: 999999, sent: 999999, at: 3).0.value)
        XCTAssertNil(rates.sample(identity: "en1:3", received: 999999, sent: 999999, at: 4).0.value)
        rates.reset()
        XCTAssertNil(rates.sample(identity: "en1:3", received: 1000000, sent: 1000000, at: 5).1.value)
    }
    func testZeroIsAValidMeasuredRate() {
        var rate = CounterRate(); _ = rate.sample(100, at: 1)
        XCTAssertEqual(rate.sample(100, at: 2), Metric(0, "B/s"))
    }
    func testCPUTicksIdleAndBusy() {
        var cpu = CPUTicks()
        XCTAssertEqual(cpu.sample([[10,10,80,0]])[0].state, .waiting)
        XCTAssertEqual(cpu.sample([[20,20,160,0]])[0].value!, 20, accuracy: 0.001)
        XCTAssertEqual(cpu.sample([[20,20,260,0]])[0].value, 0)
    }
    func testCPUCounterRolloverIsWaiting() {
        var cpu = CPUTicks(); _ = cpu.sample([[UInt32.max, 1, 1, 0]])
        XCTAssertNil(cpu.sample([[2, 2, 2, 0]])[0].value)
        XCTAssertNil(cpu.sample([[2, 2, 2, 0]])[0].value)
        XCTAssertEqual(cpu.sample([[2, 2, 2, 0], [2,2,2,0]])[0].state, .waiting)
    }
    func testAvailabilityNeverFillsZero() throws {
        for state in [Availability.waiting, .unavailable, .notPresent] {
            let m = Metric(state, "test")
            XCTAssertNil(m.value)
            let decoded = try JSONDecoder().decode(Metric.self, from: JSONEncoder().encode(m))
            XCTAssertEqual(decoded, m)
        }
        XCTAssertNil(Metric(Double.nan).value)
    }
    func testHistoryRetainsSixtySecondsAtChangedInterval() {
        var history = History()
        for t in [0.0,1,2,7,12,17,22,27,32,37,42,47,52,57,62] {
            history.append(snapshot(t))
        }
        XCTAssertEqual(history.points.first?.uptime, 2)
        XCTAssertEqual(history.points.last?.uptime, 62)
    }
    func testHistoryClockChangeAndMissingValues() {
        var history = History(); history.append(snapshot(1)); history.append(snapshot(2, wall: -50))
        XCTAssertNotEqual(history.points[0].segment, history.points[1].segment)
        let missing = Snapshot(date: Date(), uptime: 3, readings: [])
        history.append(missing)
        XCTAssertTrue(history.points.last!.values.isEmpty)
    }
    func testPreferencesPersistenceAndValidation() throws {
        let suite = "MyToolBoxTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences(); prefs.compact = true; prefs.fahrenheit = true; prefs.binaryUnits = false; prefs.interval = 5; prefs.interface = "en5"; prefs.order.reverse(); prefs.hidden = ["cpu"]
        prefs.save(to: defaults)
        XCTAssertEqual(Preferences.load(from: defaults), prefs)
        prefs.interval = -1; prefs.order = ["cpu", "cpu", "bad"]; prefs.hidden = ["bad"]; prefs.save(to: defaults)
        let cleaned = Preferences.load(from: defaults)
        XCTAssertEqual(cleaned.interval, 1); XCTAssertEqual(cleaned.order.count, 7); XCTAssertTrue(cleaned.hidden.isEmpty)
        defaults.set(Data("broken".utf8), forKey: "monitor.preferences.v1")
        XCTAssertEqual(Preferences.load(from: defaults), Preferences())
    }
    func testNetworkMenuThresholdsAndMissingValues() {
        let cases: [(Double, String)] = [(0, "0.0KB/s"), (500, "0.5KB/s"), (3100, "3.1KB/s"),
            (9940, "9.9KB/s"), (9950, "10KB/s"), (10000, "10KB/s"), (99000, "99KB/s"),
            (99999, "0.1MB/s"), (100000, "0.1MB/s"), (250000, "0.2MB/s"), (1000000, "1.0MB/s")]
        for (bytes, expected) in cases { XCTAssertEqual(MetricFormat.networkMenu(Metric(bytes, "B/s")), expected, "\(bytes) B/s") }
        XCTAssertEqual(MetricFormat.networkMenu(Metric(.waiting, "first sample")), "…")
        XCTAssertEqual(MetricFormat.networkMenu(Metric(.unavailable, "failed")), "—")
        XCTAssertEqual(MetricFormat.networkMenu(Metric(-1, "B/s")), "—")
    }
    func testUnitFormatting() {
        var p = Preferences()
        XCTAssertEqual(MetricFormat.string(Metric(1024, "B/s"), preferences: p), "1.0 KiB/s")
        p.fahrenheit = true
        XCTAssertEqual(MetricFormat.string(Metric(0, "°C"), preferences: p), "32.0 °F")
        XCTAssertEqual(MetricFormat.string(Metric(.unavailable, "reason"), preferences: p), "取得不可")
    }
    private func snapshot(_ time: Double, wall: Double? = nil) -> Snapshot {
        Snapshot(date: Date(timeIntervalSince1970: wall ?? time), uptime: time, readings: [Reading("cpu", "CPU", ["使用率": Metric(25, "%")]), Reading("gpu", "GPU", ["使用率": Metric(5, "%")]), Reading("memory", "Memory", ["使用率": Metric(50, "%")]), Reading("network", "Network", ["受信速度": Metric(100, "B/s"), "送信速度": Metric(50, "B/s")])])
    }
}
