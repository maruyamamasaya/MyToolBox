import XCTest
@testable import MonitorKit

final class PersonalCountdownTests: XCTestCase {
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func testCalendarDaysAcrossMidnightAndLeapDay() {
        var entry = PersonalCountdown(); entry.title = "40歳まで"
        entry.date = date("2028-03-01T00:00:00+09:00")
        XCTAssertEqual(entry.remainingDays(now: date("2028-02-28T23:59:00+09:00")), 2)
        XCTAssertEqual(entry.remainingDays(now: date("2028-03-01T23:00:00+09:00")), 0)
        XCTAssertEqual(entry.remainingDays(now: date("2028-03-02T00:00:00+09:00")), -1)
    }
    func testHourEstimateAndCompletion() throws {
        var entry = PersonalCountdown(); entry.title = "1万時間まで"; entry.kind = .hours
        entry.completedHours = 9_995; entry.hoursPerDay = 2
        entry.date = date("2026-10-19T09:00:00+09:00")
        try entry.validate()
        let end = entry.targetDate
        XCTAssertEqual(end, date("2026-10-21T12:00:00+09:00"))
        XCTAssertEqual(entry.remainingDays(now: entry.date), 2)
        XCTAssertEqual(entry.remainingDays(now: date("2026-10-20T09:00:00+09:00")), 1)
        XCTAssertEqual(entry.targetDate, end)
        entry.date = date("2026-10-19T23:59:00+09:00")
        XCTAssertEqual(entry.targetDate, end)
        XCTAssertEqual(entry.remainingDays(now: date("2026-10-22T09:00:00+09:00")), -1)
        entry.completedHours = 10_001
        XCTAssertEqual(entry.remainingDays(now: entry.date), 0)
        entry.hoursPerDay = 0; XCTAssertThrowsError(try entry.validate())
        entry.hoursPerDay = .nan; XCTAssertThrowsError(try entry.validate())
        entry.hoursPerDay = 25; XCTAssertThrowsError(try entry.validate())
    }
    func testElapsedHoursTarget() throws {
        var entry = PersonalCountdown(); entry.title = "10000時間"; entry.kind = .elapsed
        entry.date = date("2026-01-01T00:00:00+09:00")
        try entry.validate()
        XCTAssertEqual(entry.targetDate?.timeIntervalSince(entry.date), 36_000_000)
        XCTAssertEqual(entry.remainingDays(now: entry.date), 416)
    }
    func testInlineProgressKeepsStartAsCalculationBase() throws {
        var entry = PersonalCountdown(); entry.title = "学習"; entry.kind = .hours
        entry.date = date("2026-10-01T15:00:00+09:00")
        entry.targetHours = 100; entry.hoursPerDay = 2
        let start = entry.date
        try entry.updateCompletedHours(20)
        XCTAssertEqual(entry.date, start)
        XCTAssertEqual(entry.targetDate, date("2026-11-10T00:00:00+09:00"))
        try entry.updateCompletedHours(22)
        XCTAssertEqual(entry.date, start)
        XCTAssertEqual(entry.targetDate, date("2026-11-09T00:00:00+09:00"))
        let saved = entry
        XCTAssertThrowsError(try entry.updateCompletedHours(-1))
        XCTAssertEqual(entry, saved)
        XCTAssertThrowsError(try entry.updateCompletedHours(.nan))
        XCTAssertEqual(entry, saved)
        let data = try JSONEncoder().encode(entry)
        XCTAssertEqual(try JSONDecoder().decode(PersonalCountdown.self, from: data), entry)
        var previous = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        previous["progressDate"] = Date().timeIntervalSinceReferenceDate
        let decoded = try JSONDecoder().decode(PersonalCountdown.self, from: JSONSerialization.data(withJSONObject: previous))
        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.targetDate, entry.targetDate)
    }
    func testMultipleGoalsPersistenceAndCorruption() throws {
        let suite = "PersonalCountdownTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(try PersonalCountdownStore.load(defaults: defaults), [])
        var one = PersonalCountdown(); one.title = "誕生日"
        var two = PersonalCountdown(); two.title = "学習"; two.kind = .hours
        try PersonalCountdownStore.save([one, two], defaults: defaults)
        XCTAssertEqual(try PersonalCountdownStore.load(defaults: defaults), [one, two])
        two.title = "編集後"; try PersonalCountdownStore.save([two], defaults: defaults)
        XCTAssertEqual(try PersonalCountdownStore.load(defaults: defaults), [two])
        defaults.set(Data("broken".utf8), forKey: PersonalCountdownStore.key)
        XCTAssertThrowsError(try PersonalCountdownStore.load(defaults: defaults))
        XCTAssertEqual(defaults.data(forKey: PersonalCountdownStore.key), Data("broken".utf8))
    }
}
