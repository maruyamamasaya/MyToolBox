import SwiftUI

/// Shared output presentation for the local calculator and server utilities.
struct UtilityResult: View {
    let result: Result<[(String, String)], Error>
    @State private var copied = false
    var body: some View {
        switch result {
        case .failure(let error): Label(error.localizedDescription, systemImage: "exclamationmark.circle").foregroundStyle(.red).textSelection(.enabled)
        case .success(let rows):
            ToolCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(rows.indices, id: \.self) { i in
                        HStack(alignment: .top) {
                            Text(rows[i].0).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
                            Text(rows[i].1).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            Button("コピー") { copy(rows[i].1) }
                        }
                    }
                    HStack { Text(copied ? "コピーしました" : "").font(.caption); Spacer(); Button("すべてコピー") { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) }.disabled(rows.isEmpty) }
                }
            }
        }
    }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); copied = true }
}
struct UtilityField: View {
    let title: String
    @Binding var text: String
    var body: some View { HStack { Text(title).frame(width: 150, alignment: .leading); TextField(title, text: $text).textFieldStyle(.roundedBorder) } }
}
struct EverydayCalculatorView: View {
    let tool: ToolID
    @State private var mode = EverydayCalculators.PercentageMode.change
    @State private var percentageInputs: [EverydayCalculators.PercentageMode: [String]] = [.change: ["1000", "1250"]]
    private var a: Binding<String> { percentageField(0) }
    private var b: Binding<String> { percentageField(1) }
    private func percentageField(_ index: Int) -> Binding<String> {
        Binding(get: { percentageInputs[mode]?[index] ?? "" }, set: { value in
            var fields = percentageInputs[mode] ?? ["", ""]
            fields[index] = value; percentageInputs[mode] = fields
        })
    }
    @State private var expression = "1000 + 250 × 2"
    @State private var history: [String] = []
    @State private var numbers = "11\n19\n38\n42\n46"
    @State private var summary: Result<EverydayCalculators.Summary, Error>?
    @State private var group = 0
    @State private var value = "100"
    @State private var from = "mm"
    @State private var to = "cm"
    @State private var rate = ""
    @State private var binary = true
    @State private var digits = 2
    private typealias C = EverydayCalculators
    private var result: Result<[(String, String)], Error> {
        Result {
            switch tool {
            case .percentageCalculator: return try C.percentage(mode, a: C.percentageNumber(a.wrappedValue), b: C.percentageNumber(b.wrappedValue)).map { ($0.0, C.display($0.1)) }
            case .simpleCalculator: return [("結果", C.display(try C.expression(expression)))]
            case .unitConverter:
                let r = group == 9 && from != to ? try C.number(rate) : nil
                let answer = try C.convert(C.number(value), group: group, from: from, to: to, binary: binary, rate: r)
                return [("変換結果", C.display(answer, digits: digits) + " " + to), ("換算式", value + " " + from + " = " + C.display(answer, digits: digits) + " " + to)]
            default: return []
            }
        }
    }
    var body: some View {
        Group {
            if tool == .percentageCalculator {
                CompactPercentageCalculatorView()
            } else if tool == .simpleCalculator {
                CompactSimpleCalculatorView()
            } else if tool == .unitConverter {
                CompactUnitConverterView()
            } else if tool == .numberCalculator {
                CompactNumberSummaryView()
            } else {
        ToolPage(tool.title, subtitle: tool.subtitle, symbol: tool.symbol, tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 16) { controls } }
                if tool == .numberCalculator {
                    if let summary {
                        UtilityResult(result: summary.map { $0.rows.map { ($0.0, C.display($0.1)) } })
                        if case .success(let value) = summary, !value.ignored.isEmpty { Text("除外した入力 \(value.ignored.count)件: " + value.ignored.prefix(20).joined(separator: ", ")).foregroundStyle(.orange).textSelection(.enabled) }
                    }
                } else { UtilityResult(result: result) }
                if tool == .simpleCalculator && !history.isEmpty {
                    ToolCard { VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("履歴（画面を閉じるまで保持）"); Spacer(); Button("履歴を削除") { history = [] } }
                        ForEach(history.indices, id: \.self) { i in
                            HStack { Text(history[i]).textSelection(.enabled); Spacer(); Button("コピー") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(history[i], forType: .string) } }
                        }
                    } }
                }
                ToolFootnote(text: footnote)
            }.padding(24) }
        }.frame(minWidth: 800, minHeight: 700)
            }
        }
    }
    @ViewBuilder private var controls: some View {
        switch tool {
        case .percentageCalculator:
            ThemePicker("計算方法", selection: $mode, options: C.PercentageMode.allCases.map { ($0, $0.rawValue) }, tabs: true)
            UtilityField(title: mode == .reverse ? "増減率（%）" : mode == .ratio ? "全体" : mode == .percent ? "元の値" : "変更前", text: a)
            UtilityField(title: mode == .reverse ? "結果" : mode == .ratio ? "一部" : mode == .percent ? "割合（%）" : "変更後", text: b)
            Button("クリア") { percentageInputs[mode] = ["", ""] }
        case .simpleCalculator:
            UtilityField(title: "計算式", text: $expression).onSubmit { remember() }
            HStack { Button("計算・履歴に追加") { remember() }; Button("クリア") { expression = "" } }
        case .numberCalculator:
            Text("改行・カンマ・空白・タブで数値を区切って入力")
            TextEditor(text: $numbers).font(.system(.body, design: .monospaced)).frame(height: 220).onChange(of: numbers) { _, _ in summary = nil }
            HStack { Button("集計する") { summary = Result { try C.summarize(numbers) } }; Button("クリア") { numbers = ""; summary = nil } }
        case .unitConverter:
            ThemePicker("カテゴリ", selection: $group, options: C.unitGroups.indices.map { ($0, C.unitGroups[$0].name) })
                .onChange(of: group) { _, new in
                    let units = C.unitGroups[new].units; from = units[0].0; to = units[1].0; rate = ""
                }
            UtilityField(title: "数値", text: $value)
            ThemePicker("変換元", selection: $from, options: C.unitGroups[group].units.map { ($0.0, $0.0) })
            ThemePicker("変換先", selection: $to, options: C.unitGroups[group].units.map { ($0.0, $0.0) })
            if group == 5 { Toggle("1024倍で換算（オフは1000倍）", isOn: $binary) }
            if group == 9 { UtilityField(title: "1 \(from) = \(to)", text: $rate); Text("レートを手入力してください。単位変更時はレートを確認してください。").font(.caption) }
            Stepper("表示小数桁: \(digits)", value: $digits, in: 0...10)
            HStack {
                Button("単位を入れ替え") {
                    let old = from; from = to; to = old
                    if group == 9, let r = try? C.number(rate), r > 0 { rate = String(1 / r) }
                }
                Button("クリア") { value = "" }
            }
        default: EmptyView()
        }
    }
    private func remember() {
        if let answer = try? C.expression(expression) { history.insert(expression + " = " + C.display(answer), at: 0) }
    }
    private var footnote: String {
        switch tool {
        case .unitConverter: return "通貨レートは手入力。畳は1.62m²、gallonは米液量。小数は近似値で、表示桁で丸めます。極小値は指数表記。入力は端末内だけで処理します。"
        case .numberCalculator: return "カンマは数値の区切りです。1,000は1と0の2件として扱うため、千区切りなしで入力してください。数値でない入力は除外件数と内容を表示。最大20,000件・500KB。"
        case .simpleCalculator: return "+ − × ✕ ÷、括弧、単項符号、指数表記に対応。掛け算・割り算を優先します。最大1,000文字。小数は近似値です。"
        default: return "全角数字・円・¥・%・空白付き入力に対応。各モードの入力は個別に保持。増減率は変更前を分母として計算します。負の数にも対応。分母0・逆算−100%は計算できません。小数は近似値です。"
        }
    }
}


