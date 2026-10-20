import XCTest
@testable import MonitorKit

final class ShortcutAuditTests: XCTestCase {
    func testScopesAndModifierNormalization() {
        let a = AuditedShortcut(owner: "A", action: "Open", keyCode: 40, modifiers: 256, global: false, source: "menu")
        let b = AuditedShortcut(owner: "B", action: "Open", keyCode: 40, modifiers: 256, global: false, source: "menu")
        let g = AuditedShortcut(owner: "macOS", action: "System", keyCode: 40, modifiers: 256 | 1, global: true, source: "setting")
        XCTAssertTrue(AuditedShortcut.candidates(in: [a, b]).isEmpty)
        XCTAssertEqual(AuditedShortcut.candidates(in: [a, b, g]), Set([a.id, b.id, g.id]))
        let other = AuditedShortcut(owner: "A", action: "Other", keyCode: 40, modifiers: 512, global: true, source: "setting")
        XCTAssertFalse(a.overlaps(other))
        let sameApp = AuditedShortcut(owner: "A", action: "Contextual", keyCode: 40, modifiers: 256, global: false, source: "menu")
        XCTAssertEqual(AuditedShortcut.candidates(in: [a, sameApp]).count, 2)
    }
}
