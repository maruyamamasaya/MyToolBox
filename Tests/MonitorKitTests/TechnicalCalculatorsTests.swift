import XCTest
@testable import MonitorKit

final class TechnicalCalculatorsTests: XCTestCase {
    typealias C = TechnicalCalculators
    func testCapacityUnitsAndValidation() throws {
        XCTAssertEqual(try C.bytes("1 MB"), 1_000_000)
        XCTAssertEqual(try C.bytes("1MiB"), 1_048_576)
        XCTAssertEqual(try C.bytes("0"), 0)
        XCTAssertEqual(try C.bytes("2,097,152"), 2_097_152)
        XCTAssertEqual(try C.bytes("1,024.5 KiB"), 1_049_088)
        XCTAssertEqual(try C.bytes("2,097,152", unit: "B"), 2_097_152)
        XCTAssertThrowsError(try C.bytes("1,2 MB"))
        XCTAssertThrowsError(try C.bytes("1,2", unit: "B"))
        XCTAssertThrowsError(try C.bytes("1 Mbps"))
        XCTAssertThrowsError(try C.bytes("-1 MB"))
        XCTAssertThrowsError(try C.bytes("1e308 TB"))
    }
    func testExactBaseConversion() throws {
        XCTAssertEqual(try C.base("255", from: 10, to: 60), "4F")
        XCTAssertEqual(try C.base("-0xff", from: 16, to: 2), "-11111111")
        XCTAssertEqual(try C.base("18,446,744,073,709,551,616", from: 10, to: 16), "10000000000000000")
        XCTAssertEqual(try C.base("-000", from: 10, to: 2), "0")
        XCTAssertEqual(try C.base("a", from: 60, to: 10), "36")
        let large = String(repeating: "9", count: 200)
        XCTAssertEqual(try C.base(C.base(large, from: 10, to: 60), from: 60, to: 10), large)
        XCTAssertThrowsError(try C.base("2", from: 2, to: 10))
        XCTAssertThrowsError(try C.base("1.5", from: 10, to: 2))
        XCTAssertThrowsError(try C.base("1", from: 61, to: 2))
    }
    func testBandwidthAndInverse() throws {
        XCTAssertEqual(try C.bandwidth(bytes: 1e9, seconds: 60), 133333333.33333333, accuracy: 0.001)
        XCTAssertEqual(try C.transferTime(bytes: 1e9, bitsPerSecond: 100e6), 80)
        XCTAssertThrowsError(try C.transferTime(bytes: 1, bitsPerSecond: 0))
        XCTAssertThrowsError(try C.bandwidth(bytes: .infinity, seconds: 1))
    }
    func testRAIDLayouts() throws {
        for (level, usable) in [(0, 16.0), (1, 4), (5, 12), (6, 8), (10, 8)] {
            XCTAssertEqual(try C.raid(level: level, count: 4, size: 4).usable, usable)
        }
        XCTAssertThrowsError(try C.raid(level: 10, count: 5, size: 4))
        XCTAssertThrowsError(try C.raid(level: 5, count: 2, size: 4))
        XCTAssertThrowsError(try C.raid(level: 6, count: 4, size: 0))
    }
    func testSLAAndBoundaries() throws {
        XCTAssertEqual(try C.downtime(rate: 99.9, days: 30), 2592, accuracy: 0.00001)
        XCTAssertEqual(try C.downtime(rate: 100, days: 365), 0)
        XCTAssertEqual(try C.downtime(rate: 0, days: 1), 86400)
        XCTAssertThrowsError(try C.downtime(rate: 100.1, days: 1))
        XCTAssertEqual(C.duration(2592), "43分 12秒")
        XCTAssertEqual(C.duration(0), "0秒")
    }
}
