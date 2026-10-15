import SwiftUI

struct ChmodCalculatorView: View {
    @State private var input = "755"
    private var permission: ServerUtilities.Permission? { try? ServerUtilities.permission(input) }
    var body: some View {
        ToolPage("chmod計算", subtitle: "8進数・権限記号・チェックボックスを相互変換", symbol: "lock.shield", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 16) {
                    UtilityField(title: "8進数／記号", text: $input)
                    if let permission {
                        ForEach(Array([("所有者", 6), ("グループ", 3), ("その他", 0)].enumerated()), id: \.offset) { _, group in
                            HStack { Text(group.0).frame(width: 120, alignment: .leading)
                                ForEach(Array([("読み取り", 4), ("書き込み", 2), ("実行", 1)].enumerated()), id: \.offset) { _, bit in
                                    Toggle(bit.0, isOn: flag(permission.value, mask: bit.1 << group.1))
                                }
                            }
                        }
                        HStack { Toggle("setuid", isOn: flag(permission.value, mask: 0o4000)); Toggle("setgid", isOn: flag(permission.value, mask: 0o2000)); Toggle("sticky", isOn: flag(permission.value, mask: 0o1000)) }
                    }
                    HStack { ForEach(["644", "755", "600", "700", "1777"], id: \.self) { value in Button(value) { input = value } } }
                } }
                UtilityResult(result: Result {
                    let p = try ServerUtilities.permission(input)
                    return [("8進数", p.octal), ("記号", p.symbolic), ("コマンド例", "chmod \(p.octal) <対象パス>"), ("権限", p.details.joined(separator: "\n"))]
                })
                ToolFootnote(text: "特殊ビットも変換します。s/tは実行権限あり、S/Tは実行権限なし。ディレクトリの実行権限は通過を意味します。この画面でファイルの権限は変更されません。")
            }.padding(24) }
        }.frame(minWidth: 820, minHeight: 660)
    }
    private func flag(_ value: Int, mask: Int) -> Binding<Bool> {
        Binding(get: { value & mask != 0 }, set: { input = String(format: "%03o", $0 ? value | mask : value & ~mask) })
    }
}
struct CronReaderView: View {
    @State private var input = "0 9 * * 1-5"
    @State private var zone = "Asia/Tokyo"
    @State private var pattern = "毎日", minute = 0, hour = 9, day = 1, weekday = 1
    @State private var output: Result<[(String, String)], Error>?
    var body: some View {
        ToolPage("Cron解読・作成", subtitle: "5フィールドの条件と次回予定を確認", symbol: "calendar.badge.clock", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 14) {
                    UtilityField(title: "Cron式", text: $input).onChange(of: input) { _, _ in output = nil }
                    ThemePicker("タイムゾーン", selection: $zone, options: [("Asia/Tokyo", "日本時間"), ("UTC", "UTC"), (TimeZone.current.identifier, "システム（\(TimeZone.current.identifier)）")].reduce(into: [(String, String)]()) { result, pair in if !result.contains(where: { $0.0 == pair.0 }) { result.append(pair) } })
                        .onChange(of: zone) { _, _ in output = nil }
                    Button("解読・次回5件を計算") { calculate() }
                } }
                ToolCard { VStack(alignment: .leading, spacing: 12) {
                    Text("式を作成")
                    ThemePicker("実行間隔", selection: $pattern, options: ["毎分", "毎時", "毎日", "毎週", "毎月"].map { ($0, $0) })
                    if pattern != "毎分" { Stepper("分: \(minute)", value: $minute, in: 0...59) }
                    if !["毎分", "毎時"].contains(pattern) { Stepper("時: \(hour)", value: $hour, in: 0...23) }
                    if pattern == "毎週" { ThemePicker("曜日", selection: $weekday, options: Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()).map { ($0.offset, $0.element) }) }
                    if pattern == "毎月" { Stepper("日: \(day)", value: $day, in: 1...31) }
                    Button("作成した式を入力欄へ") {
                        switch pattern {
                        case "毎分": input = "* * * * *"
                        case "毎時": input = "\(minute) * * * *"
                        case "毎週": input = "\(minute) \(hour) * * \(weekday)"
                        case "毎月": input = "\(minute) \(hour) \(day) * *"
                        default: input = "\(minute) \(hour) * * *"
                        }; output = nil
                    }
                } }
                if let output { UtilityResult(result: output) }
                ToolFootnote(text: "標準的な分・時・日・月・曜日（0=日曜〜6=土曜）の5項目。*、数値、範囲、カンマ、*/n・範囲/nに対応。日と曜日を両方限定するとOR条件、どちらかが*始まりなら両条件で判定。次回は今より後の8年以内。夏時間の欠落時刻を飛ばし、重複時刻は最初の1回を表示。登録・実行は行いません。")
            }.padding(24) }
        }.frame(minWidth: 850, minHeight: 760)
    }
    private func calculate() {
        output = Result {
            let cron = try ServerUtilities.cron(input), tz = TimeZone(identifier: zone) ?? .current
            let dates = cron.next(after: Date(), timeZone: tz)
            return [("Cron式", cron.fields.joined(separator: " ")), ("条件", cron.descriptions.joined(separator: "\n")), ("次回予定（\(zone)）", dates.isEmpty ? "8年以内に該当する日時がありません。" : dates.map { ServerUtilities.dateText($0, timeZone: tz) }.joined(separator: "\n"))]
        }
    }
}
struct UnixTimeConverterView: View {
    @State private var input = "0", dateInput = "1970-01-01 09:00:00"
    @State private var unit = ServerUtilities.EpochUnit.seconds
    @State private var zone = "Asia/Tokyo"
    @State private var reverse = false
    private var timeZone: TimeZone { TimeZone(identifier: zone) ?? .current }
    private var result: Result<[(String, String)], Error> {
        Result {
            let date = reverse ? try ServerUtilities.date(dateInput, timeZone: timeZone) : try ServerUtilities.epoch(input, unit: unit)
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return [("Unix秒", String(format: "%.3f", date.timeIntervalSince1970)), ("Unixミリ秒", String(format: "%.0f", date.timeIntervalSince1970 * 1000)), (zone, ServerUtilities.dateText(date, timeZone: timeZone)), ("UTC（ISO 8601）", f.string(from: date))]
        }
    }
    var body: some View {
        ToolPage("Unix時刻変換", subtitle: "秒・ミリ秒と日時をタイムゾーン指定で変換", symbol: "clock.arrow.circlepath", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 14) {
                    Toggle("日時からUnix時刻へ", isOn: $reverse)
                    ThemePicker("タイムゾーン", selection: $zone, options: [("Asia/Tokyo", "日本時間"), ("UTC", "UTC")])
                    if reverse { UtilityField(title: "日時", text: $dateInput) }
                    else { ThemePicker("入力単位", selection: $unit, options: ServerUtilities.EpochUnit.allCases.map { ($0, $0.rawValue) }); UtilityField(title: "Unix時刻", text: $input) }
                    Button("現在時刻を入力") {
                        let now = Date(); input = unit == .seconds ? String(now.timeIntervalSince1970) : String(now.timeIntervalSince1970 * 1000)
                        dateInput = String(ServerUtilities.dateText(now, timeZone: timeZone).prefix(19))
                    }
                } }
                UtilityResult(result: result)
                ToolFootnote(text: "入力単位は明示指定。日時入力はyyyy-MM-dd HH:mm:ss。1970年以前の負のUnix時刻にも対応。日時表示は秒単位、Unix秒は小数3桁・ミリ秒は整数に丸めます。")
            }.padding(24) }
        }.frame(minWidth: 820, minHeight: 620)
    }
}
struct LinuxCommandView: View {
    @State private var query = "", category = "すべて", selection = "ls"
    private var filtered: [CommandReference] { CommandReference.entries.filter { (category == "すべて" || $0.category == category) && $0.matches(query) } }
    var body: some View {
        ToolPage("Linuxコマンド辞典", subtitle: "用途・オプション・実行例をローカル検索", symbol: "terminal", tint: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("名前・用途・オプションを検索", text: $query).textFieldStyle(.roundedBorder)
                ThemePicker("カテゴリ", selection: $category, options: (["すべて"] + Set(CommandReference.entries.map(\.category)).sorted()).map { ($0, $0) })
                HStack(alignment: .top, spacing: 20) {
                    ScrollView { VStack(alignment: .leading, spacing: 6) {
                        Text("\(filtered.count)件").foregroundStyle(.secondary)
                        ForEach(filtered) { command in Button { selection = command.name } label: { VStack(alignment: .leading) { Text(command.name).bold(); Text(command.summary).font(.caption) }.frame(maxWidth: .infinity, alignment: .leading).padding(8) }.buttonStyle(.plain) }
                    } }.frame(width: 260)
                    ScrollView {
                        if let command = filtered.first(where: { $0.name == selection }) ?? filtered.first {
                            UtilityResult(result: .success([("コマンド", command.name), ("用途", command.summary), ("主なオプション", command.options), ("実行例", command.example), ("補足", command.note)]))
                        } else { Text("該当するコマンドがありません。") }
                    }
                }
                ToolFootnote(text: "独自に記述した主要40コマンドのクイックリファレンス。LinuxのGNU系ツールを中心に記載。OS・実装・版により異なるため実行先のman/--helpも参照してください。画面からコマンドは実行しません。")
            }.padding(24)
        }.frame(minWidth: 950, minHeight: 740)
    }
}
