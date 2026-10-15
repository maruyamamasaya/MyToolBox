import XCTest
@testable import MonitorKit

final class TextToolsTests: XCTestCase {
    func testSequentialStartEndBlankNegativeAndNewlineNormalization() throws {
        var o = SequentialText.Options()
        XCTAssertEqual(try SequentialText.generate("a\r\nb\rc", options: o).output, "1. a\n2. b\n3. c")
        o.start = 10; o.increment = 10; o.separator = ":"
        let skipped = try SequentialText.generate("a\n\nb", options: o)
        XCTAssertEqual(skipped.output, "10:a\n\n20:b"); XCTAssertEqual(skipped.lines, 3); XCTAssertEqual(skipped.numbered, 2)
        o.start = -2; o.increment = -3; o.digits = 3; o.prefix = "item-"; o.suffix = "!"; o.atEnd = true; o.separator = "_"; o.numberEmptyLines = true
        XCTAssertEqual(try SequentialText.generate("東京\n\n大阪", options: o).output, "item-東京_-002!\nitem-_-005!\nitem-大阪_-008!")
        o.increment = 0
        XCTAssertEqual(try SequentialText.generate("x\ny", options: o).numbered, 2)
        XCTAssertEqual(try SequentialText.generate("", options: o).lines, 0)
    }
    func testSequentialOverflowAndBounds() throws {
        var o = SequentialText.Options(); o.start = Int64.max
        XCTAssertEqual(try SequentialText.generate("x", options: o).numbered, 1)
        XCTAssertThrowsError(try SequentialText.generate("x\ny", options: o))
        o.start = Int64.min; o.increment = -1
        XCTAssertEqual(try SequentialText.generate("x", options: o).output, "-9223372036854775808. x")
        XCTAssertThrowsError(try SequentialText.generate("x\ny", options: o))
        XCTAssertThrowsError(try SequentialText.generate(String(repeating: "x", count: 1_048_577), options: o))
    }
    func testClipboardDetectionAndQuotedTSV() throws {
        let parsed = try ClipboardTable.parse("1001\t山田太郎\t営業部\r\n1002\t佐藤花子\t開発部")
        XCTAssertEqual(parsed.delimiter, .tab); XCTAssertEqual(parsed.rows[1], ["1002", "佐藤花子", "開発部"])
        XCTAssertEqual(try ClipboardTable.parse("1\t\"a\tb\"\n2\t\"a\"\"b\"").rows, [["1", "a\tb"], ["2", "a\"b"]])
        XCTAssertEqual(try ClipboardTable.parse("A B\nC D").delimiter, .space)
        XCTAssertEqual(try ClipboardTable.parse("A\nB").delimiter, .newline)
        XCTAssertEqual(try ClipboardTable.parse("").rows, [])
        XCTAssertThrowsError(try ClipboardTable.parse("a,\"broken"))
    }
    func testClipboardColumnSelectionCleaningAndStableDeduplication() throws {
        let rows = [[" 1 ", "営業　　部", "x"], ["1", "営業 部", "y"], ["", "", "z"], ["2", "開発", "x"]]
        var o = ClipboardTable.Options(); o.removeDuplicates = true; o.removeEmpty = true; o.collapseSpaces = true; o.quote = .double
        XCTAssertEqual(try ClipboardTable.format(rows, columns: [0,1], options: o), "\"1\",\"営業 部\"\n\"2\",\"開発\"")
        XCTAssertEqual(try ClipboardTable.format(rows, columns: [], options: o), "")
        o.format = .newline; o.quote = .none
        XCTAssertEqual(try ClipboardTable.format(rows, columns: [2], options: o), "x\ny\nz")
    }
    func testClipboardMarkdownAndSQLEscaping() throws {
        var o = ClipboardTable.Options(); o.format = .markdown
        XCTAssertEqual(try ClipboardTable.format([["A", "B"], ["x|y", "1\n2"]], columns: [0,1], options: o), "| A | B |\n| --- | --- |\n| x\\|y | 1<br>2 |")
        o.format = .sqlIn
        XCTAssertEqual(try ClipboardTable.format([["1001"], ["O'Reilly"]], columns: [0], options: o), "IN ('1001','O''Reilly')")
        o.format = .sqlValues
        XCTAssertEqual(try ClipboardTable.format([["O'Reilly"]], columns: [0], options: o), "'O''Reilly'")
    }
    func testCleanerPreservesNormalTextAndRemovesSpecificNoise() throws {
        XCTAssertEqual(try TextCleaner.clean("見出し\r\n本文\r次の行"), "見出し\n本文\n次の行")
        XCTAssertEqual(try TextCleaner.clean("Hello\u{a0}world ゼロ\u{200b}幅\u{feff}文字"), "Hello world ゼロ幅文字")
        XCTAssertEqual(try TextCleaner.clean("  空白と\n改行は残す  "), "  空白と\n改行は残す  ")
        XCTAssertEqual(try TextCleaner.clean("1行目\n \t\n　\n2行目"), "1行目\n2行目")
        XCTAssertEqual(try TextCleaner.clean("・\n文字\n・　\n　次の項目"), "・文字\n・次の項目")
        XCTAssertEqual(try TextCleaner.clean("・\n・次の項目"), "・\n・次の項目")
    }
    func testCSVRealFileBOMAndRoundTripWithEditedContent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("roundtrip.csv")
        let rows = [["名前", "メモ", "番号"], ["東京", "a,b", "10"], ["大阪", "引用\"符", "2"], ["福岡・編集済み,\"確認\"\n追加行", "1行目\n2行目", "3"], ["", "", ""]]
        try CSVDocument.encoded(rows).write(to: file, options: .atomic)
        let data = try Data(contentsOf: file)
        XCTAssertEqual(Array(data.prefix(3)), [0xef,0xbb,0xbf])
        XCTAssertEqual(try CSVDocument.parse(CSVDocument.decode(data).0), rows)
        XCTAssertThrowsError(try CSVDocument.encoded([[String(repeating: "\"", count: 4_194_304)]]))
    }
}