struct CompactPercentageCalculatorView: View {
    @State private var mode: EverydayCalculators.PercentageMode
    @State private var inputs: [EverydayCalculators.PercentageMode: [String]]
    @State private var copied = false
    @State private var showsSettings = false
    init(mode: EverydayCalculators.PercentageMode = .change, first: String = "1000", second: String = "1250") {
        _mode = State(initialValue: mode); _inputs = State(initialValue: [mode: [first, second]])
    }
    private func field(_ index: Int) -> Binding<String> {
        Binding(get: { inputs[mode]?[index] ?? "" }, set: { value in
            var values = inputs[mode] ?? ["", ""]
            values[index] = value; inputs[mode] = values
        })
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            try EverydayCalculators.percentage(mode, a: EverydayCalculators.percentageNumber(field(0).wrappedValue),
                b: EverydayCalculators.percentageNumber(field(1).wrappedValue)).map { ($0.0, EverydayCalculators.display($0.1)) }
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("割合計算").font(.headline)
                Spacer()
                Button { inputs[mode] = ["", ""]; copied = false } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア")
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("割合計算の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("全角数字・円・¥・%・空白付き入力に対応。モードごとの入力を保持します。増減率は変更前を分母に計算。負数にも対応。分母0・逆算−100%は計算できません。小数は近似値です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            Picker("計算方法", selection: $mode) {
                ForEach(EverydayCalculators.PercentageMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            inputRow(mode == .reverse ? "増減率（%）" : mode == .ratio ? "全体" : mode == .percent ? "元の値" : "変更前", value: field(0))
            inputRow(mode == .reverse ? "結果" : mode == .ratio ? "一部" : mode == .percent ? "割合（%）" : "変更後", value: field(1))
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(rows[index].0).font(.caption).foregroundStyle(.secondary)
                                    Text(rows[index].1).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 360)
            .onChange(of: mode) { _, _ in copied = false }
            .onChange(of: inputs) { _, _ in copied = false }
    }
    private func inputRow(_ title: String, value: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 72, alignment: .leading)
            TextField(title, text: value).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(value, forType: .string)
    }
}


struct CompactSimpleCalculatorView: View {
    @State private var expression: String
    @State private var history: [String]
    @State private var copied = false
    @State private var showsHistory = false
    @State private var showsSettings = false
    init(expression: String = "1000 + 250 × 2", history: [String] = []) {
        _expression = State(initialValue: expression); _history = State(initialValue: history)
    }
    private var result: Result<String, Error> {
        Result { EverydayCalculators.display(try EverydayCalculators.expression(expression)) }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("電卓").font(.headline)
                Spacer()
                Button { showsHistory = true } label: {
                    Image(systemName: "clock.arrow.circlepath").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("計算履歴")
                    .popover(isPresented: $showsHistory) { historyPanel }
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("電卓の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Button("結果ラベル付きでコピー") {
                                if case .success(let value) = result { copy("結果: " + value) }
                            }.disabled((try? result.get()) == nil)
                            Text("+ − × ✕ ÷、括弧、単項符号、指数表記に対応。最大1,000文字。小数は近似値です。Enterまたは計算で履歴へ追加。履歴は画面を閉じるまで保持します。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            TextField("計算式", text: $expression).textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced)).accessibilityLabel("計算式")
                .onSubmit { remember() }
            Spacer(minLength: 0)
            switch result {
            case .success(let value):
                Text(value).font(.system(size: 32, weight: .semibold, design: .rounded))
                    .textSelection(.enabled).lineLimit(1).minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing).help(value)
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Button { expression = ""; copied = false } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("計算式をクリア")
                Spacer(minLength: 0)
                Button { remember() } label: { Text("計算").frame(minWidth: 36, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled((try? result.get()) == nil)
                Button { if case .success(let value) = result { copy(value) } } label: {
                    Text(copied ? "コピー済み" : "コピー").frame(minHeight: 28)
                }.disabled((try? result.get()) == nil)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 280, idealWidth: 300, minHeight: 220, idealHeight: 240)
            .onChange(of: expression) { _, _ in copied = false }
    }
    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("計算履歴").font(.headline)
                Spacer()
                Button("消去") { history = [] }.disabled(history.isEmpty)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if history.isEmpty { Text("計算すると履歴に追加します").font(.caption).foregroundStyle(.secondary) }
                    ForEach(history.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text(history[index]).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                            Button { copy(history[index]) } label: {
                                Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                            }.accessibilityLabel("履歴をコピー")
                        }
                    }
                }
            }
        }.padding(12).frame(width: 300, height: 280)
    }
    private func remember() {
        if case .success(let value) = result { history.insert(expression + " = " + value, at: 0) }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(text, forType: .string)
    }
}


