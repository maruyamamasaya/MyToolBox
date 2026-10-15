import SwiftUI

struct ChmodCalculatorView: View {
    @State private var checkerInput = "755"
    @State private var generatorInput = "755"
    @State private var generating = false
    private var input: String { generating ? generatorInput : checkerInput }
    private var inputBinding: Binding<String> { Binding(get: { input }, set: { if generating { generatorInput = $0 } else { checkerInput = $0 } }) }
    private var permission: ServerUtilities.Permission? { try? ServerUtilities.permission(input) }
    var body: some View {
        ToolPage("chmod計算", subtitle: "8進数・権限記号・チェックボックスを相互変換", symbol: "lock.shield", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 16) {
                    ThemePicker("機能", selection: $generating, options: [(false, "権限チェッカー"), (true, "権限ジェネレーター")], tabs: true)
                    UtilityField(title: "8進数／記号", text: inputBinding)
                    if !generating { Button("入力をクリア") { checkerInput = "" } }
                    if let permission, generating {
                        ForEach(Array([("所有者", 6), ("グループ", 3), ("その他", 0)].enumerated()), id: \.offset) { _, group in
                            HStack { Text(group.0).frame(width: 120, alignment: .leading)
                                ForEach(Array([("読み取り", 4), ("書き込み", 2), ("実行", 1)].enumerated()), id: \.offset) { _, bit in
                                    Toggle(bit.0, isOn: flag(permission.value, mask: bit.1 << group.1))
                                }
                            }
                        }
                        HStack { Toggle("setuid", isOn: flag(permission.value, mask: 0o4000)); Toggle("setgid", isOn: flag(permission.value, mask: 0o2000)); Toggle("sticky", isOn: flag(permission.value, mask: 0o1000)) }
                        Text("setuid: 所有者の権限で実行 ／ setgid: グループの権限で実行・ディレクトリではグループ継承 ／ sticky: 共有ディレクトリ内の削除・改名を制限").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack { ForEach(["644", "755", "600", "700", "1777"], id: \.self) { value in Button(value) { inputBinding.wrappedValue = value } } }
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
        Binding(get: { value & mask != 0 }, set: { generatorInput = String(format: "%03o", $0 ? value | mask : value & ~mask) })
    }
}
struct CronReaderView: View {
    @State private var input = "0 9 * * 1-5"
    @State private var zone = "Asia/Tokyo"
    @State private var pattern = "毎日"
    @State private var minute = 0
    @State private var hour = 9
    @State private var day = 1
    @State private var weekday = 1
    @State private var output: Result<[(String, String)], Error>?
    var body: some View {
        ToolPage("Cron解読・作成", subtitle: "5フィールドの条件と次回予定を確認", symbol: "calendar.badge.clock", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 14) {
                    UtilityField(title: "Cron式", text: $input).onChange(of: input) { _, _ in output = nil }
                    Button("入力をクリア") { input = ""; output = nil }
                    UtilityResult(result: Result { let cron = try ServerUtilities.cron(input); return [("Cron式", cron.fields.joined(separator: " ")), ("実行内容", cron.summary), ("各フィールド", cron.descriptions.joined(separator: "\n"))] })
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
                    UtilityResult(result: Result { let cron = try ServerUtilities.cron(builderCron); return [("作成した式", builderCron), ("実行内容", cron.summary)] })
                    Button("作成した式を入力欄へ") { input = builderCron; output = nil }
                } }
                if let output { UtilityResult(result: output) }
                ToolFootnote(text: "標準的な分・時・日・月・曜日（0=日曜〜6=土曜）の5項目。*、数値、範囲、カンマ、*/n・範囲/nに対応。日と曜日を両方限定するとOR条件、どちらかが*始まりなら両条件で判定。次回は今より後の8年以内。夏時間の欠落時刻を飛ばし、重複時刻は最初の1回を表示。登録・実行は行いません。")
            }.padding(24) }
        }.frame(minWidth: 850, minHeight: 760)
    }
    private var builderCron: String {
        switch pattern {
        case "毎分": return "* * * * *"
        case "毎時": return "\(minute) * * * *"
        case "毎週": return "\(minute) \(hour) * * \(weekday)"
        case "毎月": return "\(minute) \(hour) \(day) * *"
        default: return "\(minute) \(hour) * * *"
        }
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
    @State private var input = "0"
    @State private var dateInput = "1970-01-01 09:00:00"
    @State private var unit = ServerUtilities.EpochUnit.automatic
    @State private var zone = "Asia/Tokyo"
    @State private var reverse = false
    private var timeZone: TimeZone { TimeZone(identifier: zone) ?? .current }
    private var result: Result<[(String, String)], Error> {
        Result {
            let date = reverse ? try ServerUtilities.date(dateInput, timeZone: timeZone) : try ServerUtilities.epoch(input, unit: unit)
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return [("Unix秒", String(format: "%.3f", date.timeIntervalSince1970)), ("Unixミリ秒", String(format: "%.0f", date.timeIntervalSince1970 * 1000)), (zone, ServerUtilities.dateText(date, timeZone: timeZone)), ("システムのローカル時刻", ServerUtilities.dateText(date, timeZone: .current)), ("UTC", ServerUtilities.dateText(date, timeZone: TimeZone(secondsFromGMT: 0)!)), ("UTC（ISO 8601）", f.string(from: date))]
        }
    }
    var body: some View {
        ToolPage("Unix時刻変換", subtitle: "秒・ミリ秒と日時をタイムゾーン指定で変換", symbol: "clock.arrow.circlepath", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 18) {
                ToolCard { VStack(alignment: .leading, spacing: 14) {
                    Toggle("日時からUnix時刻へ", isOn: $reverse)
                    ThemePicker("タイムゾーン", selection: $zone, options: [("Asia/Tokyo", "日本時間"), ("UTC", "UTC"), ("local", "システムのローカル時刻")])
                    if reverse { UtilityField(title: "日時", text: $dateInput) }
                    else { ThemePicker("入力単位", selection: $unit, options: ServerUtilities.EpochUnit.allCases.map { ($0, $0.rawValue) }); UtilityField(title: "Unix時刻", text: $input) }
                    Button("現在時刻を入力") {
                        let now = Date(); input = unit == .milliseconds ? String(now.timeIntervalSince1970 * 1000) : String(now.timeIntervalSince1970)
                        dateInput = String(ServerUtilities.dateText(now, timeZone: timeZone).prefix(19))
                    }
                } }
                UtilityResult(result: result)
                ToolFootnote(text: "自動判定は絶対値1e11以上をミリ秒、それ未満を秒と解釈。明示指定へ切替可。日時入力はyyyy-MM-dd HH:mm[:ss]（T区切りも可）。1970年以前の負のUnix時刻にも対応。日時表示は秒単位、Unix秒は小数3桁・ミリ秒は整数に丸めます。")
            }.padding(24) }
        }.frame(minWidth: 820, minHeight: 620)
    }
}
struct LinuxCommandView: View {
    @State private var query = ""
    @State private var category = "すべて"
    @State private var selection = "ls"
    @AppStorage("tools.linuxCommands.favorites.v1") private var favoritesJSON = "[]"
    @AppStorage("tools.linuxCommands.history.v1") private var historyJSON = "[]"
    @FocusState private var searchFocused: Bool
    private var favorites: [String] { names(favoritesJSON) }
    private var history: [String] { names(historyJSON) }
    private var filtered: [CommandReference] { CommandReference.entries.filter { (category == "すべて" || $0.category == category) && $0.matches(query) } }
    private func names(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8), let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        let valid = Set(CommandReference.entries.map(\.name)); var seen = Set<String>()
        return names.filter { valid.contains($0) && seen.insert($0).inserted }
    }
    private func encode(_ names: [String]) -> String { String(decoding: (try? JSONEncoder().encode(names)) ?? Data("[]".utf8), as: UTF8.self) }
    private func select(_ name: String, clearFilters: Bool = false) {
        if clearFilters { query = ""; category = "すべて" }
        selection = name; historyJSON = encode([name] + Array(history.filter { $0 != name }.prefix(5)))
    }
    private func favorite(_ name: String) { favoritesJSON = encode(favorites.contains(name) ? favorites.filter { $0 != name } : [name] + favorites) }
    var body: some View {
        ToolPage("Linuxコマンド辞典", subtitle: "\(CommandReference.entries.count)コマンド・18カテゴリ＋補足・お気に入り・履歴", symbol: "terminal", tint: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("名前・用途・オプションを検索", text: $query).textFieldStyle(.roundedBorder).focused($searchFocused)
                    Button("検索へ /") { searchFocused = true }.keyboardShortcut("f", modifiers: .command)
                    Button("検索・分類を解除") { query = ""; category = "すべて" }
                }
                ThemePicker("カテゴリ", selection: $category, options: (["すべて"] + Set(CommandReference.entries.map(\.category)).sorted()).map { value in
                    (value, value == "すべて" ? value : value + "（\(CommandReference.entries.filter { $0.category == value }.count)）")
                })
                HStack(alignment: .top, spacing: 20) {
                    ScrollView { VStack(alignment: .leading, spacing: 8) {
                        Text("お気に入り").bold()
                        if favorites.isEmpty { Text("まだ登録されていません").font(.caption).foregroundStyle(.secondary) }
                        ForEach(favorites, id: \.self) { name in Button("★ " + name) { select(name, clearFilters: true) } }
                        HStack { Text("最近見たコマンド").bold(); Spacer(); Button("消去") { historyJSON = "[]" } }
                        ForEach(history, id: \.self) { name in Button(name) { select(name, clearFilters: true) } }
                        Divider(); Text("検索結果 \(filtered.count)件").foregroundStyle(.secondary)
                        ForEach(filtered) { command in
                            Button { select(command.name) } label: {
                                VStack(alignment: .leading) { Text((favorites.contains(command.name) ? "★ " : "") + command.name).bold(); Text(command.summary).font(.caption) }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            }.buttonStyle(.plain)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading) }.frame(width: 290)
                    ScrollView {
                        if let command = filtered.first(where: { $0.name == selection }) ?? filtered.first {
                            VStack(alignment: .leading, spacing: 16) {
                                Button(favorites.contains(command.name) ? "★ お気に入りから解除" : "☆ お気に入りへ登録") { favorite(command.name) }
                                UtilityResult(result: .success([("コマンド", command.name), ("用途", command.summary), ("カテゴリ", command.category), ("主なオプション", command.options), ("使用例", command.example), ("先頭オプション付き", command.optionCommand), ("補足", command.note)]))
                                Text("関連コマンド").bold()
                                HStack { ForEach(command.related) { related in Button(related.name) { select(related.name, clearFilters: true) } } }
                            }
                        } else { Text("該当するコマンドがありません。") }
                    }
                }
                ToolFootnote(text: "参照版の162コマンドを収録し、既存の補足3件も維持。説明・オプション・例は独自記述。お気に入りと閲覧履歴6件を端末内に保存。OS・実装・版の差は実行先のman/--helpで確認してください。オプションの引数は必要に応じ補ってください。コマンドは実行しません。")
            }.padding(24)
                .onKeyPress("/") { if searchFocused { return .ignored }; searchFocused = true; return .handled }
        }.frame(minWidth: 1050, minHeight: 800)
    }
}
