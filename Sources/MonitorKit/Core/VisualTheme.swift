import Foundation

public enum VisualTheme: String, CaseIterable, Identifiable {
    case blueCosmos = "blue-cosmos"
    case livingAurora = "living-aurora"
    case simpleDark = "simple-dark"
    case windows98 = "windows-98"
    public static let storageKey = "appearance.theme.v1"
    public var id: String { rawValue }
    public var title: String {
        switch self { case .blueCosmos: return "Blue Cosmos"; case .livingAurora: return "Living Aurora"; case .simpleDark: return "シンプルダーク"; case .windows98: return "Windows 98" }
    }
    public static func resolve(_ raw: String?) -> Self { Self(rawValue: raw ?? "") ?? .blueCosmos }
    public static func load(from defaults: UserDefaults = .standard) -> Self { resolve(defaults.string(forKey: storageKey)) }
    public func save(to defaults: UserDefaults = .standard) { defaults.set(rawValue, forKey: Self.storageKey) }
}
