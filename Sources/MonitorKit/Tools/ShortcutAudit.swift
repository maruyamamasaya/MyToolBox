import Foundation

public struct AuditedShortcut: Identifiable, Sendable {
    public let id: UUID
    public let owner: String
    public let action: String
    public let keyCode: Int
    /// Carbon modifier masks, normalized from each source.
    public let modifiers: Int
    public let global: Bool
    public let source: String
    public init(owner: String, action: String, keyCode: Int, modifiers: Int, global: Bool, source: String) {
        id = UUID(); self.owner = owner; self.action = action; self.keyCode = keyCode
        self.modifiers = modifiers & 0x1F00; self.global = global; self.source = source
    }
    public var signature: String { "\(keyCode):\(modifiers)" }
    public func overlaps(_ other: Self) -> Bool {
        signature == other.signature && (global || other.global || owner == other.owner)
    }
    public static func candidates(in rows: [Self]) -> Set<UUID> {
        var result = Set<UUID>()
        for group in Dictionary(grouping: rows, by: \.signature).values where group.count > 1 {
            for row in group where group.contains(where: { $0.id != row.id && row.overlaps($0) }) { result.insert(row.id) }
        }
        return result
    }
}
