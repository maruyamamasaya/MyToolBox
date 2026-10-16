import XCTest
@testable import MonitorKit

final class WindowLayoutTests: XCTestCase {
    func testTilingCoversOddWidthAndNegativeDisplayOrigin() {
        let area = CGRect(x: -1511, y: -800, width: 1511, height: 977)
        let current = CGRect(x: 0, y: 0, width: 700, height: 400)
        let thirds = [WindowLayout.thirdLeft, .thirdCenter, .thirdRight].map { $0.frame(in: area, current: current)! }
        XCTAssertEqual(thirds.first!.minX, area.minX)
        XCTAssertEqual(thirds[0].maxX, thirds[1].minX)
        XCTAssertEqual(thirds[1].maxX, thirds[2].minX)
        XCTAssertEqual(thirds.last!.maxX, area.maxX)
        for layout in WindowLayout.allCases where layout != .restore {
            XCTAssertTrue(area.contains(layout.frame(in: area, current: current)!), layout.rawValue)
        }
        let top = WindowLayout.top.frame(in: area, current: current)!
        let bottom = WindowLayout.bottom.frame(in: area, current: current)!
        XCTAssertEqual(top.maxY, bottom.minY)
        XCTAssertEqual(bottom.maxY, area.maxY)
    }
    func testCoordinateConversionAndCenterClamp() {
        XCTAssertEqual(WindowLayout.accessibilityFrame(CGRect(x: -1000, y: 100, width: 1000, height: 800), primaryHeight: 900), CGRect(x: -1000, y: 0, width: 1000, height: 800))
        XCTAssertEqual(WindowLayout.accessibilityFrame(CGRect(x: 0, y: 900, width: 1000, height: 800), primaryHeight: 900).minY, -800)
        let area = CGRect(x: 50, y: 25, width: 1000, height: 800)
        XCTAssertEqual(WindowLayout.center.frame(in: area, current: CGRect(x: 0, y: 0, width: 2000, height: 900)), area)
        XCTAssertNil(WindowLayout.restore.frame(in: area, current: area))
        XCTAssertEqual(WindowLayout.maximize.frame(in: area, current: .zero), area)
    }
}
