import SwiftUI

struct ChmodCalculatorView: View {
    @State private var checkerInput = "755"
    @State private var generatorInput = "755"
    @State private var generating = false
    private var input: String { generating ? generatorInput : checkerInput }
    private var inputBinding: Binding<String> { Binding(get: { input }, set: { if generating { generatorInput = $0 } else { checkerInput = $0 } }) }
    private var permission: ServerUtilities.Permission? { try? ServerUtilities.permission(input) }
    @State private var expanded: Bool
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initiallyGenerating: Bool = false, initialCheckerInput: String = "755", initialGeneratorInput: String = "755") {
        _expanded = State(initialValue: initiallyExpanded); _generating = State(initialValue: initiallyGenerating)
        _checkerInput = State(initialValue: initialCheckerInput); _generatorInput = State(initialValue: initialGeneratorInput)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("chmod計算", systemImage: "lock.shield").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("機能", selection: $generating) { Text("チェッカー").tag(false); Text("ジェネレーター").tag(true) }.pickerStyle(.segmented)
            HStack {
                TextField("8進数／権限記号", text: inputBinding).textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced)).accessibilityLabel("8進数または権限記号")
                if !generating {
                    Button { checkerInput = "" } label: { Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("チェッカー入力をクリア")
                }
            }
            HStack(spacing: 6) {
                ForEach(["644", "755", "600", "700", "1777"], id: \.self) { value in
                    Button { inputBinding.wrappedValue = value } label: { Text(value).frame(maxWidth: .infinity) }
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let permission {
                        if generating { permissionGrid(permission) }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("8進数").font(.caption).foregroundStyle(.secondary)
                                Text(permission.octal).font(.system(.title2, design: .monospaced).bold()).textSelection(.enabled)
                            }
                            Button { copy(permission.octal) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("8進数をコピー")
                            Spacer()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("権限記号").font(.caption).foregroundStyle(.secondary)
                                Text(permission.symbolic).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            }
                            Button { copy(permission.symbolic) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("権限記号をコピー")
                        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("コマンド例").font(.caption).foregroundStyle(.secondary); Spacer()
                                Button { copy("chmod \(permission.octal) <対象パス>") } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("コマンド例をコピー")
                            }
                            Text("chmod \(permission.octal) <対象パス>").font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(permission.details, id: \.self) { Text($0).font(.caption).textSelection(.enabled) }
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    } else {
                        if case .failure(let error) = Result(catching: { try ServerUtilities.permission(input) }) {
                            Text(error.localizedDescription).font(.caption).foregroundStyle(.red)
                        }
                    }
                }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Button("結果をコピー", systemImage: "doc.on.doc") {
                    if let permission { copy("8進数: \(permission.octal)\n記号: \(permission.symbolic)\nコマンド例: chmod \(permission.octal) <対象パス>\n" + permission.details.joined(separator: "\n")) }
                }.disabled(permission == nil)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("権限・特殊ビットの説明").popover(isPresented: $showsHelp) {
                        Text("setuid: 所有者の権限で実行。setgid: グループの権限で実行・ディレクトリではグループ継承。sticky: 共有ディレクトリ内の削除・改名を制限。s/tは実行権限あり、S/Tは実行権限なし。ディレクトリの実行権限は通過を意味します。この画面でファイルの権限は変更されません。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 600)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
            .onChange(of: input) { _, _ in status = "" }
    }
    private func permissionGrid(_ permission: ServerUtilities.Permission) -> some View {
        VStack(spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow { Text(""); Text("読取"); Text("書込"); Text("実行") }.font(.caption).foregroundStyle(.secondary)
                ForEach(Array([("所有者", 6), ("グループ", 3), ("その他", 0)].enumerated()), id: \.offset) { _, group in
                    GridRow {
                        Text(group.0).font(.caption)
                        ForEach(Array([("読み取り", 4), ("書き込み", 2), ("実行", 1)].enumerated()), id: \.offset) { _, bit in
                            Toggle("", isOn: flag(permission.value, mask: bit.1 << group.1)).labelsHidden().toggleStyle(.checkbox)
                                .accessibilityLabel(group.0 + "の" + bit.0).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack {
                Toggle("setuid", isOn: flag(permission.value, mask: 0o4000))
                Toggle("setgid", isOn: flag(permission.value, mask: 0o2000))
                Toggle("sticky", isOn: flag(permission.value, mask: 0o1000))
            }.toggleStyle(.checkbox).font(.caption)
        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
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
    @State private var expanded: Bool
    @State private var tab: Int
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initialTab: Int = 0, initialInput: String = "0 9 * * 1-5",
         initialPattern: String = "毎日", initialOutput: Result<[(String, String)], Error>? = nil) {
        _expanded = State(initialValue: initiallyExpanded); _tab = State(initialValue: initialTab)
        _input = State(initialValue: initialInput); _pattern = State(initialValue: initialPattern)
        _output = State(initialValue: initialOutput)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Cron解読・作成", systemImage: "calendar.badge.clock").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("表示", selection: $tab) { Text("解読・予定").tag(0); Text("式を作成").tag(1) }.pickerStyle(.segmented)
            if tab == 0 { reader } else { builder }
            HStack {
                if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("Cronの対応形式").popover(isPresented: $showsHelp) {
                        Text("標準的な分・時・日・月・曜日（0=日曜〜6=土曜）の5項目。*、数値、範囲、カンマ、*/n・範囲/nに対応。日と曜日を両方限定するとOR条件、どちらかが*始まりなら両条件で判定。次回は今より後の8年以内。夏時間の欠落時刻を飛ばし、重複時刻は最初の1回を表示。登録・実行は行いません。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 560)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 560)
            .onChange(of: input) { _, _ in output = nil; status = "" }
            .onChange(of: zone) { _, _ in output = nil; status = "" }
    }
    private var reader: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("分 時 日 月 曜日", text: $input).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).accessibilityLabel("Cron式")
                Button { input = ""; output = nil } label: { Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("Cron式をクリア")
            }
            Picker("タイムゾーン", selection: $zone) {
                Text("日本時間").tag("Asia/Tokyo"); Text("UTC").tag("UTC")
                if !["Asia/Tokyo", "UTC"].contains(TimeZone.current.identifier) {
                    Text("システム（\(TimeZone.current.identifier)）").tag(TimeZone.current.identifier)
                }
            }
            HStack { Button("次回5件を計算", action: calculate); Spacer() }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let output {
                        switch output {
                        case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                        case .success(let rows):
                            ForEach(rows.indices, id: \.self) { index in
                                if index >= 2 { resultSection(rows[index].0, rows[index].1) }
                            }
                        }
                    }
                    switch Result(catching: { try ServerUtilities.cron(input) }) {
                    case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                    case .success(let cron):
                        resultSection("実行内容", cron.summary)
                        resultSection("各フィールド", cron.descriptions.joined(separator: "\n"))
                    }
                }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Button("式をコピー", systemImage: "doc.on.doc") { copy(input) }.disabled((try? ServerUtilities.cron(input)) == nil)
                Button("結果をコピー") {
                    if case .success(let rows) = output { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) }
                }.disabled(!hasOutput)
                Spacer(minLength: 0)
            }
        }
    }
    private var hasOutput: Bool { if case .success = output { return true }; return false }
    private var builder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("実行間隔", selection: $pattern) {
                ForEach(["毎分", "毎時", "毎日", "毎週", "毎月"], id: \.self) { Text($0).tag($0) }
            }
            if pattern != "毎分" { Stepper("分: \(minute)", value: $minute, in: 0...59) }
            if !["毎分", "毎時"].contains(pattern) { Stepper("時: \(hour)", value: $hour, in: 0...23) }
            if pattern == "毎週" {
                Picker("曜日", selection: $weekday) {
                    ForEach(Array(["日", "月", "火", "水", "木", "金", "土"].enumerated()), id: \.offset) { Text($0.element).tag($0.offset) }
                }
            }
            if pattern == "毎月" { Stepper("日: \(day)", value: $day, in: 1...31) }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    resultSection("作成した式", builderCron)
                    if let cron = try? ServerUtilities.cron(builderCron) { resultSection("実行内容", cron.summary) }
                }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Button("作成した式を入力欄へ") { input = builderCron; output = nil; tab = 0 }
        }
    }
    private func resultSection(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary); Spacer()
                Button { copy(value) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel(title + "をコピー")
            }
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
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
    @State private var expanded: Bool
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initiallyReverse: Bool = false, initialInput: String = "0",
         initialDateInput: String = "1970-01-01 09:00:00", initialUnit: ServerUtilities.EpochUnit = .automatic, initialZone: String = "Asia/Tokyo") {
        _expanded = State(initialValue: initiallyExpanded); _reverse = State(initialValue: initiallyReverse)
        _input = State(initialValue: initialInput); _dateInput = State(initialValue: initialDateInput)
        _unit = State(initialValue: initialUnit); _zone = State(initialValue: initialZone)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Unix時刻変換", systemImage: "clock.arrow.circlepath").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("変換方向", selection: $reverse) { Text("Unix → 日時").tag(false); Text("日時 → Unix").tag(true) }.pickerStyle(.segmented)
            Picker("タイムゾーン", selection: $zone) {
                Text("日本時間").tag("Asia/Tokyo"); Text("UTC").tag("UTC"); Text("システム").tag("local")
            }
            if !reverse {
                Picker("入力単位", selection: $unit) {
                    ForEach(ServerUtilities.EpochUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
            }
            HStack {
                TextField(reverse ? "yyyy-MM-dd HH:mm:ss" : "Unix時刻", text: reverse ? $dateInput : $input)
                    .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    .accessibilityLabel(reverse ? "日時入力" : "Unix時刻入力")
                Button { setNow() } label: {
                    Image(systemName: "clock").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("現在時刻を入力").help("現在時刻を入力")
            }
            ScrollView {
                switch result {
                case .failure(let error): Text(error.localizedDescription).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                case .success(let rows):
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), alignment: .top)], alignment: .leading, spacing: 8) {
                        ForEach(rows.indices, id: \.self) { index in
                            let row = rows[index]
                            outputCard(row.0, row.1)
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Button("結果をコピー", systemImage: "doc.on.doc") {
                    if case .success(let rows) = result { copy(rows.map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) }
                }.disabled(!hasResult)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("Unix時刻変換の使い方").popover(isPresented: $showsHelp) {
                        Text("自動判定は絶対値1e11以上をミリ秒、それ未満を秒と解釈。明示指定へ切替可。日時入力はyyyy-MM-dd HH:mm[:ss]（T区切りも可）。1970年以前の負のUnix時刻にも対応。日時表示は秒単位、Unix秒は小数3桁・ミリ秒は整数に丸めます。時計ボタンで現在時刻を入力します。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 600)))
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
            .onChange(of: input) { _, _ in status = "" }.onChange(of: dateInput) { _, _ in status = "" }
            .onChange(of: reverse) { _, _ in status = "" }.onChange(of: unit) { _, _ in status = "" }.onChange(of: zone) { _, _ in status = "" }
    }
    private func outputCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if expanded {
                HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer(); copyButton(title, value) }
                Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    Text(title).font(.caption).foregroundStyle(.secondary).frame(width: 82, alignment: .leading)
                    Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    copyButton(title, value)
                }
            }
        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
    private func copyButton(_ title: String, _ value: String) -> some View {
        Button { copy(value) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel(title + "をコピー")
    }
    private var hasResult: Bool { if case .success = result { return true }; return false }
    private func setNow() {
        let now = Date()
        input = unit == .milliseconds ? String(now.timeIntervalSince1970 * 1000) : String(now.timeIntervalSince1970)
        dateInput = String(ServerUtilities.dateText(now, timeZone: timeZone).prefix(19))
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
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
        selection = name; detailTab = 1; historyJSON = encode([name] + Array(history.filter { $0 != name }.prefix(5)))
    }
    private func favorite(_ name: String) { favoritesJSON = encode(favorites.contains(name) ? favorites.filter { $0 != name } : [name] + favorites) }
    @State private var expanded: Bool
    @State private var detailTab: Int
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initialQuery: String = "", initialCategory: String = "すべて", initialSelection: String = "ls", initialDetailTab: Int = 0) {
        _expanded = State(initialValue: initiallyExpanded); _detailTab = State(initialValue: initialDetailTab)
        _query = State(initialValue: initialQuery); _category = State(initialValue: initialCategory); _selection = State(initialValue: initialSelection)
    }
    private var command: CommandReference? { filtered.first(where: { $0.name == selection }) ?? filtered.first }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Linuxコマンド辞典", systemImage: "terminal").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            HStack {
                TextField("名前・用途・オプションを検索", text: Binding(get: { query }, set: { query = $0; if !expanded { detailTab = 0 } }))
                    .textFieldStyle(.roundedBorder).focused($searchFocused).accessibilityLabel("コマンドを検索")
                Button { searchFocused = true } label: { Image(systemName: "magnifyingglass").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("検索へ移動").keyboardShortcut("f", modifiers: .command)
                Button { query = ""; category = "すべて"; detailTab = 0 } label: { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("検索・分類を解除")
            }
            HStack {
                Picker("カテゴリ", selection: Binding(get: { category }, set: { category = $0; if !expanded { detailTab = 0 } })) {
                    ForEach(["すべて"] + Set(CommandReference.entries.map(\.category)).sorted(), id: \.self) { value in
                        Text(value == "すべて" ? value : value + "（\(CommandReference.entries.filter { $0.category == value }.count)）").tag(value)
                    }
                }
                Menu {
                    if favorites.isEmpty { Text("まだ登録されていません") }
                    ForEach(favorites, id: \.self) { name in Button(name) { select(name, clearFilters: true) } }
                } label: { Image(systemName: "star").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("お気に入り")
                Menu {
                    if history.isEmpty { Text("履歴はありません") }
                    ForEach(history, id: \.self) { name in Button(name) { select(name, clearFilters: true) } }
                    Divider(); Button("履歴を消去") { historyJSON = "[]" }
                } label: { Image(systemName: "clock").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("最近見たコマンド")
            }
            if expanded {
                HStack(alignment: .top, spacing: 10) { commandList.frame(width: 290); commandDetails }
            } else {
                Picker("表示", selection: $detailTab) { Text("一覧 \(filtered.count)件").tag(0); Text("使い方").tag(1) }.pickerStyle(.segmented)
                if detailTab == 0 { commandList } else { commandDetails }
            }
            HStack {
                Text(status.isEmpty ? "\(CommandReference.entries.count)件収録・端末内の辞典" : status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("コマンド辞典について").popover(isPresented: $showsHelp) {
                        Text("参照版の162コマンドと補足3件を収録。説明・オプション・例は独自記述。お気に入りと閲覧履歴6件を端末内に保存。OS・実装・版の差は実行先のman/--helpで確認してください。オプションの引数は必要に応じ補ってください。コマンドは実行しません。")
                            .font(.caption).padding(16).frame(width: 310)
                    }
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 600)))
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
            .onKeyPress("/") { if searchFocused { return .ignored }; searchFocused = true; return .handled }
    }
    private var commandList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(filtered) { item in
                    Button { select(item.name) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(item.name).font(.system(.body, design: .monospaced).bold()); if favorites.contains(item.name) { Image(systemName: "star.fill").foregroundStyle(.yellow) }; Spacer() }
                            Text(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }.padding(8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                            .background(command?.name == item.name ? Color.cyan.opacity(0.12) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)
                }
                if filtered.isEmpty { Text("該当するコマンドがありません。").font(.caption).foregroundStyle(.secondary).padding(8) }
            }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private var commandDetails: some View {
        VStack(spacing: 8) {
            if let command {
                HStack {
                    Text(command.name).font(.system(.title3, design: .monospaced).bold()).textSelection(.enabled)
                    Button { copy(command.name) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("コマンド名をコピー")
                    Spacer()
                    Button { favorite(command.name) } label: { Image(systemName: favorites.contains(command.name) ? "star.fill" : "star").frame(width: 24, height: 24).contentShape(Rectangle()) }
                        .accessibilityLabel(favorites.contains(command.name) ? "お気に入りから解除" : "お気に入りへ登録")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(detailRows(command), id: \.0) { title, value in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(title).font(.caption).foregroundStyle(.secondary); Spacer()
                                    Button { copy(value) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel(title + "をコピー")
                                }
                                Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        }
                        Text("関連コマンド").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 85))], alignment: .leading) {
                            ForEach(command.related) { related in Button(related.name) { select(related.name, clearFilters: true) } }
                        }
                    }.padding(2)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack {
                    Button("すべてコピー", systemImage: "doc.on.doc") { copy(([("コマンド", command.name)] + detailRows(command)).map { $0.0 + ": " + $0.1 }.joined(separator: "\n")) }
                    Spacer()
                }
            } else { Text("該当するコマンドがありません。").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func detailRows(_ command: CommandReference) -> [(String, String)] {
        [("用途", command.summary), ("カテゴリ", command.category), ("主なオプション", command.options), ("使用例", command.example), ("先頭オプション付き", command.optionCommand), ("補足", command.note)]
    }
    private func copy(_ text: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(text, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}
