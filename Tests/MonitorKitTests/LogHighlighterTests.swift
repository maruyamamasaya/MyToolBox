import XCTest
@testable import MonitorKit

final class LogHighlighterTests: XCTestCase {
    func testSeverityAliasesAndBoundaries() {
        XCTAssertEqual(LogLevel.detect("info WARNING error critical"), .fatal)
        XCTAssertEqual(LogLevel.detect("warning"), .warn)
        XCTAssertEqual(LogLevel.detect("errors information"), .other)
    }
    func testLineEndingsAndContextUnion() {
        let lines = LogHighlighter.parse("INFO ok\r\nERROR broken\rcontinuation\nWARN slow\n")
        XCTAssertEqual(lines.count, 5)
        XCTAssertEqual(lines.last?.text, "")
        XCTAssertEqual(LogHighlighter.visible(lines, levels: [.error, .warn], context: 1).map(\.id), [1, 2, 3, 4, 5])
        XCTAssertTrue(LogHighlighter.visible(lines, levels: [], context: 10).isEmpty)
        XCTAssertTrue(LogHighlighter.parse("").isEmpty)
    }
    func testLiteralCaseInsensitiveUnicodeSearch() {
        let text = "😀 [ERROR] [error]"
        let ranges = LogHighlighter.matches(text, query: "[error]")
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.first?.location, 3)
        XCTAssertTrue(LogHighlighter.matches(text, query: "").isEmpty)
    }
}
