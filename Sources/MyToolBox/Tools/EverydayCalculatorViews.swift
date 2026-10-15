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
