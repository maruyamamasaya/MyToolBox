import SwiftUI

struct LogHighlighterView: View {
    @State private var input = ""
    @State private var lines: [LogEntry] = []
    @State private var levels = Set(LogLevel.allCases)
    @State private var query = ""
    @State private var context = 0
    @State private var wrap = false
    @State private var custom = ""
    @State private var terms: [String] = []
    @State private var current = 0
    @State private var status = ""
    private var visible: [LogEntry] { LogHighlighter.visible(lines, levels: levels, context: context) }
    private var hits: [(line: Int, range: NSRange)] {
        visible.flatMap { line in LogHighlighter.matches(line.text, query: query).map { (line.id, $0) } }
    }
    @State private var expanded: Bool
    @State private var showsSettings = false
    init(initiallyExpanded: Bool = false, initialInput: String = "", initiallyAnalyzed: Bool = false,
         initialQuery: String = "", initialLevels: Set<LogLevel> = Set(LogLevel.allCases), initialWrap: Bool = false) {
        _expanded = State(initialValue: initiallyExpanded); _input = State(initialValue: initialInput)
        _lines = State(initialValue: initiallyAnalyzed && initialInput.utf8.count <= 2_000_000 ? LogHighlighter.parse(initialInput) : [])
        _query = State(initialValue: initialQuery); _levels = State(initialValue: initialLevels); _wrap = State(initialValue: initialWrap)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("ログハイライター", systemImage: "text.magnifyingglass").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            TextEditor(text: $input).font(.system(.body, design: .monospaced))
                .frame(height: expanded ? 180 : 100).accessibilityLabel("ログ貼り付け")
            HStack {
                Button("ログ解析", action: analyze)
                Menu {
                    Button("ERRORのみ") { levels = [.fatal, .error]; current = 0 }
                    Button("WARN以上") { levels = [.fatal, .error, .warn]; current = 0 }
                    Button("すべて表示") { levels = Set(LogLevel.allCases); current = 0 }
                } label: {
                    Text(levels == Set(LogLevel.allCases) ? "全レベル" : levels == [.fatal, .error] ? "ERRORのみ" : levels == [.fatal, .error, .warn] ? "WARN以上" : "レベル選択中")
                }
                Spacer(minLength: 0)
                Button { input = ""; lines = []; query = ""; current = 0; status = "" } label: {
                    Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("ログをクリア")
                Button { showsSettings.toggle() } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("レベル・表示・強調設定").popover(isPresented: $showsSettings) { settings }
            }
            logResults
            HStack {
                Button("結果をコピー", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    status = NSPasteboard.general.setString(visible.map(\.text).joined(separator: "\n"), forType: .string) ? "コピーしました" : "コピーできませんでした"
                }.disabled(visible.isEmpty)
                Spacer()
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 600)))
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
        .onChange(of: input) { _, value in
            lines = []; current = 0
            status = value.isEmpty ? "" : "入力が変わりました。「ログ解析」で更新してください。"
        }
        .onChange(of: query) { _, _ in current = 0 }
        .onChange(of: context) { _, _ in current = 0 }
    }
    private var logResults: some View {
        let displayed = visible
        let searchHits = hits
        let selectedHit = searchHits.isEmpty ? nil : searchHits[min(current, searchHits.count - 1)]
        return ScrollViewReader { proxy in
            VStack(spacing: 8) {
                HStack {
                    TextField("検索（文字列）", text: $query).textFieldStyle(.roundedBorder).accessibilityLabel("ログ内検索")
                    Button { move(-1, proxy: proxy) } label: { Image(systemName: "chevron.up").frame(width: 24, height: 24).contentShape(Rectangle()) }
                        .accessibilityLabel("前の一致へ").disabled(searchHits.isEmpty)
                    Button { move(1, proxy: proxy) } label: { Image(systemName: "chevron.down").frame(width: 24, height: 24).contentShape(Rectangle()) }
                        .accessibilityLabel("次の一致へ").disabled(searchHits.isEmpty)
                }
                HStack {
                    Text("全\(lines.count)行 · \(displayed.count)行を表示")
                    Spacer()
                    Text(searchHits.isEmpty ? "一致 0件" : "\(min(current, searchHits.count - 1) + 1) / \(searchHits.count)件")
                }.font(.caption).foregroundStyle(.secondary)
                GeometryReader { geometry in
                    let gutter = CGFloat(max(3, String(lines.count).count) * 8)
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(displayed) { line in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(String(line.id)).foregroundStyle(.secondary).frame(width: gutter, alignment: .trailing)
                                    Text(highlight(line, selected: selectedHit)).textSelection(.enabled)
                                        .fixedSize(horizontal: !wrap, vertical: true)
                                        .frame(width: wrap ? max(80, geometry.size.width - gutter - 24) : nil, alignment: .leading)
                                }.font(.system(.body, design: .monospaced)).id(line.id)
                            }
                            if displayed.isEmpty { Text(lines.isEmpty ? "ログを貼り付けて解析してください。" : "選択条件に一致するログはありません。").font(.caption).foregroundStyle(.secondary) }
                        }.padding(8).frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }
                }.background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("レベル・表示・強調").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Toggle(isOn: Binding(get: { levels.contains(level) }, set: { selected in
                            if selected { levels.insert(level) } else { levels.remove(level) }; current = 0
                        })) { Text("\(level.rawValue) \(lines.filter { $0.level == level }.count)").foregroundStyle(color(level)) }.toggleStyle(.checkbox)
                    }
                }
                Picker("前後の行も表示", selection: $context) {
                    ForEach([0, 1, 3, 5, 10], id: \.self) { Text("\($0)行").tag($0) }
                }
                Toggle("長い行を折り返す", isOn: $wrap)
                Divider()
                Text("カスタムハイライト").font(.headline)
                HStack {
                    TextField("キーワード", text: $custom).textFieldStyle(.roundedBorder).onSubmit(addTerm)
                    Button("追加", action: addTerm).disabled(terms.count >= 10 || custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ForEach(terms, id: \.self) { term in
                    HStack { Text(term).lineLimit(2); Spacer(); Button { terms.removeAll { $0 == term } } label: { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel(term + "の強調を削除") }
                }
                Text("各100文字・10個まで。ログは2 MB以内。保存・送信はしません。検索は表示中の行が対象です。レベル判定は行内で最も重大なキーワードを優先します。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }.frame(width: 330, height: 440)
    }
    private func analyze() {
        guard input.utf8.count <= 2_000_000 else { status = "入力は2 MB以内にしてください。"; return }
        lines = LogHighlighter.parse(input); levels = Set(LogLevel.allCases); current = 0; status = "解析しました"
    }
    private func addTerm() {
        let term = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, term.count <= 100, terms.count < 10, !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else { status = "100文字以内・重複なし・10個まで指定できます。"; return }
        terms.append(term); custom = ""; status = ""
    }
    private func move(_ delta: Int, proxy: ScrollViewProxy) {
        guard !hits.isEmpty else { return }
        current = (current + delta + hits.count) % hits.count
        proxy.scrollTo(hits[current].line, anchor: .center)
    }
    private func highlight(_ line: LogEntry, selected: (line: Int, range: NSRange)?) -> AttributedString {
        var result = AttributedString(line.text)
        result.foregroundColor = color(line.level)
        for term in terms + (query.isEmpty ? [] : [query]) {
            for range in LogHighlighter.matches(line.text, query: term) {
                guard let source = Range(range, in: line.text), let converted = Range(source, in: result) else { continue }
                result[converted].backgroundColor = term == query ? .yellow.opacity(0.5) : .cyan.opacity(0.3)
                result[converted].foregroundColor = .primary
            }
        }
        if let hit = selected {
            if hit.line == line.id, let source = Range(hit.range, in: line.text), let converted = Range(source, in: result) {
                result[converted].backgroundColor = .orange.opacity(0.8)
            }
        }
        return result
    }
    private func color(_ level: LogLevel) -> Color {
        switch level { case .fatal: return .pink; case .error: return .red; case .warn: return .orange; case .info: return .primary; case .debug: return .cyan; case .trace: return .purple; case .other: return .secondary }
    }
}
