import XCTest
@testable import MonitorKit

final class LocalToolsTests: XCTestCase {
    func testToneChannelsFadesAndSequence() {
        let left = AudioSignal.stereo(time: 0.101, sequence: 0, volume: 0.15)
        XCTAssertNotEqual(left.0, 0); XCTAssertEqual(left.1, 0)
        let right = AudioSignal.stereo(time: 0.901, sequence: 2, volume: 0.15)
        XCTAssertEqual(right.0, 0); XCTAssertNotEqual(right.1, 0)
        let both = AudioSignal.stereo(time: 1.701, sequence: 2, volume: 0.15)
        XCTAssertNotEqual(both.0, 0); XCTAssertEqual(both.0, both.1)
        XCTAssertEqual(AudioSignal.stereo(time: 0, sequence: 0, volume: 0.15).0, 0)
        XCTAssertEqual(AudioSignal.stereo(time: 0.6, sequence: 0, volume: 0.15).0, 0)
        XCTAssertLessThanOrEqual(abs(AudioSignal.stereo(time: 0.101, sequence: 0, volume: 100).0), 0.6)
    }
    func testRMSAndPeakAreDigitalLevels() {
        let values: [Float] = [0.5, -0.5, 0.5, -0.5]
        let level = values.withUnsafeBufferPointer { AudioSignal.levels($0) }
        XCTAssertEqual(level.rms, 0.5, accuracy: 0.0001); XCTAssertEqual(level.peak, 0.5)
        XCTAssertEqual([Float](repeating: 0, count: 100).withUnsafeBufferPointer { AudioSignal.levels($0).rms }, 0)
    }
    func testCSVQuotedUnicodeAndLineBreakRoundTrip() throws {
        let rows = [["名前", "引用", "改行", "空"], ["a,b", "a\"b", "a\r\nb\nc", ""]]
        XCTAssertEqual(try CSVDocument.parse("\u{FEFF}" + CSVDocument.serialize(rows) + "\r\n"), rows)
    }
    func testCSVRaggedAndTrailingEmptyFields() throws {
        for rows in [[[""]], [["a"], [""]]] { XCTAssertEqual(try CSVDocument.parse(CSVDocument.serialize(rows)), rows) }
        XCTAssertEqual(try CSVDocument.parse("a,b,\r\n1\r\n2,3,"), [["a","b",""],["1","",""],["2","3",""]])
        XCTAssertEqual(try CSVDocument.parse("\"\""), [[""]])
        XCTAssertEqual(try CSVDocument.parse(","), [["", ""]])
    }
    func testCSVRejectsMalformedAndOversizedInput() {
        for input in ["", " \n", "\"unclosed", "a\"b,c", "\"a\"b,c", Array(repeating: "x", count: 201).joined(separator: ","), Array(repeating: "x", count: 20_001).joined(separator: "\n")] {
            XCTAssertThrowsError(try CSVDocument.parse(input))
        }
    }
    func testCSVDecoding() throws {
        XCTAssertEqual(try CSVDocument.decode(Data("名前,値".utf8)).1, "UTF-8")
        let sjis = Data([0x96, 0xbc, 0x91, 0x4f, 0x2c, 0x31])
        XCTAssertEqual(try CSVDocument.decode(sjis).0, "名前,1")
        XCTAssertThrowsError(try CSVDocument.decode(Data(repeating: 0, count: 8 * 1024 * 1024 + 1)))
    }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { BusinessDays.calendar.date(from: DateComponents(year: y, month: m, day: d))! }
    private func source() throws -> BusinessDays {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try BusinessDays(data: Data(contentsOf: root.appendingPathComponent("Resources/JapaneseHolidays.json")))
    }
    func testOfficialGoldenWeekInclusiveAndCustomNoDoubleCount() throws {
        let model = try source()
        let r = try model.calculate(start: date(2026,5,1), end: date(2026,5,6))
        XCTAssertEqual(r.total, 6); XCTAssertEqual(r.weekends, 2); XCTAssertEqual(r.holidays, 3); XCTAssertEqual(r.business, 1)
        let custom = try model.calculate(start: date(2026,5,1), end: date(2026,5,6), custom: ["2026-05-01", "2026-05-02", "2026-05-04"])
        XCTAssertEqual(custom.business, 0); XCTAssertEqual(custom.holidays, 4); XCTAssertEqual(custom.weekends, 2)
    }
    func testOfficialOlympicHolidayChangesAndRangeErrors() throws {
        let model = try source()
        XCTAssertNotNil(model.holidays["2020-08-10"]); XCTAssertNil(model.holidays["2020-08-11"])
        XCTAssertNotNil(model.holidays["2021-07-22"]); XCTAssertNil(model.holidays["2021-07-19"])
        XCTAssertThrowsError(try model.calculate(start: date(2028,1,1), end: date(2028,1,1)))
        XCTAssertThrowsError(try model.calculate(start: date(2026,1,2), end: date(2026,1,1)))
        XCTAssertEqual(try model.calculate(start: date(2026,10,15), end: date(2026,10,15)).business, 1)
    }
}
