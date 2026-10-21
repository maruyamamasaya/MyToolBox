import SwiftUI

struct RegexTesterView: View {
    @State private var pattern: String
    @State private var expanded: Bool
    private let sampleText: String
    private let initialResult: Result<RegexWorkbench.Output, Error>?
    private let initialResultTab: Int
    init(initiallyExpanded: Bool = false, initialResultTab: Int = 0, initialPattern: String = #"([A-Za-z]+)-(\d+)"#,
         sampleText: String = "item-123\norder-456\n日本語のテスト",
         initialResult: Result<RegexWorkbench.Output, Error>? = nil) {
        _pattern = State(initialValue: initialPattern); _expanded = State(initialValue: initiallyExpanded)
        self.sampleText = sampleText; self.initialResult = initialResult; self.initialResultTab = initialResultTab
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("正規表現テスター", systemImage: "text.magnifyingglass").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            RegexTestPanel(pattern: $pattern, sampleText: sampleText, compactUI: true, expanded: expanded, initialResultTab: initialResultTab, initialResult: initialResult)
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 560)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 520, idealHeight: expanded ? 850 : 560)
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
    private let compactUI: Bool
    private let expanded: Bool
    @State private var showsSettings = false
    @State private var resultTab = 0
    init(pattern: Binding<String>, sampleText: String = "item-123\norder-456\n日本語のテスト", compactUI: Bool = false, expanded: Bool = false, initialResultTab: Int = 0,
         initialResult: Result<RegexWorkbench.Output, Error>? = nil) {
        _pattern = pattern; _input = State(initialValue: sampleText)
        self.compactUI = compactUI; self.expanded = expanded
        _resultTab = State(initialValue: initialResultTab)
        if let initialResult {
            switch initialResult {
            case .success(let output): _output = State(initialValue: output)
            case .failure(let error): _error = State(initialValue: error.localizedDescription)
            }
        }
    }
    private var request: RegexRequest { .init(text: input, pattern: pattern, replacement: replacement, all: all, ignoreCase: ignoreCase, multiline: multiline, dotAll: dotAll) }
    private var originalPanel: some View {
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
    }
    var body: some View {
        Group {
            if compactUI { compactPanel } else { originalPanel }
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
    private var compactPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("パターン（/…/不要）", text: $pattern)
                    .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    .accessibilityLabel("正規表現パターン")
                Button { copy(pattern) } label: { Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("パターンをコピー")
                Button { showsSettings.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("検索設定").popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("検索設定").font(.headline)
                            Toggle("g すべて検索", isOn: $all)
                            Toggle("i 大文字小文字を無視", isOn: $ignoreCase)
                            Toggle("m 複数行（^・$）", isOn: $multiline)
                            Toggle("s 改行も含む（.）", isOn: $dotAll)
                            Text("ICU形式。置換は$0・$1など。本文64KiB・式と置換4KiB・一致1,000件・0.25秒まで。端末内で処理し保存しません。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(16).frame(width: 290)
                    }
            }
            HStack {
                Text("テスト文字列").font(.caption)
                Text([all ? "g" : "", ignoreCase ? "i" : "", multiline ? "m" : "", dotAll ? "s" : ""].joined())
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Button { input = "" } label: { Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("本文をクリア")
            }
            TextEditor(text: $input).font(.system(.body, design: .monospaced))
                .frame(height: expanded ? 200 : 105).accessibilityLabel("テスト文字列")
            HStack {
                Text(busy ? "確認中…" : !error.isEmpty ? "入力エラー" : output.map { "一致：\($0.matches.count)件" } ?? "未確認").font(.caption)
                Spacer()
                if resultTab == 2 {
                    Button("コピー", systemImage: "doc.on.doc") { if let output { copy(output.replacement) } }.disabled(output == nil)
                }
            }
            Picker("結果", selection: $resultTab) {
                Text("一致箇所").tag(0); Text("キャプチャ").tag(1); Text("置換").tag(2)
            }.pickerStyle(.segmented)
            if resultTab == 2 {
                TextField("置換文字列（$1・$2）", text: $replacement).textFieldStyle(.roundedBorder).accessibilityLabel("置換文字列")
            }
            GeometryReader { geometry in
              ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 8) {
                    if !error.isEmpty {
                        Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    } else if let output {
                        if resultTab == 0 { Text(highlight(output)).textSelection(.enabled) }
                        else if resultTab == 1 {
                            if output.matches.isEmpty { Text("一致なし") }
                            ForEach(Array(output.matches.enumerated()), id: \.offset) { index, match in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(index + 1)：位置 \(match.range.location)、長さ \(match.range.length)（UTF-16）").foregroundStyle(.secondary)
                                    ForEach(match.groups.indices, id: \.self) { group in
                                        Text("$\(group) = \(match.groups[group].map { $0.isEmpty ? "（空文字）" : $0 } ?? "（未一致）")").textSelection(.enabled)
                                    }
                                }
                            }
                        } else { Text(output.replacement.isEmpty ? "（空文字）" : output.replacement).textSelection(.enabled) }
                    } else { Text(busy ? "確認中…" : "結果がここに表示されます").foregroundStyle(.secondary) }
                }.font(.system(.body, design: .monospaced)).padding(8)
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
              }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
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
    @State private var expanded: Bool
    @State private var tab: Int
    @State private var showsHelp = false
    @State private var status = ""
    init(initiallyExpanded: Bool = false, initialTab: Int = 0, initialParts: [RegexWorkbench.Part]? = nil) {
        _expanded = State(initialValue: initiallyExpanded); _tab = State(initialValue: initialTab)
        var digit = RegexWorkbench.Part(); digit.repetition = .exact; digit.minimum = 3
        var dash = RegexWorkbench.Part(); dash.kind = .literal; dash.value = "-"
        var last = RegexWorkbench.Part(); last.repetition = .exact; last.minimum = 4
        let items = initialParts ?? [digit, dash, last]
        _parts = State(initialValue: items)
        do { _pattern = State(initialValue: try RegexWorkbench.build(items, start: true, end: true)) }
        catch { _pattern = State(initialValue: "(?!)"); _error = State(initialValue: error.localizedDescription) }
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("正規表現ビルダー", systemImage: "wand.and.stars").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("表示", selection: $tab) { Text("条件を編集").tag(0); Text("テスト").tag(1) }.pickerStyle(.segmented)
            ZStack(alignment: .topLeading) {
                editor.opacity(tab == 0 ? 1 : 0).disabled(tab != 0).allowsHitTesting(tab == 0).accessibilityHidden(tab != 0)
                // Keep the test panel mounted so text, replacement and flags survive tab/size changes.
                RegexTestPanel(pattern: $pattern, sampleText: "123-4567\n1234-567\nabc-1234", compactUI: true, expanded: expanded)
                    .opacity(tab == 1 ? 1 : 0).disabled(tab != 1).allowsHitTesting(tab == 1).accessibilityHidden(tab != 1)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.orange).lineLimit(3) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 600)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 560, idealHeight: expanded ? 850 : 600)
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu("条件を追加", systemImage: "plus") {
                    ForEach(RegexWorkbench.PartKind.allCases, id: \.self) { kind in
                        Button(kind.rawValue) { var part = RegexWorkbench.Part(); part.kind = kind; parts.append(part); update() }
                    }
                }.disabled(parts.count >= 40)
                Menu("プリセット") {
                    Button("郵便番号") { preset(postal: true) }
                    Button("数字のみ") { preset(postal: false) }
                    ForEach(["英数字のみ", "メール簡易版", "URL簡易版", "IPv4簡易版"], id: \.self) { name in Button(name) { extraPreset(name) } }
                }
                Spacer(minLength: 0)
                Button { parts = []; update() } label: { Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("条件をリセット")
            }
            HStack {
                Toggle("先頭 ^", isOn: $start); Toggle("末尾 $", isOn: $end)
                Spacer()
                Text("\(parts.count)/40").font(.caption).foregroundStyle(.secondary)
            }.onChange(of: start) { _, _ in update() }.onChange(of: end) { _, _ in update() }
            ScrollView {
                VStack(spacing: 8) {
                    if parts.isEmpty { Text("「条件を追加」から組み立ててください").foregroundStyle(.secondary).padding(.top, 12) }
                    ForEach($parts) { $part in
                        partEditor($part)
                    }
                }.padding(2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Text("生成パターン").font(.caption)
                Spacer()
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("ビルダーの使い方").popover(isPresented: $showsHelp) {
                        Text("固定文字・OR・グループは文字としてエスケープ。文字クラスはa-zなどの範囲構文。条件変更で手修正を含め再生成します。メール・URL・IPv4は簡易判定（IPv4の0〜255は検証しません）。最大40条件・回数0〜1,000。")
                            .font(.caption).padding(16).frame(width: 300)
                    }
                Button { NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(pattern, forType: .string) ? "コピーしました" : "コピーできませんでした" } label: {
                    Image(systemName: "doc.on.doc").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("パターンをコピー").disabled(!error.isEmpty)
            }
            TextField("生成パターン（手修正可）", text: $pattern).textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced)).accessibilityLabel("生成パターン")
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary) }
        }
    }
    private func partEditor(_ binding: Binding<RegexWorkbench.Part>) -> some View {
        let part = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(part.kind.rawValue).font(.headline); Spacer()
                Button { move(part.id, -1) } label: { Image(systemName: "arrow.up").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("条件を上へ").disabled(parts.first?.id == part.id)
                Button { move(part.id, 1) } label: { Image(systemName: "arrow.down").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("条件を下へ").disabled(parts.last?.id == part.id)
                Button { parts.removeAll { $0.id == part.id }; update() } label: { Image(systemName: "xmark").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("条件を削除")
            }
            if [.literal, .characterClass, .group, .either].contains(part.kind) {
                TextField(part.kind == .characterClass ? "例：a-zA-Z0-9_-" : "文字列", text: binding.value).textFieldStyle(.roundedBorder)
                    .accessibilityLabel(part.kind.rawValue + "の文字列").onChange(of: part.value) { _, _ in update() }
            }
            if part.kind == .either {
                TextField("または", text: binding.alternative).textFieldStyle(.roundedBorder).onChange(of: part.alternative) { _, _ in update() }
            }
            if part.kind == .characterClass { Toggle("含まない文字", isOn: binding.negate).onChange(of: part.negate) { _, _ in update() } }
            if part.kind == .group { Toggle("キャプチャする", isOn: binding.capture).onChange(of: part.capture) { _, _ in update() } }
            Picker("繰り返し", selection: binding.repetition) {
                ForEach(RegexWorkbench.Repetition.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.onChange(of: part.repetition) { _, _ in update() }
            if [.exact, .range, .atLeast].contains(part.repetition) {
                Stepper("回数 \(part.minimum)", value: binding.minimum, in: 0...1000)
                    .onChange(of: part.minimum) { _, value in binding.wrappedValue.maximum = max(value, binding.wrappedValue.maximum); update() }
            }
            if part.repetition == .range {
                Stepper("最大 \(part.maximum)", value: binding.maximum, in: part.minimum...1000).onChange(of: part.maximum) { _, _ in update() }
            }
        }.padding(8).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
    }
    private func update() {
        status = ""
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
