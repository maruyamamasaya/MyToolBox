import XCTest
@testable import MonitorKit

final class TimeToolsTests: XCTestCase {
    func testPauseResumeAndDelayedRefresh() {
        let origin = Date(timeIntervalSince1970: 1000)
        var timer = UtilityTimer(); timer.duration = 60
        timer.start(at: origin)
        XCTAssertEqual(timer.remaining(at: origin.addingTimeInterval(20)), 40)
        timer.pause(at: origin.addingTimeInterval(20))
        XCTAssertEqual(timer.remaining(at: origin.addingTimeInterval(120)), 40)
        timer.start(at: origin.addingTimeInterval(120))
        XCTAssertTrue(timer.finished(at: origin.addingTimeInterval(180)))
        XCTAssertEqual(timer.remaining(at: origin.addingTimeInterval(180)), 0)
        timer.reset(); XCTAssertEqual(timer.remaining(at: origin), 60)
    }
    func testStopwatchAndRestoredDeadline() throws {
        let origin = Date(timeIntervalSince1970: 1000)
        var timer = UtilityTimer(); timer.countdown = false; timer.start(at: origin)
        let restored = try JSONDecoder().decode(UtilityTimer.self, from: JSONEncoder().encode(timer))
        XCTAssertEqual(restored.elapsed(at: origin.addingTimeInterval(7200)), 7200)
        XCTAssertFalse(restored.finished(at: origin.addingTimeInterval(7200)))
        XCTAssertEqual(restored.elapsed(at: origin.addingTimeInterval(-10)), 0)
    }
    func testWorkAndOvernight() throws {
        let work = try TimeCalculation.work("09:15", "18:30", rest: "01:00")
        XCTAssertEqual(work.gross, 555); XCTAssertEqual(work.net, 495)
        XCTAssertEqual(try TimeCalculation.interval("23:30", "01:15"), 105)
        XCTAssertEqual(try TimeCalculation.interval("09:00", "09:00"), 0)
        XCTAssertThrowsError(try TimeCalculation.work("09:00", "10:00", rest: "02:00"))
        for invalid in ["24:00", "12:60", "-1:00", "abc", "1:2:3", "０９:００"] {
            XCTAssertThrowsError(try TimeCalculation.minutes(invalid))
        }
    }
    func testMultipleRangesAndValidation() throws {
        XCTAssertEqual(try TimeCalculation.total("09:00 - 10:30\n11:15〜12:00\n13:00～16:45"), 360)
        XCTAssertEqual(try TimeCalculation.total("23:00 - 01:00\n\n00:00 - 01:00"), 180)
        XCTAssertThrowsError(try TimeCalculation.total(""))
        XCTAssertThrowsError(try TimeCalculation.total("09:00 - 10:00 - 11:00"))
        XCTAssertThrowsError(try TimeCalculation.total(String(repeating: "09:00 - 10:00\n", count: 1001)))
    }
}
