import XCTest
@testable import MonitorKit

final class PaletteColorTests: XCTestCase {
    func testHexNormalizationAndRGB() throws {
        XCTAssertEqual(try XCTUnwrap(PaletteColor(hex: " #aBc \n")).hex, "#AABBCC")
        XCTAssertEqual(try XCTUnwrap(PaletteColor(hex: "4caf50")).rgb, "rgb(76, 175, 80)")
        XCTAssertEqual(PaletteColor(hex: "000000")?.rgb, "rgb(0, 0, 0)")
        XCTAssertEqual(PaletteColor(hex: "FFFFFF")?.rgb, "rgb(255, 255, 255)")
        for value in ["", "#", "##123456", "１２３", "12345", "12345678", "GGGGGG", "12 3456"] { XCTAssertNil(PaletteColor(hex: value), value) }
    }
    func testReferencePaletteAndGradient() throws {
        let colors = PaletteColor.groups.flatMap { $0.1 }
        XCTAssertEqual(colors.count, 120)
        XCTAssertEqual(Set(colors).count, 120)
        for hex in colors { XCTAssertNotNil(PaletteColor(hex: hex)) }
        for item in PaletteColor.recommendations {
            let start = try XCTUnwrap(PaletteColor(hex: item.1)), end = try XCTUnwrap(PaletteColor(hex: item.2))
            XCTAssertEqual(start.gradient(to: end, degrees: 135), "linear-gradient(135deg, \(item.1), \(item.2))")
        }
    }
}