struct CompactUnitConverterView: View {
    @State private var group: Int
    @State private var value: String
    @State private var from: String
    @State private var to: String
    @State private var rate: String
    @State private var binary = true
    @State private var digits = 2
    @State private var copied = false
    @State private var showsSettings = false
    init(group: Int = 0, value: String = "100", rate: String = "") {
        _group = State(initialValue: group); _value = State(initialValue: value); _rate = State(initialValue: rate)
        let units = EverydayCalculators.unitGroups[group].units
        _from = State(initialValue: units[0].0); _to = State(initialValue: units[1].0)
    }
    private var results: Result<[(String, String)], Error> {
        Result {
            let r = group == 9 && from != to ? try EverydayCalculators.number(rate) : nil
            let answer = try EverydayCalculators.convert(EverydayCalculators.number(value), group: group,
                from: from, to: to, binary: binary, rate: r)
            let formatted = EverydayCalculators.display(answer, digits: digits) + " " + to
            return [("変換結果", formatted), ("換算式", value + " " + from + " = " + formatted)]
        }
    }
    private var inputKey: [String] { [String(group), value, from, to, rate, String(binary), String(digits)] }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("単位変換").font(.headline)
                Spacer(minLength: 0)
                Picker("カテゴリ", selection: $group) {
                    ForEach(EverydayCalculators.unitGroups.indices, id: \.self) {
                        Text(EverydayCalculators.unitGroups[$0].name).tag($0)
                    }
                }.labelsHidden().frame(width: 110)
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("単位変換の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Stepper("小数桁 \(digits)", value: $digits, in: 0...10)
                            ThemeMenu()
                            Text("通貨レートは手入力。単位変更時はレートを確認してください。畳は1.62m²、gallonは米液量。小数は近似値で、極小値は指数表記です。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            HStack(spacing: 8) {
                unitPicker("変換元", value: $from)
                Button {
                    let old = from; from = to; to = old
                    if group == 9, let r = try? EverydayCalculators.number(rate), r > 0 { rate = String(1 / r) }
                } label: {
                    Image(systemName: "arrow.left.arrow.right").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("単位を入れ替え")
                unitPicker("変換先", value: $to)
            }
            HStack(spacing: 8) {
                TextField("数値", text: $value).textFieldStyle(.roundedBorder).accessibilityLabel("変換する数値")
                Button { value = "" } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("数値をクリア")
            }
            if group == 5 { Toggle("1024倍（オフは1000倍）", isOn: $binary).font(.caption) }
            if group == 9 {
                HStack(spacing: 6) {
                    Text("1 " + from + " =").font(.caption)
                    TextField("手入力レート", text: $rate).textFieldStyle(.roundedBorder).accessibilityLabel("1 " + from + "あたりの" + to + "のレート")
                    Text(to).font(.caption)
                }
            }
            switch results {
            case .success(let rows):
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(rows.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 8) {
                                Text(rows[index].1).font(index == 0 ? .system(size: 24, weight: .semibold, design: .rounded) : .caption)
                                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button { copy(rows[index].1) } label: {
                                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                }.accessibilityLabel(rows[index].0 + "をコピー")
                            }
                        }
                    }
                }
                HStack {
                    Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) } label: {
                        Text("すべてコピー").frame(minHeight: 28)
                    }
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 320, idealHeight: 340)
            .onChange(of: group) { _, next in
                let units = EverydayCalculators.unitGroups[next].units
                from = units[0].0; to = units[1].0; rate = ""
            }
            .onChange(of: inputKey) { _, _ in copied = false }
    }
    private func unitPicker(_ title: String, value: Binding<String>) -> some View {
        Picker(title, selection: value) {
            ForEach(EverydayCalculators.unitGroups[group].units, id: \.0) { Text($0.0).tag($0.0) }
        }.labelsHidden().frame(maxWidth: .infinity)
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(text, forType: .string)
    }
}


