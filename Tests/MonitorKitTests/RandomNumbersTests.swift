import XCTest
@testable import MonitorKit

final class RandomNumbersTests: XCTestCase {
    func testRangesAndCount() throws {
        var generator = SystemRandomNumberGenerator()
        for bounds in [(1, 10), (1, 100), (1, 1000), (0, 255), (-100, 100), (-1000, 1000), (7, 7)] {
            let values = try RandomNumbers.generate(minimum: bounds.0, maximum: bounds.1, count: 100, using: &generator)
            XCTAssertEqual(values.count, 100)
            XCTAssertTrue(values.allSatisfy { Int($0).map { (bounds.0...bounds.1).contains($0) } ?? false })
        }
    }
    func testLargeDigitsRemainExact() throws {
        var generator = SystemRandomNumberGenerator()
        for digits in [1, 16, 32] {
            let values = try RandomNumbers.generate(digits: digits, count: 100, using: &generator)
            XCTAssertTrue(values.allSatisfy { $0.count == digits && $0.first != "0" && $0.allSatisfy(\.isNumber) })
        }
    }
    func testZeroRangeStripsLeadingZeros() throws {
        var generator = SystemRandomNumberGenerator()
        let values = try RandomNumbers.generate(digits: 2, startsAtZero: true, count: 100, using: &generator)
        XCTAssertTrue(values.allSatisfy { Int($0).map { (0...99).contains($0) } ?? false })
        XCTAssertTrue(values.allSatisfy { $0 == "0" || $0.first != "0" })
    }
    func testInvalidInputs() {
        var generator = SystemRandomNumberGenerator()
        for digits in [0, 33] { XCTAssertThrowsError(try RandomNumbers.generate(digits: digits, count: 1, using: &generator)) }
        for count in [0, 101] { XCTAssertThrowsError(try RandomNumbers.generate(count: count, using: &generator)) }
        XCTAssertThrowsError(try RandomNumbers.generate(minimum: 2, maximum: 1, count: 1, using: &generator))
    }
}
