import SwiftUI

struct RegexTesterView: View {
    @State private var pattern = #"([A-Za-z]+)-(\d+)"#
    var body: some View {
        ToolPage("正規表現テスター", subtitle: "パターンを試し、一致箇所・キャプチャ・置換を確認", symbol: "text.magnifyingglass", tint: .indigo) {
            ScrollView { RegexTestPanel(pattern: $pattern).padding(22) }
        }.frame(minWidth: 800, idealWidth: 900, minHeight: 760)
    }
}

private struct RegexRequest: Equatable, Sendable {
    let text: String, pattern: String, replacement: String
    let all: Bool, ignoreCase: Bool, multiline: Bool, dotAll: Bool
}

struct RegexTestPanel: View {
    @Binding var pattern: String
    @State private var input = "item-123\norder-456\n日本語のテスト"
    @State private var replacement = "$1: $2"
    @State private var all = true
    @State private var ignoreCase = false
    @State private var multiline = false
    @State private var dotAll = false
    @State private var output: RegexWorkbench.Output?
    @State private var error = ""
    @State private var busy = false
    @State private var status = ""
    init(pattern: Binding<String>, sampleText: String = "item-123\norder-456\n日本語のテスト") {
        _pattern = pattern; _input = State(initialValue: sampleText)
    }
    private var request: RegexRequest { .init(text: input, pattern: pattern, replacement: replacement, all: all, ignoreCase: ignoreCase, multiline: multiline, dotAll: dotAll) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ToolCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("正規表現").font(.headline)
                        Spacer()
                        Button("パターンをコピー") { copy(pattern) }
                    }
                    TextField("パターン（/…/は付けずに入力）", text: $pattern).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    HStack {
                        Toggle("g すべて検索", isOn: $all); Toggle("i 大文字小文字を無視", isOn: $ignoreCase)
                        Toggle("m 複数行", isOn: $multiline); Toggle("s 改行も含む", isOn: $dotAll)
                    }.font(.caption)
                }
            }
            Text("テスト文字列").font(.headline)
            TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(height: 120).accessibilityLabel("テスト文字列")
            HStack {
                Text(busy ? "確認中…" : "一致：\(output?.matches.count ?? 0)件").font(.headline)
                Spacer()
                Button("クリア") { input = "" }
            }
            if !error.isEmpty { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if let output {
                ToolCard { Text(highlight(output)).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                DisclosureGroup("一致・キャプチャの詳細") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(output.matches.enumerated()), id: \.offset) { index, match in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1)：位置 \(match.range.location)、長さ \(match.range.length)（UTF-16）").font(.caption).foregroundStyle(.secondary)
                                ForEach(match.groups.indices, id: \.self) { group in
                                    Text("$\(group) = \(match.groups[group].map { $0.isEmpty ? "（空文字）" : $0 } ?? "（未一致）")").textSelection(.enabled)
                                }
                            }
                        }
                    }.font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                }
                TextField("置換文字列（$1、$2でキャプチャ参照）", text: $replacement).textFieldStyle(.roundedBorder)
                HStack { Text("置換結果").font(.headline); Spacer(); Button("置換結果をコピー") { copy(output.replacement) } }
                ToolCard { Text(output.replacement.isEmpty ? "（空文字）" : output.replacement).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            } else {
                TextField("置換文字列（$1、$2）", text: $replacement).textFieldStyle(.roundedBorder)
            }
            Text(status).font(.caption).foregroundStyle(.secondary)
            ToolFootnote(text: "ICU正規表現。JavaScriptとは一部構文が異なります。置換はICU形式（$0・$1など）。本文64KiB・一致1,000件まで。端末内で処理し保存しません。")
        }
        .task(id: request) {
            let value = request
            output = nil; error = ""; busy = true; status = ""
            do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
            let worker = Task.detached(priority: .userInitiated) {
                Result { try RegexWorkbench.test(value.text, pattern: value.pattern, replacement: value.replacement, all: value.all, ignoreCase: value.ignoreCase, multiline: value.multiline, dotAll: value.dotAll) }
            }
            let result = await withTaskCancellationHandler(operation: { await worker.value }, onCancel: { worker.cancel() })
            guard !Task.isCancelled else { return }
            busy = false
            switch result { case .success(let value): output = value; case .failure(let failure): error = failure.localizedDescription }
        }
    }
    private func highlight(_ output: RegexWorkbench.Output) -> AttributedString {
        var value = AttributedString(input)
        for match in output.matches where match.range.length > 0 {
            if let range = Range(match.range, in: input), let start = AttributedString.Index(range.lowerBound, within: value), let end = AttributedString.Index(range.upperBound, within: value) {
                value[start..<end].backgroundColor = .yellow.opacity(0.5)
                value[start..<end].foregroundColor = .black
            }
        }
        return value
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(value, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}

struct RegexBuilderView: View {
    @State private var parts: [RegexWorkbench.Part] = []
    @State private var start = true
    @State private var end = true
    @State private var pattern = ""
    @State private var error = ""
    var body: some View {
        ToolPage("正規表現ビルダー", subtitle: "条件を並べて作り、その場でテスト", symbol: "wand.and.stars", tint: .purple) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ToolCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("条件を追加").font(.headline)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))]) {
                                ForEach(RegexWorkbench.PartKind.allCases, id: \.self) { kind in
                                    Button(kind.rawValue) { var part = RegexWorkbench.Part(); part.kind = kind; parts.append(part); update() }.disabled(parts.count >= 40)
                                }
                            }
                            HStack {
                                Text("プリセット")
                                Button("郵便番号") { preset(postal: true) }
                                Button("数字のみ") { preset(postal: false) }
                                Menu("その他") {
                                    ForEach(["英数字のみ", "メール簡易版", "URL簡易版", "IPv4簡易版"], id: \.self) { name in Button(name) { extraPreset(name) } }
                                }
                                Button("リセット") { parts = []; update() }
                            }
                        }
                    }
                    ForEach($parts) { $part in
                        ToolCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(part.kind.rawValue).font(.headline); Spacer()
                                    Button("↑") { move(part.id, -1) }.accessibilityLabel("条件を上へ")
                                    Button("↓") { move(part.id, 1) }.accessibilityLabel("条件を下へ")
                                    Button("削除") { parts.removeAll { $0.id == part.id }; update() }
                                }
                                if [.literal, .characterClass, .group, .either].contains(part.kind) {
                                    TextField(part.kind == .characterClass ? "例：a-zA-Z0-9_-" : "文字列", text: $part.value).textFieldStyle(.roundedBorder).onChange(of: part.value) { _, _ in update() }
                                }
                                if part.kind == .either { TextField("または", text: $part.alternative).textFieldStyle(.roundedBorder).onChange(of: part.alternative) { _, _ in update() } }
                                if part.kind == .characterClass { Toggle("含まない文字", isOn: $part.negate).onChange(of: part.negate) { _, _ in update() } }
                                if part.kind == .group { Toggle("キャプチャする", isOn: $part.capture).onChange(of: part.capture) { _, _ in update() } }
                                HStack {
                                    Picker("繰り返し", selection: $part.repetition) { ForEach(RegexWorkbench.Repetition.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.onChange(of: part.repetition) { _, _ in update() }
                                    if [.exact, .range, .atLeast].contains(part.repetition) {
                                        Stepper("回数 \(part.minimum)", value: $part.minimum, in: 0...1000).onChange(of: part.minimum) { _, _ in part.maximum = max(part.minimum, part.maximum); update() }
                                    }
                                    if part.repetition == .range { Stepper("最大 \(part.maximum)", value: $part.maximum, in: part.minimum...1000).onChange(of: part.maximum) { _, _ in update() } }
                                }
                            }
                        }
                    }
                    HStack { Toggle("先頭から ^", isOn: $start); Toggle("末尾まで $", isOn: $end) }.onChange(of: start) { _, _ in update() }.onChange(of: end) { _, _ in update() }
                    if !error.isEmpty { Text(error).foregroundStyle(.orange) }
                    Text("生成パターン・テスト").font(.title3)
                    RegexTestPanel(pattern: $pattern, sampleText: "123-4567\n1234-567\nabc-1234")
                    ToolFootnote(text: "メール・URL・IPv4は簡易判定（IPv4の0〜255は検証しません）。固定文字・OR・グループの内容は文字としてエスケープ。文字クラスだけはa-zなどの範囲構文を入力します。条件変更でパターンを再生成します。")
                }.padding(22)
            }
        }.frame(minWidth: 850, idealWidth: 950, minHeight: 780).onAppear { if parts.isEmpty { preset(postal: true) } }
    }
    private func update() {
        do { pattern = try RegexWorkbench.build(parts, start: start, end: end); error = "" }
        catch { self.error = error.localizedDescription; pattern = "(?!)" }
    }
    private func move(_ id: UUID, _ delta: Int) {
        guard let index = parts.firstIndex(where: { $0.id == id }), parts.indices.contains(index + delta) else { return }
        parts.swapAt(index, index + delta); update()
    }
    private func extraPreset(_ name: String) {
        func part(_ kind: RegexWorkbench.PartKind, _ value: String = "", _ repetition: RegexWorkbench.Repetition = .one) -> RegexWorkbench.Part {
            var item = RegexWorkbench.Part(); item.kind = kind; item.value = value; item.repetition = repetition; return item
        }
        start = true; end = true
        switch name {
        case "英数字のみ": parts = [part(.alnum, "", .oneMore)]
        case "メール簡易版": parts = [part(.characterClass, #"^\s@"#, .oneMore), part(.literal, "@"), part(.characterClass, #"^\s@"#, .oneMore), part(.literal, "."), part(.characterClass, #"^\s@"#, .oneMore)]
        case "URL簡易版": parts = [part(.literal, "http"), part(.literal, "s", .optional), part(.literal, "://"), part(.nonspace, "", .oneMore)]
        default:
            var digits = part(.digit, "", .range); digits.minimum = 1; digits.maximum = 3
            parts = [digits, part(.literal, "."), digits, part(.literal, "."), digits, part(.literal, "."), digits].map { item in
                var fresh = RegexWorkbench.Part(); fresh.kind = item.kind; fresh.value = item.value; fresh.repetition = item.repetition; fresh.minimum = item.minimum; fresh.maximum = item.maximum; return fresh
            }
        }
        update()
    }
    private func preset(postal: Bool) {
        var digit = RegexWorkbench.Part(); digit.repetition = postal ? .exact : .oneMore; digit.minimum = 3
        if postal {
            var dash = RegexWorkbench.Part(); dash.kind = .literal; dash.value = "-"
            var last = RegexWorkbench.Part(); last.repetition = .exact; last.minimum = 4
            parts = [digit, dash, last]
        } else { parts = [digit] }
        start = true; end = true; update()
    }
}
