import SwiftUI

/// Semantic palettes derived from living-aurora-ui. Native UI shares one environment.
struct AppTheme {
    var id: VisualTheme = .blueCosmos
    var simple: Bool { id == .simpleDark }
    var classic: Bool { id == .windows98 }
    var background: Color { simple ? Color(nsColor: .windowBackgroundColor) : Color(hex: classic ? 0x008080 : id == .livingAurora ? 0x05070c : 0x020611) }
    var surface: Color { simple ? Color(nsColor: .controlBackgroundColor) : Color(hex: classic ? 0xc0c0c0 : id == .livingAurora ? 0x0d1220 : 0x070f22) }
    var surfaceHigh: Color { simple ? Color(nsColor: .textBackgroundColor) : Color(hex: classic ? 0xffffff : id == .livingAurora ? 0x12192a : 0x0a1630) }
    var text: Color { simple ? Color.primary : Color(hex: classic ? 0x000000 : id == .livingAurora ? 0xeef2ff : 0xedf5ff) }
    var muted: Color { simple ? Color.secondary : Color(hex: classic ? 0x333333 : id == .livingAurora ? 0x949db3 : 0x8497b7) }
    var accent: Color { simple ? Color.accentColor : Color(hex: classic ? 0x000080 : id == .livingAurora ? 0x8b6cff : 0x69a7ff) }
    var edge: Color { simple ? Color.gray : Color(hex: classic ? 0x808080 : id == .livingAurora ? 0xd1deff : 0x97c2ff) }
    var radius: CGFloat { classic ? 0 : simple ? 8 : id == .livingAurora ? 18 : 20 }
    var fontName: String { NSFont(name: "Microsoft Sans Serif", size: 11) != nil ? "Microsoft Sans Serif" : "Tahoma" }
    func font(_ size: CGFloat = 11, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        classic && design != .monospaced ? .custom(fontName, size: min(size, 14)).weight(weight) : .system(size: size, weight: weight, design: design)
    }
    var panel: LinearGradient {
        LinearGradient(colors: classic || simple ? [surface, surface] : [surfaceHigh.opacity(id == .livingAurora ? 0.8 : 0.94), surface.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
private struct ThemeKey: EnvironmentKey { static let defaultValue = AppTheme() }
extension EnvironmentValues {
    var appTheme: AppTheme { get { self[ThemeKey.self] } set { self[ThemeKey.self] = newValue } }
}
extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
}

/// The same AppStorage key invalidates all open roots without replacing their models.
struct ThemeRoot<Content: View>: View {
    @AppStorage(VisualTheme.storageKey) private var saved = VisualTheme.blueCosmos.rawValue
    var override: VisualTheme? = nil
    var windowTitle: String? = nil
    @ViewBuilder var content: Content
    private var theme: AppTheme { AppTheme(id: override ?? VisualTheme.resolve(saved)) }
    var body: some View {
        VStack(spacing: 0) {
            if theme.classic, let windowTitle { ClassicTitleBar(title: windowTitle) }
            content
        }
        .background { ThemeBackground() }
        .foregroundStyle(theme.text).font(theme.font(12))
        .tint(theme.accent).buttonStyle(ThemeButtonStyle())
        .toggleStyle(ThemeToggleStyle()).textFieldStyle(ThemeTextFieldStyle())
        .progressViewStyle(ThemeProgressStyle())
        .environment(\.appTheme, theme)
        .environment(\.colorScheme, theme.classic ? .light : .dark)
        .preferredColorScheme(theme.classic ? .light : .dark)
        .background { ThemeWindowBridge(theme: theme, customTitle: windowTitle != nil) }
    }
}
struct ThemeBackground: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        Group {
            switch theme.id {
            case .blueCosmos: CosmosBackground()
            case .livingAurora: AuroraBackground()
            case .simpleDark: theme.background
            case .windows98: theme.surface
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geometry in
                let span = max(geometry.size.width, geometry.size.height)
                ZStack {
                    Color(hex: 0x05070c)
                    ForEach(0..<5) { index in
                        let phase = time / [49.0, 61, 73, 57, 67][index] * .pi * 2 + Double(index)
                        let x = [0.05, 0.9, 0.5, 0.75, 0.25][index] + sin(phase) * 0.12
                        let y = [0.18, 0.65, 0.45, 0.08, 0.9][index] + cos(phase * 0.83) * 0.1
                        RadialGradient(colors: [Color(hex: [0x8b6cff, 0x55dde0, 0x215bb0, 0x8b6cff, 0xd563c8][index]).opacity(index < 2 ? 0.2 : 0.08), .clear], center: UnitPoint(x: x, y: y), startRadius: 0, endRadius: span * (index < 2 ? 0.65 : 0.4))
                    }
                    LinearGradient(stops: [.init(color: .clear, location: 0.25), .init(color: Color(hex: 0xb5dcff).opacity(0.025), location: 0.47), .init(color: .clear, location: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        }.clipped()
    }
}
struct CosmosBackground: View {
    private let theme = AppTheme(id: .blueCosmos)
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x01040d), Color(hex: 0x041027), theme.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [theme.accent.opacity(0.12), .clear], center: UnitPoint(x: 0.12, y: 0.3), startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.65)
                RadialGradient(colors: [Color(hex: 0x796eff).opacity(0.07), .clear], center: UnitPoint(x: 0.9, y: 0.1), startRadius: 0, endRadius: max(geometry.size.width, geometry.size.height) * 0.5)
                Canvas { context, size in
                    // Stable placement, sparse regions and mostly tiny distant stars.
                    var seed: UInt32 = 73
                    func random() -> Double {
                        seed = seed &* 1664525 &+ 1013904223
                        return Double(seed) / Double(UInt32.max)
                    }
                    for index in 0..<87 {
                        let cluster = random() < 0.48
                        let x = cluster ? 0.02 + random() * 0.34 : random()
                        let y = cluster ? 0.16 + random() * 0.29 : random()
                        let diameter = index < 4 ? 2.0 : 0.5 + random() * 0.8
                        let opacity = index < 4 ? 0.8 : 0.12 + random() * 0.35
                        let rect = CGRect(x: x * size.width, y: y * size.height, width: diameter, height: diameter)
                        context.fill(Path(ellipseIn: rect), with: .color(theme.text.opacity(opacity)))
                    }
                }
            }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}


struct ThemeMenu: View {
    @AppStorage(VisualTheme.storageKey) private var saved = VisualTheme.blueCosmos.rawValue
    var body: some View {
        Menu {
            ForEach(VisualTheme.allCases) { theme in
                Button { saved = theme.rawValue } label: {
                    if VisualTheme.resolve(saved) == theme { Label(theme.title, systemImage: "checkmark") }
                    else { Text(theme.title) }
                }
            }
        } label: { Label("テーマ", systemImage: "paintpalette") }.fixedSize().accessibilityLabel("テーマを切り替え")
    }
}
struct ThemeSettings: View {
    @Environment(\.appTheme) private var theme
    @AppStorage(VisualTheme.storageKey) private var saved = VisualTheme.blueCosmos.rawValue
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemePicker("外観", selection: Binding(get: { theme.id }, set: { saved = $0.rawValue }), options: VisualTheme.allCases.map { ($0, $0.title) })
            Text("開いているすべてのツールに反映し、次回起動時も維持します。").font(.caption)
        }
    }
}
