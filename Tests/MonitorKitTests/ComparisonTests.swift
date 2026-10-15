import XCTest
@testable import MonitorKit
final class ComparisonTests: XCTestCase {
    func testInsertedBlankLineKeepsOriginalLineNumbers() throws {
        let r = try TextComparison.compare("aaa\nbbb\nccc\nddd", "aaa\nbbb\n\nccc\nddd")
        XCTAssertEqual(r.rows.map(\.kind), [.same,.same,.added,.same,.same])
        XCTAssertEqual(r.rows[2].right, ""); XCTAssertNil(r.rows[2].left)
        XCTAssertEqual(r.rows[3].leftNumber, 3); XCTAssertEqual(r.rows[3].rightNumber, 4)
    }
    func testChangedWordsAndUTF16GraphemeBoundaries() throws {
        let r = try TextComparison.compare("server=prod\ntimeout=30", "server=production\ntimeout=60")
        XCTAssertEqual(r.changed, 2); XCTAssertEqual(r.removed, 0); XCTAssertEqual(r.added, 0)
        XCTAssertEqual(r.rows[0].leftSpan, .init(location: 7, length: 4))
        XCTAssertEqual(r.rows[0].rightSpan, .init(location: 7, length: 10))
        let spans = TextComparison.changedSpans("👨‍👩‍👧‍👦 猫", "👨‍👩‍👧‍👦 犬")
        XCTAssertEqual(spans.0.location, "👨‍👩‍👧‍👦 ".utf16.count)
        XCTAssertEqual(spans.0.length, 1); XCTAssertEqual(spans.1.length, 1)
    }
    func testEmptyOneSidedAndTrailingNewlineAreDistinct() throws {
        XCTAssertTrue(try TextComparison.compare("", "").rows.isEmpty)
        let inserted = try TextComparison.compare("", "a\n")
        XCTAssertEqual(inserted.rows.map(\.kind), [.added,.added]); XCTAssertEqual(inserted.rows[1].right, "")
        let removed = try TextComparison.compare("a\n", "a")
        XCTAssertEqual(removed.rows.map(\.kind), [.same,.removed])
        XCTAssertEqual(try TextComparison.compare("a\r\nb\rc", "a\nb\nc").same, 3)
    }
    func testRowAlignmentConservesBothInputsAcrossManyEditPatterns() throws {
        var seed: UInt64 = 42
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1; return seed }
        let vocabulary = ["a", "b", "", "猫", "value=10", "value=20"]
        for _ in 0..<80 {
            let a = (0..<Int(next() % 12)).map { _ in vocabulary[Int(next() % UInt64(vocabulary.count))] }.joined(separator: "\n")
            let b = (0..<Int(next() % 12)).map { _ in vocabulary[Int(next() % UInt64(vocabulary.count))] }.joined(separator: "\n")
            let rows = try TextComparison.compare(a,b).rows
            XCTAssertEqual(rows.compactMap(\.left), TextComparison.split(a))
            XCTAssertEqual(rows.compactMap(\.right), TextComparison.split(b))
            XCTAssertEqual(rows.compactMap(\.leftNumber), Array(1...max(1, TextComparison.split(a).count)).prefix(TextComparison.split(a).count).map { $0 })
            XCTAssertEqual(rows.compactMap(\.rightNumber), Array(1...max(1, TextComparison.split(b).count)).prefix(TextComparison.split(b).count).map { $0 })
            for row in rows where row.kind == .same { XCTAssertEqual(row.left, row.right) }
        }
    }
    func testDiffLimitsRejectInsteadOfTruncating() throws {
        XCTAssertThrowsError(try TextComparison.compare(String(repeating: "a\n", count: 1000), "a"))
        XCTAssertThrowsError(try TextComparison.compare(String(repeating: "x", count: 262_145), "x"))
        let r = try TextComparison.compare(Array(repeating: "x", count: 1000).joined(separator: "\n"), Array(repeating: "x", count: 1000).joined(separator: "\n"))
        XCTAssertEqual(r.same, 1000)
    }
    func testListComparisonSetsDeduplicateAndKeepFirstOrder() throws {
        let r = try ListComparison.compare("apple\nbanana\norange\napple", "banana\norange\ngrape", options: .init())
        XCTAssertEqual(r.leftCount, 3); XCTAssertEqual(r.rightCount, 3)
        XCTAssertEqual(r.common, ["banana", "orange"]); XCTAssertEqual(r.onlyLeft, ["apple"]); XCTAssertEqual(r.onlyRight, ["grape"])
        var options = ListComparison.Options(); options.ignoreCase = true
        XCTAssertEqual(try ListComparison.compare("Apple\nPEAR", "apple\npear", options: options).common, ["Apple", "PEAR"])
    }
    func testListWhitespaceEmptyAndCaseOptions() throws {
        var options = ListComparison.Options(); options.trim = false
        let r = try ListComparison.compare(" a \n", "a", options: options)
        XCTAssertEqual(r.common, []); XCTAssertEqual(r.onlyLeft, [" a "]); XCTAssertEqual(r.onlyRight, ["a"])
        options.ignoreEmpty = false
        XCTAssertEqual(try ListComparison.compare("\n", "\n\n", options: options).common, [""])
        XCTAssertTrue(try ListComparison.compare("", "", options: options).common.isEmpty)
        XCTAssertThrowsError(try ListComparison.compare(String(repeating: "x\n", count: 20_001), "", options: options))
    }
}
