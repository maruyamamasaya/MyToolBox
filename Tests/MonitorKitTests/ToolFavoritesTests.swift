import XCTest
@testable import MonitorKit

final class ToolFavoritesTests: XCTestCase {
    func testTogglePreservesOtherFavoritesAndUnknownIdentifiers() {
        let initial = ToolFavorites.encode(["csvEditor", "futureTool"])
        let added = ToolFavorites.toggling("systemMonitor", in: initial)
        XCTAssertEqual(ToolFavorites.decode(added), ["csvEditor", "futureTool", "systemMonitor"])
        XCTAssertEqual(ToolFavorites.decode(ToolFavorites.toggling("csvEditor", in: added)), ["futureTool", "systemMonitor"])
        XCTAssertEqual(ToolFavorites.decode("broken"), [])
        XCTAssertEqual(ToolFavorites.decode(ToolFavorites.toggling("csvEditor", in: "broken")), ["csvEditor"])
    }
    func testReorderInBothDirectionsAndPersistenceFormat() {
        let raw = #"["a","hidden","b","c","a"]"#
        let moved = ToolFavorites.moving("c", to: "a", in: raw)
        XCTAssertEqual(ToolFavorites.ordered(moved), ["c", "a", "hidden", "b"])
        XCTAssertEqual(ToolFavorites.ordered(ToolFavorites.moving("c", to: "b", in: moved)), ["a", "hidden", "b", "c"])
        XCTAssertEqual(ToolFavorites.moving("missing", to: "a", in: raw), raw)
        XCTAssertEqual(ToolFavorites.moving("a", to: "a", in: raw), raw)
        let added = ToolFavorites.toggling("new", in: moved)
        XCTAssertEqual(ToolFavorites.ordered(added), ["c", "a", "hidden", "b", "new"])
        XCTAssertEqual(ToolFavorites.ordered(ToolFavorites.toggling("a", in: added)), ["c", "hidden", "b", "new"])
    }
    func testPersistenceAndDeduplication() {
        let suite = "ToolFavoritesTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("untouched", forKey: "monitor.preferences.v1")
        defaults.set(ToolFavorites.encode(["csvEditor", "systemMonitor"]), forKey: ToolFavorites.storageKey)
        let reopened = UserDefaults(suiteName: suite)!
        XCTAssertEqual(ToolFavorites.decode(reopened.string(forKey: ToolFavorites.storageKey)!), ["csvEditor", "systemMonitor"])
        let reordered = ToolFavorites.moving("systemMonitor", to: "csvEditor", in: reopened.string(forKey: ToolFavorites.storageKey)!)
        reopened.set(reordered, forKey: ToolFavorites.storageKey)
        XCTAssertEqual(ToolFavorites.ordered(UserDefaults(suiteName: suite)!.string(forKey: ToolFavorites.storageKey)!), ["systemMonitor", "csvEditor"])
        XCTAssertEqual(reopened.string(forKey: "monitor.preferences.v1"), "untouched")
        XCTAssertEqual(ToolFavorites.decode(#"["csvEditor","csvEditor"]"#), ["csvEditor"])
    }
}
