import XCTest
@testable import MonitorKit

final class CalendarAlmanacTests: XCTestCase {
    private func date(_ value: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm"; f.timeZone = BusinessDays.calendar.timeZone
        return f.date(from: value)!
    }
    func testReferencePhotoJanuary2027() {
        // Independent reference: user's January 2027 desk-calendar photograph.
        for (day,expected) in [(1,"仏滅"),(2,"大安"),(5,"友引"),(8,"赤口"),(11,"先負"),(22,"友引"),(31,"大安")] {
            XCTAssertEqual(CalendarAlmanac.annotation(for: date(String(format: "2027-01-%02d 12:00",day))).rokuyo, expected)
        }
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2027-01-05 12:00")).solarTerm,"小寒")
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2027-01-20 12:00")).solarTerm,"大寒")
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2027-01-08 12:00")).moonPhase,"● 新月")
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2027-01-22 12:00")).moonPhase,"○ 満月")
    }
    func testNoonAgeAndJSTCivilDay() {
        let a = CalendarAlmanac.annotation(for: date("2027-01-08 00:00"))
        XCTAssertEqual(a.moonAge!, 396.0 / 1440.0, accuracy: 0.000001)
        XCTAssertEqual(a, CalendarAlmanac.annotation(for: date("2027-01-08 23:59")))
        // The full moon occurs at 21:17: the age still uses the preceding new moon at noon.
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2027-01-22 12:00")).moonAge!, 14 + 6.6/24, accuracy: 0.000001)
    }
    func testLeapSixthMonth2025AndUnsupportedYears() {
        // 2025-07-25 starts the leap sixth month; same rokuyo reset as month six.
        XCTAssertEqual(CalendarAlmanac.annotation(for: date("2025-07-25 12:00")).rokuyo,"赤口")
        for year in [2023,2028] {
            let a = CalendarAlmanac.annotation(for: date("\(year)-01-01 12:00"))
            XCTAssertNil(a.rokuyo); XCTAssertNil(a.solarTerm); XCTAssertNil(a.moonPhase); XCTAssertNil(a.moonAge)
        }
    }
}
