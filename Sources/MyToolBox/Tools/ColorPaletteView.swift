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
    var body: some View {
        ToolPage("カラーパレット", subtitle: "色を見つけて、カラーコードをすぐにコピー。", symbol: "paintpalette", tint: .pink) {
            ScrollView {
                VStack(spacing: 18) {
                    ToolCard {
                        HStack(spacing: 20) {
                            swatch(selected).frame(width: 110, height: 100)
                            VStack(alignment: .leading, spacing: 12) {
                                ToolSectionLabel(title: "カラーコードを入力", symbol: "number")
                                TextField("#あり・なし、3桁または6桁", text: $input).textFieldStyle(.roundedBorder).accessibilityLabel("HEXカラーコード")
                                if let selected {
                                    HStack { Text(selected.hex).monospaced(); Button("HEXをコピー") { copy(selected.hex) }; Text(selected.rgb).monospaced(); Button("RGBをコピー") { copy(selected.rgb) } }
                                } else { Text("3桁または6桁のHEXカラーコードを入力してください").foregroundStyle(.red) }
                            }
                        }
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ToolSectionLabel(title: "グラデーションをつくる", symbol: "rectangle.fill")
                            GeometryReader { geometry in
                                let radians = Double(degrees) * .pi / 180
                                let length = abs(geometry.size.width * sin(radians)) + abs(geometry.size.height * cos(radians))
                                let dx = length * sin(radians) / (2 * max(1, geometry.size.width))
                                let dy = -length * cos(radians) / (2 * max(1, geometry.size.height))
                                Rectangle().fill(LinearGradient(colors: [color(start), color(end)], startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy), endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy)))
                                    .opacity(css == nil ? 0 : 1)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }.frame(height: 105).accessibilityLabel("グラデーションのプレビュー")
                            HStack {
                                colorInput("カラー1", text: $first)
                                colorInput("カラー2", text: $second)
                                Picker("方向", selection: $degrees) {
                                    Text("斜め ↘").tag(135); Text("下から上 ↑").tag(0); Text("右から左 ←").tag(270); Text("斜め ↗").tag(45)
                                }.frame(width: 190)
                            }
                            HStack {
                                Text(css ?? "両方の色に有効なHEXを入力してください").font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                Spacer()
                                Button("CSSをコピー") { if let css { copy(css) } }.disabled(css == nil)
                            }
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                                ForEach(PaletteColor.recommendations, id: \.0) { item in
                                    Button { first = item.1; second = item.2 } label: {
                                        VStack(alignment: .leading) {
                                            Rectangle().fill(LinearGradient(colors: [color(PaletteColor(hex: item.1)), color(PaletteColor(hex: item.2))], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(height: 30)
                                            Text(item.0).font(.caption)
                                        }
                                    }.buttonStyle(.plain).accessibilityLabel(item.0 + "を適用")
                                }
                            }
                        }
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ToolSectionLabel(title: "カラーコードをストック", symbol: "note.text")
                            TextEditor(text: $notes).font(.system(.body, design: .monospaced)).frame(height: 90).accessibilityLabel("カラーコードのメモ")
                            Text("このMacに自動保存").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ToolSectionLabel(title: "120色 · クリックして選択", symbol: "paintpalette")
                            ForEach(PaletteColor.groups, id: \.0) { group in
                                HStack {
                                    Text(group.0).font(.caption).frame(width: 85, alignment: .leading)
                                    ForEach(group.1, id: \.self) { hex in
                                        Button { input = hex } label: {
                                            swatch(PaletteColor(hex: hex)).frame(height: 32)
                                                .overlay(Rectangle().strokeBorder(selected?.hex == hex ? Color.primary : .clear, lineWidth: 3))
                                        }.buttonStyle(.plain).help(hex).accessibilityLabel(group.0 + " " + hex + "を選択").accessibilityValue(selected?.hex == hex ? "選択中" : "未選択")
                                    }
                                }
                            }
                        }
                    }
                    Text(status).font(.caption).foregroundStyle(.secondary).accessibilityLabel("コピー状態")
                }.padding(24)
            }
        }.frame(minWidth: 940, minHeight: 760)
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
