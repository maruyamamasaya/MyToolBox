import SwiftUI

struct ColorPaletteView: View {
    @State private var input = "#4CAF50"
    @State private var first = "#833AB4"
    @State private var second = "#FD1D1D"
    @State private var degrees = 135
    @State private var status = ""
    @AppStorage("tools.colorPalette.notes.v1") private var notes = ""
    private var selected: PaletteColor? { PaletteColor(hex: input) }
    private var start: PaletteColor? { PaletteColor(hex: first) }
    private var end: PaletteColor? { PaletteColor(hex: second) }
    private var css: String? { guard let start, let end else { return nil }; return start.gradient(to: end, degrees: degrees) }
    @State private var expanded = false
    @State private var tab = 0
    init(initiallyExpanded: Bool = false, initialTab: Int = 0) {
        _expanded = State(initialValue: initiallyExpanded)
        _tab = State(initialValue: initialTab)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("カラーパレット", systemImage: "paintpalette").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("表示", selection: $tab) {
                Text("パレット").tag(0); Text("グラデーション").tag(1); Text("メモ").tag(2)
            }.pickerStyle(.segmented)
            if tab == 0 { palette }
            else if tab == 1 { gradient }
            else {
                TextEditor(text: $notes).font(.system(.body, design: .monospaced))
                    .accessibilityLabel("カラーコードのメモ")
                Text("このMacに自動保存").font(.caption).foregroundStyle(.secondary)
            }
            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel("コピー状態")
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 380, height: 560)))
            .frame(minWidth: expanded ? 800 : 360, idealWidth: expanded ? 1100 : 380,
                   minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 560)
    }
    private var palette: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                swatch(selected).frame(width: 54, height: 62)
                VStack(alignment: .leading, spacing: 6) {
                    TextField("HEX（3桁・6桁）", text: $input).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("HEXカラーコード")
                    if let selected {
                        HStack {
                            Button("HEX", systemImage: "doc.on.doc") { copy(selected.hex) }.help(selected.hex)
                            Button("RGB", systemImage: "doc.on.doc") { copy(selected.rgb) }.help(selected.rgb)
                        }
                        Text(selected.rgb).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    } else { Text("3桁・6桁のHEXを入力").font(.caption).foregroundStyle(.red) }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(PaletteColor.groups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.0).font(.caption).foregroundStyle(.secondary)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 11), spacing: 4) {
                                ForEach(group.1, id: \.self) { hex in
                                    Button { input = hex } label: {
                                        swatch(PaletteColor(hex: hex)).frame(height: expanded ? 42 : 26)
                                            .overlay(Rectangle().strokeBorder(selected?.hex == hex ? Color.primary : .clear, lineWidth: 3))
                                            .contentShape(Rectangle())
                                    }.buttonStyle(.plain).help(hex)
                                        .accessibilityLabel(group.0 + " " + hex + "を選択")
                                        .accessibilityValue(selected?.hex == hex ? "選択中" : "未選択")
                                }
                            }
                        }
                    }
                }.padding(2)
            }
            Text("120色 · クリックして選択").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var gradient: some View {
        ScrollView {
            VStack(spacing: 10) {
                GeometryReader { geometry in
                    let radians = Double(degrees) * .pi / 180
                    let length = abs(geometry.size.width * sin(radians)) + abs(geometry.size.height * cos(radians))
                    let dx = length * sin(radians) / (2 * max(1, geometry.size.width))
                    let dy = -length * cos(radians) / (2 * max(1, geometry.size.height))
                    Rectangle().fill(LinearGradient(colors: [color(start), color(end)],
                        startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy), endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
                        .opacity(css == nil ? 0 : 1)
                }.frame(height: expanded ? 240 : 100).accessibilityLabel("グラデーションのプレビュー")
                HStack { colorInput("カラー1", text: $first); colorInput("カラー2", text: $second) }
                HStack {
                    Picker("方向", selection: $degrees) {
                        Text("斜め ↘").tag(135); Text("上 ↑").tag(0); Text("左 ←").tag(270); Text("斜め ↗").tag(45)
                    }
                    Button("CSSコピー", systemImage: "doc.on.doc") { if let css { copy(css) } }.disabled(css == nil)
                }
                Text(css ?? "両方に有効なHEXを入力してください")
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: expanded ? 4 : 2), spacing: 8) {
                    ForEach(PaletteColor.recommendations, id: \.0) { item in
                        Button { first = item.1; second = item.2 } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Rectangle().fill(LinearGradient(colors: [color(PaletteColor(hex: item.1)), color(PaletteColor(hex: item.2))], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(height: expanded ? 55 : 28)
                                Text(item.0).font(.caption).lineLimit(1)
                            }.frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.accessibilityLabel(item.0 + "を適用")
                    }
                }
            }.padding(2)
        }
    }
    private func color(_ value: PaletteColor?) -> Color {
        guard let value else { return .clear }
        return Color(.sRGB, red: Double(value.red) / 255, green: Double(value.green) / 255, blue: Double(value.blue) / 255, opacity: 1)
    }
    private func swatch(_ value: PaletteColor?) -> some View {
        Rectangle().fill(color(value)).overlay(Rectangle().strokeBorder(.gray.opacity(0.4)))
    }
    private func colorInput(_ title: String, text: Binding<String>) -> some View {
        HStack {
            ColorPicker(title, selection: Binding(get: { color(PaletteColor(hex: text.wrappedValue)) }, set: { value in
                guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
                text.wrappedValue = String(format: "#%02X%02X%02X", Int((rgb.redComponent * 255).rounded()), Int((rgb.greenComponent * 255).rounded()), Int((rgb.blueComponent * 255).rounded()))
            }), supportsOpacity: false).labelsHidden().accessibilityLabel(title)
            TextField(title, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(title + " HEX")
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        status = NSPasteboard.general.setString(value, forType: .string) ? "コピーしました: " + value : "コピーできませんでした"
    }
}
