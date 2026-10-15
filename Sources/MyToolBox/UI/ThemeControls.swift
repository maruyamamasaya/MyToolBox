import SwiftUI

/// Two physical pixels per side, with the five classic Windows bevel colors.
struct ClassicBevel: View {
    var sunken = false
    var body: some View {
        Canvas { context, size in
            let upper: [Color] = sunken ? [Color(hex: 0x808080), .black] : [.white, Color(hex: 0xdfdfdf)]
            let lower: [Color] = sunken ? [.white, Color(hex: 0xdfdfdf)] : [.black, Color(hex: 0x808080)]
            for i in 0..<2 {
                let d = CGFloat(i)
                var top = Path(); top.move(to: CGPoint(x: d, y: size.height - d)); top.addLine(to: CGPoint(x: d, y: d)); top.addLine(to: CGPoint(x: size.width - d, y: d))
                var bottom = Path(); bottom.move(to: CGPoint(x: d, y: size.height - d - 1)); bottom.addLine(to: CGPoint(x: size.width - d - 1, y: size.height - d - 1)); bottom.addLine(to: CGPoint(x: size.width - d - 1, y: d))
                context.stroke(top, with: .color(upper[i]), lineWidth: 1)
                context.stroke(bottom, with: .color(lower[i]), lineWidth: 1)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct ThemeButtonStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    var prominent = false
    var plain = false
    func makeBody(configuration: Configuration) -> some View {
        ThemeButtonBody(configuration: configuration, theme: theme, enabled: enabled, prominent: prominent, plain: plain)
    }
}
private struct ThemeButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let theme: AppTheme
    let enabled: Bool
    let prominent: Bool
    let plain: Bool
    @State private var hovering = false
    @Environment(\.isFocused) private var focused
    var body: some View {
        configuration.label
            .offset(x: theme.classic && configuration.isPressed ? 1 : 0, y: theme.classic && configuration.isPressed ? 1 : 0)
            .shadow(color: theme.classic && !enabled ? .white : .clear, radius: 0, x: 1, y: 1)
            .font(theme.classic ? theme.font(11) : nil)
            .padding(.horizontal, theme.classic ? 8 : plain ? 0 : 10)
            .padding(.vertical, theme.classic ? 4 : plain ? 0 : 5)
            .foregroundStyle(theme.classic ? (enabled ? Color.black : Color(hex: 0x808080)) : prominent ? Color.white : theme.text)
            .background {
                if theme.classic { theme.surface }
                else if !plain { RoundedRectangle(cornerRadius: 6).fill(prominent ? theme.accent.opacity(configuration.isPressed ? 0.6 : 0.85) : theme.edge.opacity(hovering ? 0.2 : 0.12)) }
            }
            .overlay { if theme.classic { ClassicBevel(sunken: configuration.isPressed) } }
            .overlay { if theme.classic && focused { Rectangle().inset(by: 4).stroke(.black, style: StrokeStyle(lineWidth: 1, dash: [1, 1])) } }
            .opacity(enabled || theme.classic ? 1 : 0.45)
            .contentShape(Rectangle()).onHover { hovering = $0 }
    }
}
struct ThemeToggleStyle: ToggleStyle {
    @Environment(\.appTheme) private var theme
    @Environment(\.isEnabled) private var enabled
    var asButton = false
    func makeBody(configuration: Configuration) -> some View {
        if theme.classic {
            Button { configuration.isOn.toggle() } label: {
                HStack(spacing: 6) {
                    ZStack {
                        Rectangle().fill(enabled ? Color.white : theme.surface).frame(width: 13, height: 13).overlay(ClassicBevel(sunken: true))
                        if configuration.isOn { Image(systemName: "checkmark").font(.system(size: 10, weight: .black)).foregroundStyle(enabled ? .black : .gray) }
                    }
                    configuration.label.font(theme.font(11)).foregroundStyle(enabled ? theme.text : Color.gray)
                }
            }.buttonStyle(.plain).accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.checkbox) }
        } else if asButton {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.button)
        } else {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.checkbox)
        }
    }
}
struct ThemeTextFieldStyle: TextFieldStyle {
    @Environment(\.appTheme) private var theme
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.textFieldStyle(.plain).padding(.horizontal, 6).padding(.vertical, 4)
            .foregroundStyle(theme.text).background(theme.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: theme.classic ? 0 : 5))
            .overlay { if theme.classic { ClassicBevel(sunken: true) } }
    }
}
struct ThemeProgressStyle: ProgressViewStyle {
    @Environment(\.appTheme) private var theme
    func makeBody(configuration: Configuration) -> some View {
        if theme.classic, let value = configuration.fractionCompleted {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<max(0, Int((geometry.size.width - 6) * min(1, max(0, value)) / 10)), id: \.self) { _ in Rectangle().fill(theme.accent).frame(width: 8) }
                    Spacer(minLength: 0)
                }.padding(3).background(Color.white).overlay(ClassicBevel(sunken: true))
            }.frame(height: 18).accessibilityValue("\(Int(value * 100))%")
        } else {
            ProgressView(configuration).progressViewStyle(.automatic)
        }
    }
}

/// Explicit options preserve selection semantics, without depending on opaque Picker tags.
struct ThemePicker<Value: Hashable>: View {
    @Environment(\.appTheme) private var theme
    let title: String
    @Binding var selection: Value
    let options: [(Value, String)]
    var tabs = false
    init(_ title: String, selection: Binding<Value>, options: [(Value, String)], tabs: Bool = false) {
        self.title = title; _selection = selection; self.options = options; self.tabs = tabs
    }
    var body: some View {
        if theme.classic {
            if tabs {
                HStack(spacing: 2) {
                    ForEach(options, id: \.0) { option in
                        Button { selection = option.0 } label: {
                            Text(option.1).font(theme.font(11, weight: selection == option.0 ? .bold : .regular)).frame(maxWidth: .infinity).padding(.horizontal, 9).padding(.vertical, 6)
                                .background(theme.surface).overlay(ClassicBevel(sunken: selection == option.0))
                        }.buttonStyle(.plain).accessibilityAddTraits(selection == option.0 ? .isSelected : [])
                    }
                }.accessibilityLabel(title)
            } else {
                HStack(spacing: 6) {
                    Text(title).font(theme.font(11))
                    ClassicPopup(title: title, selection: $selection, options: options).frame(height: 23)

                }
            }
        } else if tabs {
            Picker(title, selection: $selection) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }.pickerStyle(.segmented)
        } else {
            Picker(title, selection: $selection) { ForEach(options, id: \.0) { Text($0.1).tag($0.0) } }
        }
    }
}
private struct ThemeSurface: ViewModifier {
    @Environment(\.appTheme) private var theme
    var sunken = false
    func body(content: Content) -> some View {
        content.overlay { if theme.classic { ClassicBevel(sunken: sunken) } }
    }
}
extension View {
    func classicBevel(sunken: Bool = false) -> some View { modifier(ThemeSurface(sunken: sunken)) }
}
