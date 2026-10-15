import XCTest
@testable import MonitorKit

final class JSONWorkspaceTests: XCTestCase {
    func testRoundTripAndExactNumbers() throws {
        let input = #"{"日本語":"a\n\"b","big":123456789012345678901234567890,"exp":-1.250e+999,"a":[true,false,null,{},[]]}"#
        let value = try JSONWorkspace.parse(input)
        for indent: Int? in [nil, 2, 4] {
            let text = value.encoded(indent: indent)
            XCTAssertEqual(try JSONWorkspace.parse(text), value)
            XCTAssertTrue(text.contains("123456789012345678901234567890"))
            XCTAssertTrue(text.contains("-1.250e+999"))
        }
    }
    func testInvalidJSON() {
        for text in ["", "01", "+1", "NaN", "1.", "[1,]", "{\"a\":1,}", "{\"a\":1,\"a\":2}", "true false", "\"\\q\"", "\"a\nb\"", "[", "{a:1}"] {
            XCTAssertThrowsError(try JSONWorkspace.parse(text), text)
        }
    }
    func testErrorLocationAndWhitespace() throws {
        XCTAssertEqual(try JSONWorkspace.parse("\r\n [1,\r\n 2]\t"), .array([.number("1"), .number("2")]))
        do { _ = try JSONWorkspace.parse("{\n  \"a\" 1\n}"); XCTFail("must fail") }
        catch let error as JSONWorkspace.Failure { XCTAssertEqual(error.line, 2); XCTAssertEqual(error.column, 7) }
    }
    func testUnicodeAndScalarRoots() throws {
        XCTAssertEqual(try JSONWorkspace.parse(#""\uD83D\uDE00""#), .string("😀"))
        for input in ["null", "true", "-0", "1e-20", #""文字列""#] {
            let value = try JSONWorkspace.parse(input)
            XCTAssertEqual(try JSONWorkspace.parse(value.encoded()), value)
        }
    }
    func testLimits() {
        XCTAssertThrowsError(try JSONWorkspace.parse(String(repeating: " ", count: 256 * 1024 + 1)))
        XCTAssertThrowsError(try JSONWorkspace.parse(String(repeating: "[", count: 50) + "0" + String(repeating: "]", count: 50)))
        XCTAssertThrowsError(try JSONWorkspace.parse("[" + Array(repeating: "0", count: 4000).joined(separator: ",") + "]"))
    }
    func testNestedBuilderOperations() throws {
        var root = try JSONWorkspace.parse(#"{"a":[1,{"b":false}]}"#)
        root.replace(at: [0, 1, 0], with: .string("changed"))
        XCTAssertEqual(root.value(at: [0, 1, 0]), .string("changed"))
        root.replace(at: [0, 0], with: nil)
        XCTAssertEqual(root.value(at: [0, 0, 0]), .string("changed"))
        XCTAssertEqual(try JSONWorkspace.parse(root.encoded()), root)
        root.replace(at: [], with: .array([])); XCTAssertEqual(root, .array([]))
    }
}
