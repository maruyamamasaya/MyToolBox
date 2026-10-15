import XCTest
@testable import MonitorKit

final class ScheduleCandidatesTests: XCTestCase {
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        BusinessDays.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
    func testHourBarBoundariesAndReverseRangeSelection() {
        var selection = ScheduleCandidates.HourSelection()
        XCTAssertNil(selection.click(9)); XCTAssertEqual(selection.anchor, 9)
        XCTAssertEqual(selection.click(21), .init(start: 9, end: 21)); XCTAssertNil(selection.anchor)
        XCTAssertNil(selection.click(18))
        XCTAssertEqual(selection.click(10), .init(start: 10, end: 18)); XCTAssertNil(selection.anchor)
        XCTAssertNil(selection.click(12))
        XCTAssertEqual(selection.click(13), .init(start: 12, end: 13))
    }
    func testHourBarEqualEndpointsCancelAndOutOfBoundsDoNotCommit() {
        var selection = ScheduleCandidates.HourSelection()
        XCTAssertNil(selection.click(8)); XCTAssertNil(selection.click(22)); XCTAssertNil(selection.anchor)
        XCTAssertNil(selection.click(21)); XCTAssertNil(selection.click(21)); XCTAssertEqual(selection.anchor, 21)
        XCTAssertNil(selection.click(23)); XCTAssertEqual(selection.anchor, 21)
        selection.cancel(); XCTAssertNil(selection.anchor)
        XCTAssertNil(selection.click(14)); XCTAssertEqual(selection.anchor, 14)
        XCTAssertEqual(selection.click(15), .init(start: 14, end: 15))
    }
    func testSingleSelectionUsesJapanDateAndMatchesOriginalOutput() throws {
        var state = ScheduleCandidates()
        XCTAssertEqual(try state.formatted(), "")
        state.choose(date(2026, 10, 15, 23))
        XCTAssertEqual(state.selected, [date(2026, 10, 15)])
        XCTAssertEqual(try state.formatted(), "10月15日（木）　12：00　〜　13：00")
        state.choose(date(2026, 10, 16)); XCTAssertEqual(state.selected.count, 1)
        state.choose(date(2026, 10, 16)); XCTAssertEqual(state.selected.count, 1)
    }
    func testMultipleDatesSortAcrossMonthsAndYearsAndCollapseToEarliest() throws {
        var state = ScheduleCandidates(); state.mode = .multiple
        for day in [date(2027, 1, 1), date(2026, 12, 31), date(2026, 10, 15)] { state.choose(day) }
        XCTAssertEqual(try state.formatted(), "・10月15日（木）　12：00　〜　13：00\n・12月31日（木）　12：00　〜　13：00\n・1月1日（金）　12：00　〜　13：00")
        state.mode = .single
        XCTAssertEqual(state.dates, [date(2026, 10, 15)])
        XCTAssertFalse(try state.formatted().hasPrefix("・"))
    }
    func testDefaultsOnlyAffectNewDatesAndReselectionRetainsPerDateHours() throws {
        var state = ScheduleCandidates(); state.mode = .multiple
        let first = date(2026, 10, 15), second = date(2026, 10, 16)
        state.choose(first); state.setTime(.init(start: 9, end: 11), for: first)
        state.defaults = .init(start: 15, end: 18); state.choose(second)
        XCTAssertEqual(state.time(for: first), .init(start: 9, end: 11))
        XCTAssertEqual(state.time(for: second), .init(start: 15, end: 18))
        state.choose(first); XCTAssertEqual(state.dates, [second])
        state.choose(first); XCTAssertEqual(state.time(for: first), .init(start: 9, end: 11))
        XCTAssertTrue(try state.formatted().contains("09：00　〜　11：00"))
        state.clear(); XCTAssertTrue(state.dates.isEmpty)
        state.choose(first); XCTAssertEqual(state.time(for: first), state.defaults)
    }
    func testAnyInvalidSelectedTimeBlocksWholeOutputAndRecovers() throws {
        var state = ScheduleCandidates(); state.mode = .multiple
        let first = date(2026, 10, 15), second = date(2026, 10, 16)
        state.choose(first); state.choose(second)
        for time in [ScheduleCandidates.Hours(start: 12, end: 12), .init(start: 13, end: 12), .init(start: -1, end: 13), .init(start: 0, end: 24)] {
            state.setTime(time, for: second)
            XCTAssertEqual(state.invalidDates, [second]); XCTAssertThrowsError(try state.formatted())
        }
        state.setTime(.init(start: 0, end: 23), for: second)
        XCTAssertTrue(state.invalidDates.isEmpty); XCTAssertTrue(try state.formatted().contains("00：00　〜　23：00"))
        state.setTime(.init(start: 23, end: 0), for: first); state.remove(first)
        XCTAssertNoThrow(try state.formatted())
    }
    func testLeapDayAndUTCBoundaryStayOnJapaneseDay() throws {
        var state = ScheduleCandidates()
        state.choose(ISO8601DateFormatter().date(from: "2028-02-28T15:00:00Z")!)
        XCTAssertEqual(try state.formatted(), "2月29日（火）　12：00　〜　13：00")
    }
}
