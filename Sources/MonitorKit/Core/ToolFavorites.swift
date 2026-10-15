import Foundation

/// Stable tool identifiers only; independent of catalog order and display names.
public enum ToolFavorites {
    public static let storageKey = "tools.favorites.v1"
    public static func decode(_ raw: String) -> Set<String> {
        Set(ordered(raw))
    }
    public static func encode(_ values: Set<String>) -> String {
        guard let data = try? JSONEncoder().encode(values.sorted()), let raw = String(data: data, encoding: .utf8) else { return "[]" }
        return raw
    }
    public static func ordered(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
    private static func encodeOrdered(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values), let raw = String(data: data, encoding: .utf8) else { return "[]" }
        return raw
    }
    /// Move to the destination's slot; hidden/unknown IDs retain their relative order.
    public static func moving(_ identifier: String, to target: String, in raw: String) -> String {
        var values = ordered(raw)
        guard identifier != target, let source = values.firstIndex(of: identifier), let destination = values.firstIndex(of: target) else { return raw }
        values.remove(at: source)
        values.insert(identifier, at: destination)
        return encodeOrdered(values)
    }
    public static func toggling(_ identifier: String, in raw: String) -> String {
        var values = ordered(raw)
        if values.contains(identifier) { values.removeAll { $0 == identifier } }
        else { values.append(identifier) }
        return encodeOrdered(values)
    }
}
