import XCTest
@testable import MonitorKit

final class RegexAndSmallDataTests: XCTestCase {
    func testCapturesUnicodeAndReplacement() throws {
        let result = try RegexWorkbench.test("😀 cat-12 dog-34", pattern: #"([a-z]+)-(\d+)"#, replacement: "$2/$1")
        XCTAssertEqual(result.matches.count, 2)
        XCTAssertEqual(result.matches[0].range.location, 3)
        XCTAssertEqual(result.matches[0].groups, ["cat-12", "cat", "12"])
        XCTAssertEqual(result.replacement, "😀 12/cat 34/dog")
    }
    func testFlagsAndFirstOnly() throws {
        XCTAssertEqual(try RegexWorkbench.test("CAT\ncat", pattern: "^cat$", ignoreCase: true, multiline: true).matches.count, 2)
        XCTAssertEqual(try RegexWorkbench.test("a\nb", pattern: "a.b", dotAll: true).matches.count, 1)
        XCTAssertEqual(try RegexWorkbench.test("aaa", pattern: "a", replacement: "b", all: false).replacement, "baa")
        XCTAssertEqual(try RegexWorkbench.test("a", pattern: "(b)?a").matches[0].groups[1], nil)
    }
    func testEmptyMatchesAndInvalidPatterns() throws {
        XCTAssertEqual(try RegexWorkbench.test("😀", pattern: "^|$", replacement: "|").replacement, "|😀|")
        XCTAssertThrowsError(try RegexWorkbench.test("x", pattern: "["))
        XCTAssertThrowsError(try RegexWorkbench.test(String(repeating: "a", count: 65_537), pattern: "a"))
        XCTAssertThrowsError(try RegexWorkbench.test(String(repeating: "a", count: 1001), pattern: "a"))
    }
    func testPathologicalRegexStops() {
        XCTAssertThrowsError(try RegexWorkbench.test(String(repeating: "a", count: 64) + "!", pattern: "^(a+)+$"))
    }
    func testBuilderEscapesAndRepeatsEntireLiteral() throws {
        var literal = RegexWorkbench.Part(); literal.kind = .literal; literal.value = "a.b"; literal.repetition = .exact; literal.minimum = 2
        let pattern = try RegexWorkbench.build([literal], start: true, end: true)
        XCTAssertEqual(try RegexWorkbench.test("a.ba.b", pattern: pattern).matches.count, 1)
        XCTAssertEqual(try RegexWorkbench.test("axbaxb", pattern: pattern).matches.count, 0)
        var choice = RegexWorkbench.Part(); choice.kind = .either; choice.value = "a+"; choice.alternative = "b"
        XCTAssertEqual(try RegexWorkbench.test("a+", pattern: RegexWorkbench.build([choice], start: true, end: true)).matches.count, 1)
        literal.minimum = -1
        XCTAssertThrowsError(try literal.pattern())
    }
    func testTableExportsEscapingAndHeaders() throws {
        let rows = [["名前", "内容"], ["a|b", "<script>\n\"x\""]]
        let csv = SmallDataTools.export(rows, format: .csv, header: true, alignment: .left)
        XCTAssertEqual(try CSVDocument.parse(csv), rows)
        let markdown = SmallDataTools.export(rows, format: .markdown, header: true, alignment: .center)
        XCTAssertTrue(markdown.contains("a\\|b")); XCTAssertTrue(markdown.contains(":---:")); XCTAssertTrue(markdown.contains("<br>"))
        let html = SmallDataTools.export(rows, format: .html, header: false, alignment: .right)
        XCTAssertFalse(html.contains("<thead>")); XCTAssertTrue(html.contains("&lt;script&gt;")); XCTAssertTrue(html.contains("&quot;"))
        let noHeader = SmallDataTools.export([["a"]], format: .markdown, header: false, alignment: .left)
        XCTAssertEqual(noHeader.components(separatedBy: "\n").count, 3)
    }
    func testStatisticsNullsMixedValuesAndDuplicates() throws {
        let rows = try SmallDataTools.parse("name,value,mixed,empty\na,0,3,NULL\nb,2,text,\na,0,3,NULL\nc,NA,4,N/A")
        let result = try SmallDataTools.statistics(rows, header: true, nullTokens: "NULL,NA,N/A")
        XCTAssertEqual(result.rows, 4); XCTAssertEqual(result.duplicates, 1)
        let numeric = result.columns[1]
        XCTAssertEqual(numeric.count, 3); XCTAssertEqual(numeric.nulls, 1); XCTAssertEqual(numeric.unique, 2)
        XCTAssertEqual(numeric.sum, 2); XCTAssertEqual(numeric.mean!, 2.0 / 3.0, accuracy: 0.00001)
        XCTAssertEqual(numeric.median, 0); XCTAssertEqual(numeric.minimum, 0); XCTAssertEqual(numeric.maximum, 2)
        XCTAssertEqual(result.columns[2].type, "文字列"); XCTAssertNil(result.columns[2].mean)
        XCTAssertEqual(result.columns[3].nulls, 4); XCTAssertNil(result.columns[3].sum)
    }
    func testQuotedCSVTabAndEmptyDataset() throws {
        let rows = try SmallDataTools.parse("\u{FEFF}name,value\r\n\"a,b\",1\r\n\"a\nline\",3")
        XCTAssertEqual(rows[1][0], "a,b"); XCTAssertEqual(rows[2][0], "a\nline")
        XCTAssertEqual(try SmallDataTools.parse("a\tb\n1\t2", delimiter: "\t"), [["a", "b"], ["1", "2"]])
        let empty = try SmallDataTools.statistics([["name"]], header: true, nullTokens: "")
        XCTAssertEqual(empty.rows, 0); XCTAssertEqual(empty.columns[0].type, "空"); XCTAssertNil(empty.columns[0].mean)
        let noHeader = try SmallDataTools.statistics([["1"], ["3"]], header: false, nullTokens: "")
        XCTAssertEqual(noHeader.rows, 2); XCTAssertEqual(noHeader.columns[0].median, 2)
        XCTAssertThrowsError(try SmallDataTools.parse("a,\"unclosed"))
    }
    func testLimitsAndNumericOverflow() throws {
        XCTAssertThrowsError(try SmallDataTools.parse(String(repeating: "x", count: 524_289)))
        XCTAssertThrowsError(try SmallDataTools.parse(Array(repeating: "x", count: 31).joined(separator: ",")))
        XCTAssertThrowsError(try SmallDataTools.statistics([["n"], ["1e308"], ["1e308"]], header: true, nullTokens: ""))
    }
}
