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
    var body: some View {
        let displayed = visible
        let searchHits = hits
        let selectedHit = searchHits.isEmpty ? nil : searchHits[min(current, searchHits.count - 1)]
        ToolPage("ログハイライター", subtitle: "ログを色分け・絞り込み、気になる箇所を検索。", symbol: "text.magnifyingglass", tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $input).font(.system(.body, design: .monospaced))
                    .frame(height: 130).accessibilityLabel("ログ貼り付け")
                HStack {
                    Button("ログ解析", action: analyze)
                    Button("ERRORのみ") { levels = [.fatal, .error]; current = 0 }
                    Button("WARN以上") { levels = [.fatal, .error, .warn]; current = 0 }
                    Button("すべて表示") { levels = Set(LogLevel.allCases); current = 0 }
                    Spacer()
                    Button("結果をコピー") {
                        NSPasteboard.general.clearContents()
                        status = NSPasteboard.general.setString(visible.map(\.text).joined(separator: "\n"), forType: .string) ? "コピーしました" : "コピーできませんでした"
                    }.disabled(visible.isEmpty)
                    Button("クリア") { input = ""; lines = []; query = ""; current = 0; status = "" }
                }
                HStack {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Toggle(isOn: Binding(get: { levels.contains(level) }, set: { selected in
                            if selected { levels.insert(level) } else { levels.remove(level) }; current = 0
                        })) { Text("\(level.rawValue) \(lines.filter { $0.level == level }.count)").foregroundStyle(color(level)) }
                        .toggleStyle(.checkbox)
                    }
                }
                HStack {
                    TextField("検索（文字列）", text: $query).textFieldStyle(.roundedBorder)
                    Text("一致 \(hits.count)件").font(.caption)
                    Picker("前後", selection: $context) {
                        ForEach([0, 1, 3, 5, 10], id: \.self) { Text("\($0)行").tag($0) }
                    }.frame(width: 115)
                    Toggle("折り返す", isOn: $wrap)
                }
                HStack {
                    TextField("カスタムハイライト（100文字・10個まで）", text: $custom).textFieldStyle(.roundedBorder).onSubmit(addTerm)
                    Button("追加", action: addTerm).disabled(terms.count >= 10 || custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ForEach(terms, id: \.self) { term in Button("\(term) ×") { terms.removeAll { $0 == term } }.lineLimit(1) }
                }
                ScrollViewReader { proxy in
                    HStack {
                        Text("全\(lines.count)行 · \(visible.count)行を表示").font(.caption)
                        Spacer()
                        Text(hits.isEmpty ? "" : "\(min(current, hits.count - 1) + 1) / \(hits.count)").font(.caption)
                        Button("前へ") { move(-1, proxy: proxy) }.disabled(hits.isEmpty)
                        Button("次へ") { move(1, proxy: proxy) }.disabled(hits.isEmpty)
                    }
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(displayed) { line in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(String(line.id)).foregroundStyle(.secondary).frame(width: 48, alignment: .trailing)
                                    Text(highlight(line, selected: selectedHit)).textSelection(.enabled)
                                        .fixedSize(horizontal: !wrap, vertical: true)
                                        .frame(width: wrap ? 680 : nil, alignment: .leading)
                                }.font(.system(.body, design: .monospaced)).id(line.id)
                            }
                            if visible.isEmpty { Text(lines.isEmpty ? "ログを貼り付けて解析してください。" : "選択条件に一致するログはありません。").foregroundStyle(.secondary).padding() }
                        }.padding(8).frame(minWidth: 740, alignment: .leading)
                    }.frame(minHeight: 230)
                }
                Text(status).font(.caption).foregroundStyle(.secondary)
                ToolFootnote(text: "ログは保存・送信しません。検索は表示中の行を対象にし、レベル判定は行内で最も重大なキーワードを優先します。")
            }.padding(20)
        }.frame(minWidth: 1000, minHeight: 710)
        .onChange(of: query) { _, _ in current = 0 }
        .onChange(of: context) { _, _ in current = 0 }
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
