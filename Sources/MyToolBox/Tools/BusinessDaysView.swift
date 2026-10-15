import SwiftUI
struct BusinessDaysView: View {
    var holidayURL: URL? = Bundle.main.url(forResource: "JapaneseHolidays", withExtension: "json")
    @State private var start = Date()
    @State private var end = Date()
    @State private var customDate = Date()
    @State private var customName = ""
    @State private var custom: [String: String] = [:]
    @State private var format = 0
    @State private var status = ""
    private let calendar = BusinessDays.calendar
    private var source: Result<BusinessDays, Error> {
        Result { guard let url = holidayURL else { throw ToolFailure.message("祝日データが見つかりません") }; return try BusinessDays(data: Data(contentsOf: url)) }
    }
    private var result: Result<BusinessDays.Result, Error> { source.flatMap { model in Result { try model.calculate(start: start, end: end, custom: Set(custom.keys)) } } }
    private var output: String {
        guard let counts = try? result.get() else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.timeZone = calendar.timeZone
        f.dateFormat = format == 2 ? "yyyy/M/d（E）" : "yyyy/M/d"
        let a = f.string(from: start), b = f.string(from: end)
        switch format {
        case 0: return a + "\n〜\n" + b
        case 3: return a + " - " + b
        case 4: return a + "〜" + b + "（\(counts.total)日間）"
        default: return a + "〜" + b
        }
    }
    var body: some View {
        ToolPage("営業日計算", subtitle: "日付を選んで、働く日をひと目で。", symbol: "calendar", tint: .mint) {
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 14) {
                        dateCard("開始日", selection: $start, symbol: "calendar.badge.plus")
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        dateCard("終了日", selection: $end, symbol: "calendar.badge.checkmark")
                    }
                    HStack(spacing: 8) {
                        Text("クイック選択").font(.caption).foregroundStyle(.secondary)
                        Button("今日から1週間") { range(7) }
                        Button("今日から30日") { range(30) }
                        Button("今月") { start = calendar.dateInterval(of: .month, for: Date())!.start; end = calendar.date(byAdding: .day, value: -1, to: calendar.dateInterval(of: .month, for: Date())!.end)! }
                        Spacer()
                    }.controlSize(.small)
                    switch result {
                    case .success(let r):
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("営業日").font(.system(size: 13, weight: .semibold)).foregroundStyle(.mint)
                                HStack(alignment: .firstTextBaseline, spacing: 6) { Text("\(r.business)").font(.system(size: 58, weight: .semibold, design: .rounded)).monospacedDigit(); Text("日").font(.title3).foregroundStyle(.secondary) }
                            }.frame(minWidth: 140, alignment: .leading)
                            Divider().frame(height: 66)
                            count("期間", r.total, symbol: "calendar")
                            count("土日", r.weekends, symbol: "sun.max")
                            count("平日の祝日・休日", r.holidays, symbol: "flag")
                            Spacer(minLength: 0)
                        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.mint.opacity(0.18)))
                    case .failure(let e):
                        Label(e.localizedDescription, systemImage: "exclamationmark.circle").foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { ToolSectionLabel(title: "期間をコピー", symbol: "doc.on.doc"); Spacer(); Picker("形式", selection: $format) { ForEach(Array(["改行＋〜", "1行", "曜日つき", "ハイフン", "日数つき"].enumerated()), id: \.offset) { Text($0.element).tag($0.offset) } }.labelsHidden().frame(width: 140) }
                            HStack { Text(output.isEmpty ? "有効な期間を選択してください" : output).font(.system(size: 14, design: .monospaced)).textSelection(.enabled); Spacer(); Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); status = "コピーしました" } label: { Label(status.isEmpty ? "コピー" : status, systemImage: "doc.on.doc") }.buttonStyle(.borderedProminent).disabled((try? result.get()) == nil) }
                        }
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 12) {
                            ToolSectionLabel(title: "独自の休日", symbol: "calendar.badge.exclamationmark")
                            HStack { DatePicker("日付", selection: $customDate, displayedComponents: .date).labelsHidden(); TextField("会社の休業日など", text: $customName).textFieldStyle(.roundedBorder); Button { custom[BusinessDays.key(customDate)] = customName; customName = "" } label: { Label("追加", systemImage: "plus") }.disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty) }
                            ForEach(custom.keys.sorted(), id: \.self) { day in HStack { Text(day).monospacedDigit().foregroundStyle(.secondary); Text(custom[day]!); Spacer(); Button { custom[day] = nil } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("\(day)の休日を削除") } }
                            Text("追加した休日は、このウィンドウを閉じるまで有効です。").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    ToolFootnote(text: "開始日・終了日を含みます。土日と重なる祝日は二重に数えません。内閣府の公表済み祝日（1955〜2027年・2026-10-15取得）を同梱。")
                }.padding(24)
            }
        }.environment(\.calendar, calendar).environment(\.timeZone, calendar.timeZone).frame(minWidth: 740, minHeight: 740)
        .onChange(of: start) { _, _ in status = "" }.onChange(of: end) { _, _ in status = "" }.onChange(of: format) { _, _ in status = "" }
    }
    private func dateCard(_ title: String, selection: Binding<Date>, symbol: String) -> some View {
        ToolCard {
            VStack(alignment: .leading, spacing: 14) {
                ToolSectionLabel(title: title, symbol: symbol)
                DatePicker(title, selection: selection, displayedComponents: .date).datePickerStyle(.field).labelsHidden().font(.title2)
                ToolCalendar(selection: selection, holidays: ((try? source.get().holidays) ?? [:]).merging(custom) { _, new in new })
            }
        }
    }
    private func range(_ count: Int) { start = Date(); end = calendar.date(byAdding: .day, value: count - 1, to: start)! }
    private func count(_ label: String, _ value: Int, symbol: String) -> some View { VStack(alignment: .leading, spacing: 10) { Label(label, systemImage: symbol).font(.caption).foregroundStyle(.secondary); Text("\(value)").font(.system(size: 27, weight: .medium, design: .rounded)).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading) }
}
