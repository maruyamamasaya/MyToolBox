import Foundation

/// Opaque sRGB colors. Accepts the reference tool's three- or six-digit HEX notation.
public struct PaletteColor: Equatable, Sendable {
    public let red: Int
    public let green: Int
    public let blue: Int
    public init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard [3, 6].contains(value.count), value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard let number = Int(value, radix: 16) else { return nil }
        red = number >> 16; green = (number >> 8) & 255; blue = number & 255
    }
    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
    public var rgb: String { "rgb(\(red), \(green), \(blue))" }
    public func gradient(to other: Self, degrees: Int) -> String {
        "linear-gradient(\(degrees)deg, \(hex), \(other.hex))"
    }
    public static let groups: [(String, [String])] = [
        ("赤", "FFEBEE FFCDD2 EF9A9A E57373 EF5350 F44336 E53935 D32F2F C62828 B71C1C FF1744"),
        ("オレンジ", "FFF3E0 FFE0B2 FFCC80 FFB74D FFA726 FF9800 FB8C00 F57C00 EF6C00 E65100 FF6D00"),
        ("黄色", "FFFDE7 FFF9C4 FFF59D FFF176 FFEE58 FFEB3B FDD835 FBC02D F9A825 F57F17 FFD600"),
        ("緑", "E8F5E9 C8E6C9 A5D6A7 81C784 66BB6A 4CAF50 43A047 388E3C 2E7D32 1B5E20 00C853"),
        ("水色", "E0F7FA B2EBF2 80DEEA 4DD0E1 26C6DA 00BCD4 00ACC1 0097A7 00838F 006064 00E5FF"),
        ("青", "E3F2FD BBDEFB 90CAF9 64B5F6 42A5F5 2196F3 1E88E5 1976D2 1565C0 0D47A1 2979FF"),
        ("紫", "F3E5F5 E1BEE7 CE93D8 BA68C8 AB47BC 9C27B0 8E24AA 7B1FA2 6A1B9A 4A148C AA00FF"),
        ("ピンク", "FCE4EC F8BBD0 F48FB1 F06292 EC407A E91E63 D81B60 C2185B AD1457 880E4F F50057"),
        ("茶色", "EFEBE9 D7CCC8 BCAAA4 A1887F 8D6E63 795548 6D4C41 5D4037 4E342E 3E2723 A0522D"),
        ("グレー", "FAFAFA F5F5F5 EEEEEE E0E0E0 BDBDBD 9E9E9E 757575 616161 424242 303030 212121"),
        ("白・黒・定番", "FFFFFF F8F9FA ECEFF1 CFD8DC 90A4AE 607D8B 455A64 263238 000000 FF5733")
    ].map { ($0.0, $0.1.split(separator: " ").map { "#" + $0 }) }
    public static let recommendations: [(String, String, String)] = [
        ("Social Sunset", "#833AB4", "#FD1D1D"), ("Peach Glow", "#FF9966", "#FF5E62"),
        ("Digital Lavender", "#7F7FD5", "#91EAE4"), ("Neo Matcha", "#DCE35B", "#45B649"),
        ("Dreamy Blue", "#A1C4FD", "#C2E9FB"), ("Berry Pop", "#FC466B", "#3F5EFB"),
        ("Soft Sorbet", "#FBC2EB", "#A6C1EE"), ("Midnight Reel", "#232526", "#6A3093")
    ]
}
