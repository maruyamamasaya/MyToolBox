import XCTest
@testable import MonitorKit

final class VisualThemeTests: XCTestCase {
    func testUpgradeFallbackAndPersistenceDoNotTouchMonitoringSettings() {
        let suite = "MyToolBoxThemeTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(VisualTheme.load(from: defaults), .blueCosmos)
        var monitoring = Preferences(); monitoring.interval = 5; monitoring.fahrenheit = true
        monitoring.save(to: defaults)
        for theme in VisualTheme.allCases {
            theme.save(to: defaults)
            XCTAssertEqual(VisualTheme.load(from: UserDefaults(suiteName: suite)!), theme)
            XCTAssertEqual(Preferences.load(from: defaults), monitoring)
        }
        defaults.set("unknown-future-theme", forKey: VisualTheme.storageKey)
        XCTAssertEqual(VisualTheme.load(from: defaults), .blueCosmos)
        defaults.set(42, forKey: VisualTheme.storageKey)
        XCTAssertEqual(VisualTheme.load(from: defaults), .blueCosmos)
    }
}
