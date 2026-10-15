import XCTest
@testable import MonitorKit
final class LineUtilityTests: XCTestCase {
    func testNaturalSortKeepsLargeIntegersAndStableLeadingZeros() throws {
        var o = LineTools.SortOptions()
        XCTAssertEqual(try LineTools.sort("server10\nserver2\nserver1\nserver20", options: o), ["server1","server2","server10","server20"])
        XCTAssertEqual(try LineTools.sort("item9007199254740993\nitem9007199254740992", options: o), ["item9007199254740992","item9007199254740993"])
        XCTAssertEqual(try LineTools.sort("02\n2\n002", options: o), ["02","2","002"])
        o.descending = true
        XCTAssertEqual(try LineTools.sort("b\n\na\n   ", options: o), ["b","a","","   "])
    }
    func testSortNumericAlphabeticDeduplicateAndRestore() throws {
        var o = LineTools.SortOptions(); o.mode = .number
        XCTAssertEqual(try LineTools.sort("100\n20\n3\n-2.5e2\n12px", options: o), ["-2.5e2","3","20","100","12px"])
        o.mode = .alphabetic; o.removeDuplicates = true
        XCTAssertEqual(try LineTools.sort("  b  \n a\nb\nb", options: o), [" a","  b  ","b"])
        o.originalOrder = true
        XCTAssertEqual(try LineTools.sort("b\r\na\rb\n", options: o), ["b","a","b",""])
    }
    func testFilterConjunctionDisjunctionAndSourceNumbers() throws {
        var o = LineTools.FilterOptions(); o.conditions = [.init(value: "ERROR"), .init(value: "api")]; o.showNumbers = true
        XCTAssertEqual(try LineTools.filter("ERROR api\nERROR db\nINFO api", options: o).output, "1: ERROR api")
        o.any = true; o.conditions = [.init(value: "ERROR"), .init(value: "WARN")]
        XCTAssertEqual(try LineTools.filter("ERROR api\nWARN db\nINFO ok", options: o).count, 2)
        o.ignoreCase = true; o.conditions = [.init(type: .equals, value: "error")]
        XCTAssertEqual(try LineTools.filter("Error\nERROR\ninfo", options: o).count, 2)
        o.conditions = [.init(value: "")]
        XCTAssertEqual(try LineTools.filter("\nERROR\n", options: o).count, 0)
    }
    func testFilterNegativePrefixSuffixAndWhitespace() throws {
        var o = LineTools.FilterOptions(); o.conditions = [.init(type: .notContains, value: "failed"), .init(type: .starts, value: "api"), .init(type: .ends, value: "ready")]
        XCTAssertEqual(try LineTools.filter("api ready\napi failed\nweb ready", options: o).output, "api ready")
    }
    func testDuplicateGroupsKeepFirstDisplayAndOriginalPositions() throws {
        var o = LineTools.DuplicateOptions(); o.ignoreCase = true
        let r = try LineTools.duplicates(" Apple \napple\nAPPLE\nbanana\n\n", options: o)
        XCTAssertEqual(r.lines, 6); XCTAssertEqual(r.total, 4); XCTAssertEqual(r.unique, 2); XCTAssertEqual(r.extra, 2)
        XCTAssertEqual(r.groups.count, 1); XCTAssertEqual(r.groups[0].value, "Apple"); XCTAssertEqual(r.groups[0].lineNumbers, [1,2,3])
        o.ignoreEmpty = false
        XCTAssertEqual(try LineTools.duplicates("a\n\n\na", options: o).groups.map(\.value), ["a", ""])
    }
    func testListQuotedCustomJSONAndSpaces() throws {
        var o = ListConverter.Options(); o.input = .comma
        XCTAssertEqual(try ListConverter.convert("\"Tokyo, Japan\",Osaka", options: o).output, "Tokyo, Japan\nOsaka")
        o.input = .custom; o.separator = " / "
        XCTAssertEqual(try ListConverter.convert("apple / banana / orange", options: o).count, 3)
        o.input = .auto
        XCTAssertEqual(try ListConverter.convert("New York Los Angeles", options: o).count, 1)
        o.input = .json
        XCTAssertEqual(try ListConverter.convert("[\"apple\",\"banana\"]", options: o).output, "apple\nbanana")
        XCTAssertThrowsError(try ListConverter.convert("not JSON", options: o))
        o.input = .space; o.removeEmpty = false
        XCTAssertEqual(try ListConverter.convert(" a   b ", options: o).count, 4)
        o.input = .comma
        XCTAssertThrowsError(try ListConverter.convert("\"unclosed,a", options: o))
    }
    func testListCleanOrderPrefixAndOutputQuoting() throws {
        var o = ListConverter.Options(); o.deduplicate = true; o.order = .ascending; o.prefix = "ID_"; o.suffix = "_x"
        XCTAssertEqual(try ListConverter.convert("item10\nitem2\nitem1\nitem2\n", options: o).output, "ID_item1_x\nID_item2_x\nID_item10_x")
        o = .init(); o.format = .sql
        XCTAssertEqual(try ListConverter.convert("O'Reilly\nbook", options: o).output, "IN ('O''Reilly','book')")
        o.input = .json; o.format = .json
        let result = try ListConverter.convert("[\"a\\\"b\",\"line\\nbreak\"]", options: o)
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: Data(result.output.utf8)), ["a\"b","line\nbreak"])
    }
    func testReplacementLiteralDollarWholeLineAndUnicode() throws {
        var o = StringReplacer.Options(); o.mode = .replace; o.query = "apple"; o.replacement = "orange"
        let r = try StringReplacer.run("Apple apple", options: o)
        XCTAssertEqual(r.output, "orange orange"); XCTAssertEqual(r.count, 2)
        o.caseSensitive = true
        XCTAssertEqual(try StringReplacer.run("Apple apple", options: o).count, 1)
        o.query = "$5"; o.replacement = "$10"
        XCTAssertEqual(try StringReplacer.run("$5 and $5", options: o).output, "$10 and $10")
        o.query = "apple"; o.replacement = "x"; o.wholeLine = true
        XCTAssertEqual(try StringReplacer.run("apple\napple_test", options: o).output, "x\napple_test")
        o.wholeLine = false; o.query = "猫"; o.replacement = "犬"
        XCTAssertEqual(try StringReplacer.run("😀猫", options: o).matches[0].location, 2)
    }
    func testRegexCapturesDotAllAndInvalidPattern() throws {
        var o = StringReplacer.Options(); o.mode = .replace; o.regex = true; o.dotAll = true; o.query = "a.b"; o.replacement = "ok"
        XCTAssertEqual(try StringReplacer.run("a\nb", options: o).output, "ok")
        o.query = "(cat)-(dog)"; o.replacement = "$2/$1/$$/$&"
        XCTAssertEqual(try StringReplacer.run("cat-dog", options: o).output, "dog/cat/$/cat-dog")
        o.query = "["
        XCTAssertThrowsError(try StringReplacer.run("text", options: o))
        o.query = "^"; o.replacement = "x"
        XCTAssertEqual(try StringReplacer.run("😀", options: o).output, "x😀")
    }
    func testSequentialRulesDeletionAndMalformedRule() throws {
        var o = StringReplacer.Options(); o.mode = .rules; o.rules = "apple => orange\norange => grape\ntest => sample"
        let r = try StringReplacer.run("apple test", options: o)
        XCTAssertEqual(r.output, "grape sample"); XCTAssertEqual(r.count, 3)
        o.rules = "invalid"
        XCTAssertThrowsError(try StringReplacer.run("text", options: o))
        o.mode = .delete; o.multipleDelete = true; o.deletionList = "aa\nbb"
        XCTAssertEqual(try StringReplacer.run("aa bb aa", options: o).output, "  ")
    }
    func testBoundsRejectLargeInputsAndExpansion() throws {
        XCTAssertThrowsError(try LineTools.lines(String(repeating: "x\n", count: 20_001)))
        var o = StringReplacer.Options(); o.regex = true; o.query = "x"
        XCTAssertThrowsError(try StringReplacer.run(String(repeating: "x", count: 262_145), options: o))
        o.mode = .replace; o.query = "x"; o.replacement = String(repeating: "z", count: 65_536)
        XCTAssertThrowsError(try StringReplacer.run(String(repeating: "x", count: 65), options: o))
    }
}
