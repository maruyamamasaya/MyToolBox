import XCTest
@testable import MonitorKit

final class UserAgentInfoTests: XCTestCase {
    func testBrowserPrecedence() {
        let chrome = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0.0.0 Safari/537.36"
        XCTAssertEqual(UserAgentInfo(chrome + " Edg/130.0").browser, "Microsoft Edge 130.0")
        XCTAssertEqual(UserAgentInfo(chrome + " OPR/99.0").browser, "Opera 99.0")
        XCTAssertEqual(UserAgentInfo(chrome + " SamsungBrowser/25.0").browser, "Samsung Internet 25.0")
        XCTAssertEqual(UserAgentInfo(chrome).os, "Windows 10 / 11")
        XCTAssertEqual(UserAgentInfo(chrome).device, "Desktop")
    }
    func testMobileAndTabletClaims() {
        let iphone = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 CriOS/130.0 Mobile/15E148 Safari/604.1"
        XCTAssertEqual(UserAgentInfo(iphone).browser, "Google Chrome 130.0")
        XCTAssertEqual(UserAgentInfo(iphone).os, "iOS 18.0")
        XCTAssertEqual(UserAgentInfo(iphone).device, "Mobile")
        XCTAssertEqual(UserAgentInfo(iphone.replacingOccurrences(of: "CriOS", with: "FxiOS")).browser, "Mozilla Firefox 130.0")
        XCTAssertEqual(UserAgentInfo("Mozilla/5.0 (Linux; Android 14; Tablet) AppleWebKit/537.36 Chrome/130.0 Safari/537.36").device, "Tablet")
        XCTAssertEqual(UserAgentInfo("Mozilla/5.0 (X11; CrOS x86_64 16000) AppleWebKit/537.36 Chrome/130.0 Safari/537.36").os, "ChromeOS")
    }
    func testWebKitDoesNotClaimSafariAndUnknownDoesNotClaimDesktop() {
        let base = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
        XCTAssertEqual(UserAgentInfo(base).browser, "WebKit（ブラウザ名不明）")
        XCTAssertEqual(UserAgentInfo(base).os, "macOS 10.15.7")
        XCTAssertEqual(UserAgentInfo(base + " Version/18.0 Safari/605.1.15").browser, "Safari 18.0")
        for input in ["", "不明なUA", "Bot/1.0"] {
            XCTAssertEqual(UserAgentInfo(input).browser, "不明")
            XCTAssertEqual(UserAgentInfo(input).device, "不明")
        }
    }
}