struct CompactNumberSummaryView: View {
    @State private var numbers: String
    @State private var summary: Result<EverydayCalculators.Summary, Error>?
    @State private var copied = false
    @State private var showsSettings = false
    init(numbers: String = "11\n19\n38\n42\n46", summary: Result<EverydayCalculators.Summary, Error>? = nil) {
        _numbers = State(initialValue: numbers); _summary = State(initialValue: summary)
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("数値集計").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("数値集計の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("改行・カンマ・空白・タブで区切ります。カンマは数値の区切りです。1,000は1と0の2件として扱うため、千区切りなしで入力してください。最大20,000件・500KB。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            TextEditor(text: $numbers).font(.system(.body, design: .monospaced))
                .frame(height: 70).accessibilityLabel("集計する数値")
            HStack(spacing: 8) {
                Button { numbers = ""; summary = nil; copied = false } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア")
                Spacer()
                Button { summary = Result { try EverydayCalculators.summarize(numbers) }; copied = false } label: {
                    Text("集計").frame(minWidth: 36, minHeight: 28)
                }.buttonStyle(.borderedProminent)
            }
            if let summary {
                switch summary {
                case .success(let value):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            if !value.ignored.isEmpty {
                                Text("除外した入力 \(value.ignored.count)件: " + value.ignored.prefix(20).joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(value.rows.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(value.rows[index].0).font(.caption).foregroundStyle(.secondary)
                                        .frame(width: 32, alignment: .leading)
                                    Text(EverydayCalculators.display(value.rows[index].1))
                                        .font(index < 2 ? .system(size: 20, weight: .semibold, design: .rounded) : .system(.body, design: .monospaced))
                                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button { copy(EverydayCalculators.display(value.rows[index].1)) } label: {
                                        Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                                    }.accessibilityLabel(value.rows[index].0 + "をコピー")
                                }
                            }
                        }
                    }
                    HStack {
                        Text(copied ? "コピーしました" : "").font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button { copy(value.rows.map { $0.0 + ": " + EverydayCalculators.display($0.1) }.joined(separator: "\n")) } label: {
                            Text("すべてコピー").frame(minHeight: 28)
                        }
                    }
                case .failure(let error):
                    Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            } else {
                Text("数値を入力して「集計」を押してください")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 300, idealWidth: 320, minHeight: 340, idealHeight: 380)
            .onChange(of: numbers) { _, _ in summary = nil; copied = false }
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(text, forType: .string)
    }
}
