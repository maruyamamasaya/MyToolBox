import SwiftUI

struct TimeCalculatorView: View {
    @State private var multiple: Bool
    @State private var start: String
    @State private var end: String
    @State private var rest: String
    @State private var ranges: String
    @State private var copied = false
    @State private var showsSettings = false
    init(multiple: Bool = false, start: String = "09:15", end: String = "18:30", rest: String = "01:00",
         ranges: String = "09:00 - 10:30\n11:15 - 12:00\n13:00 - 16:45") {
        _multiple = State(initialValue: multiple); _start = State(initialValue: start)
        _end = State(initialValue: end); _rest = State(initialValue: rest); _ranges = State(initialValue: ranges)
    }
    private var result: Result<(minutes: Int, gross: Int?), Error> {
        Result {
            if multiple { return (try TimeCalculation.total(ranges), nil) }
            let value = try TimeCalculation.work(start, end, rest: rest)
            return (value.net, value.gross)
        }
    }
    private func report(_ value: (minutes: Int, gross: Int?)) -> String {
        if let gross = value.gross {
            return "稼働時間：" + TimeCalculation.report(value.minutes) + "\n実時間：" + TimeCalculation.display(gross)
        }
        return "合計：" + TimeCalculation.report(value.minutes)
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("時間計算").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("時間計算の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("時刻はHH:mmで入力。終了が開始より早い場合は翌日、同時刻は0分。時間帯は各行を独立して合計し、重複分も含みます。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 260)
                    }
            }
            Picker("計算方法", selection: $multiple) {
                Text("勤務時間").tag(false); Text("時間帯の合計").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            if multiple {
                TextEditor(text: $ranges).font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80, maxHeight: .infinity).accessibilityLabel("時間帯")
                Text("1行ずつ 09:00 - 10:30（〜・～も可）")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    field("開始", value: $start); field("終了", value: $end); field("休憩", value: $rest)
                }
                Spacer(minLength: 0)
            }
            switch result {
            case .success(let value):
                VStack(alignment: .leading, spacing: 4) {
                    Text(multiple ? "合計" : "稼働時間").font(.caption).foregroundStyle(.secondary)
                    Text(TimeCalculation.display(value.minutes)).font(.system(size: 26, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text("\(String(format: "%.2f", Double(value.minutes) / 60))時間 · \(value.minutes)分")
                        .font(.caption).foregroundStyle(.secondary)
                    if let gross = value.gross {
                        Text("実時間 " + TimeCalculation.display(gross)).font(.caption).foregroundStyle(.secondary)
                    }
                }.textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 8) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(report(value), forType: .string); copied = true
                    } label: {
                        Label(copied ? "コピー済み" : "コピー", systemImage: "doc.on.doc").frame(minHeight: 28)
                    }
                    Spacer(minLength: 0)
                    resetButton
                }
            case .failure(let error):
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); resetButton }
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 280, idealWidth: 300, minHeight: multiple ? 360 : 320, idealHeight: multiple ? 360 : 320)
            .onChange(of: start) { _, _ in copied = false }.onChange(of: end) { _, _ in copied = false }
            .onChange(of: rest) { _, _ in copied = false }.onChange(of: ranges) { _, _ in copied = false }
            .onChange(of: multiple) { _, _ in copied = false }
    }
    private var resetButton: some View {
        Button {
            start = "09:15"; end = "18:30"; rest = "01:00"
            ranges = "09:00 - 10:30\n11:15 - 12:00\n13:00 - 16:45"; copied = false
        } label: { Text("リセット").frame(minHeight: 28) }
    }
    private func field(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("HH:mm", text: value).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }
}
