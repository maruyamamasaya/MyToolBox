import XCTest
@testable import MonitorKit

final class TextCodecTests: XCTestCase {
    func testBase64RoundTripAndWhitespace() throws {
        let text = "日本語🙂\n\0"
        let encoded = try TextCodec.convert(text, mode: .base64Encode).text
        XCTAssertEqual(try TextCodec.convert(" \n" + encoded + "\t", mode: .base64Decode).text, text)
        XCTAssertEqual(try TextCodec.convert("", mode: .base64Decode).text, "")
        for invalid in ["a", "!!!!", "====", "a===", "AA=A"] { XCTAssertThrowsError(try TextCodec.convert(invalid, mode: .base64Decode)) }
        XCTAssertThrowsError(try TextCodec.convert("/w==", mode: .base64Decode))
    }
    func testEscapeRoundTripAndUnknownSequences() throws {
        let text = "日本語🙂\r\n\t\\\"\0"
        let escaped = try TextCodec.convert(text, mode: .escape).text
        XCTAssertEqual(try TextCodec.convert(escaped, mode: .restore).text, text)
        let result = try TextCodec.convert("\\q\\", mode: .restore)
        XCTAssertEqual(result.text, "\\q\\")
        XCTAssertFalse(result.warning.isEmpty)
        XCTAssertEqual(try TextCodec.convert("\\\\n", mode: .restore).text, "\\n")
    }
    func testVisualizationAndInspection() throws {
        XCTAssertEqual(try TextCodec.convert(" 　\t\r\n\0", mode: .visualize).text, "·□→␍↵\n␀")
        let report = try TextCodec.convert("Aあア漢🙂\n\u{200B}\u{FFFD}", mode: .inspect).text
        for expected in ["ASCII: 2", "ひらがな: 1", "カタカナ: 1", "漢字: 1", "確認対象: 2件", "2行目  U+200B", "Unicode置換文字"] { XCTAssertTrue(report.contains(expected), expected) }
        let many = try TextCodec.convert(String(repeating: "\u{200B}", count: 1001), mode: .inspect).text
        XCTAssertTrue(many.contains("先頭1,000件のみ表示"))
    }
    func testInputLimit() {
        XCTAssertThrowsError(try TextCodec.convert(String(repeating: "a", count: 1_048_577), mode: .base64Encode))
    }
}
