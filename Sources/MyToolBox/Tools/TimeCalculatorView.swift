import SwiftUI

struct TimeCalculatorView: View {
    @State private var multiple = false
    @State private var start = "09:15"
    @State private var end = "18:30"
    @State private var rest = "01:00"
    @State private var ranges = "09:00 - 10:30\n11:15 - 12:00\n13:00 - 16:45"
    @State private var copied = false
    private var result: Result<String, Error> {
        Result {
            if multiple { return "合計：" + TimeCalculation.report(try TimeCalculation.total(ranges)) }
            let value = try TimeCalculation.work(start, end, rest: rest)
            return "稼働時間：" + TimeCalculation.report(value.net) + "\n実時間：" + TimeCalculation.display(value.gross)
        }
    }
    var body: some View {
        ToolPage("時間計算", subtitle: "勤務時間・複数の時間帯をすばやく合計", symbol: "clock.badge.checkmark", tint: .cyan) {
            VStack(alignment: .leading, spacing: 20) {
                Picker("計算方法", selection: $multiple) { Text("勤務時間").tag(false); Text("複数行を合計").tag(true) }.pickerStyle(.segmented)
                ToolCard {
                    if multiple {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("1行に1つずつ時間帯を入力")
                            TextEditor(text: $ranges).font(.system(.body, design: .monospaced)).frame(minHeight: 160).accessibilityLabel("時間帯")
                            Text("例：09:00 - 10:30（〜・～も使用できます）").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 20) {
                            field("開始", value: $start); field("終了", value: $end); field("休憩", value: $rest)
                        }
                    }
                }
                switch result {
                case .success(let report):
                    ToolCard { Text(report).font(.title2).textSelection(.enabled).lineSpacing(12) }
                    Button(copied ? "コピーしました" : "結果をコピー", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(report, forType: .string); copied = true
                    }
                case .failure(let error):
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                Button("リセット") { start = "09:15"; end = "18:30"; rest = "01:00"; ranges = "09:00 - 10:30\n11:15 - 12:00\n13:00 - 16:45" }
                ToolFootnote(text: "終了が開始より早い場合は翌日として計算。同時刻は0分。時間帯は各行を独立して合計し、重複分も含みます。")
                Spacer(minLength: 0)
            }.padding(26)
        }.frame(minWidth: 660, idealWidth: 760, minHeight: 580)
            .onChange(of: start) { _, _ in copied = false }.onChange(of: end) { _, _ in copied = false }
            .onChange(of: rest) { _, _ in copied = false }.onChange(of: ranges) { _, _ in copied = false }
            .onChange(of: multiple) { _, _ in copied = false }
    }
    private func field(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading) { Text(title); TextField("HH:mm", text: value).textFieldStyle(.roundedBorder).accessibilityLabel(title) }
    }
}
