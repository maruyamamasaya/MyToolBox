import SwiftUI
@MainActor final class ReplacerModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var status = ""
    @Published var options = StringReplacer.Options()
    @Published var matches: [NSRange] = []
    @Published var count = 0
    @Published var busy = false
    @Published var valid = false
    private var task: Task<Void, Never>?
    func invalidate() { task?.cancel(); busy = false; valid = false; output = ""; matches = []; count = 0; status = "" }
    func run() {
        task?.cancel(); busy = true; valid = false; matches = []; status = ""
        let input = input, options = options
        task = Task {
            do {
                let result = try await TextProcessor.shared.replace(input, options: options)
                try Task.checkCancellation(); output = result.output; count = result.count
                matches = result.matches.map { NSRange(location: $0.location, length: $0.length) }
                busy = false; valid = true
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; busy = false; output = ""; count = 0; status = error.localizedDescription }
        }
    }
    func cancel() { task?.cancel(); busy = false; status = "キャンセルしました" }
    func stop() { task?.cancel() }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); status = "コピーしました" }
}
struct ReplacerView: View {
    @ObservedObject var model: ReplacerModel
    @State private var showsSettings = false
    @State private var showsMatches = false
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("検索・置換").font(.headline)
                Spacer()
                Button { showsMatches = true } label: {
                    Image(systemName: "highlighter").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("一致箇所を表示").disabled(!model.valid || model.matches.isEmpty)
                    .popover(isPresented: $showsMatches) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("一致箇所（先頭1,000件）").font(.caption)
                            ToolTextEditor(text: .constant(TextToolLimits.normalized(model.input)), editable: false,
                                label: "一致箇所", highlights: model.matches)
                        }.padding(12).frame(width: 340, height: 300)
                    }
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("検索・置換の条件")
                    .popover(isPresented: $showsSettings) { settings }
            }
            Picker("処理モード", selection: $model.options.mode) {
                ForEach(StringReplacer.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            if model.options.mode == .rules || model.options.mode == .delete && model.options.multipleDelete {
                Button("ルールを設定") { showsSettings = true }
            } else {
                queryRow("検索", text: $model.options.query)
                if model.options.mode == .replace { queryRow("置換", text: $model.options.replacement) }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("入力").font(.caption).foregroundStyle(.secondary)
                ToolTextEditor(text: $model.input, label: "入力テキスト")
                    .frame(minHeight: 60, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("結果").font(.caption).foregroundStyle(.secondary)
                ToolTextEditor(text: $model.output, editable: false, label: "処理結果")
                    .frame(minHeight: 60, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            Text(model.busy ? "処理中…" : model.status.isEmpty && model.valid ? "該当：\(model.count)件" : model.status)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { model.input = ""; model.invalidate() } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("クリア")
                Button { model.input = model.output } label: {
                    Image(systemName: "arrow.up").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("結果を入力へ").disabled(!model.valid || model.busy)
                Spacer(minLength: 0)
                Button { if model.busy { model.cancel() } else { model.run() } } label: {
                    Text(model.busy ? "中止" : "実行").frame(minHeight: 28)
                }.buttonStyle(.borderedProminent)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(!model.valid || model.busy)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 340, idealWidth: 360, minHeight: 400, idealHeight: 440)
            .onChange(of: model.input) { _, _ in model.invalidate() }
            .onChange(of: model.options) { _, _ in model.invalidate() }
            .onDisappear { model.stop() }
    }
    private func queryRow(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).frame(width: 28, alignment: .leading)
            ToolTextEditor(text: text, label: title + "文字列").frame(height: 32)
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("大小文字を区別", isOn: $model.options.caseSensitive)
                Toggle("行全体の完全一致", isOn: $model.options.wholeLine)
                Toggle("正規表現", isOn: $model.options.regex)
                Toggle(". が改行にも一致", isOn: $model.options.dotAll)
                if model.options.mode == .delete { Toggle("複数削除", isOn: $model.options.multipleDelete) }
                if model.options.mode == .rules {
                    Text("1行に1ルール：検索 => 置換").font(.caption)
                    ToolTextEditor(text: $model.options.rules, label: "置換ルール").frame(height: 130)
                } else if model.options.mode == .delete && model.options.multipleDelete {
                    Text("削除する文字列を1行に1件").font(.caption)
                    ToolTextEditor(text: $model.options.deletionList, label: "複数削除する文字列").frame(height: 130)
                }
                ThemeMenu()
                Text("複数ルールは上から順に適用。正規表現はICU、置換は$1〜$99・$&・$$に対応。正規表現の入力256KiB、1ルール0.25秒、最大100ルール。通常文字列は1MiB。変更後は実行で再計算します。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }.frame(width: 320, height: 420)
    }
}
struct ClipboardWorkspaceView: View {
    @ObservedObject var table: ClipboardFormatterModel
    @ObservedObject var list: ListConverterModel
    @State private var listMode: Bool
    @State private var expanded: Bool
    @State private var showsSettings = false
    init(table: ClipboardFormatterModel, list: ListConverterModel, listMode: Bool = false, initiallyExpanded: Bool = false) {
        self.table = table; self.list = list
        _listMode = State(initialValue: listMode); _expanded = State(initialValue: initiallyExpanded)
    }
    private var modeBinding: Binding<Bool> {
        Binding(get: { listMode }, set: { next in table.table.finishEditing(); listMode = next })
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("クリップボード整形").font(.headline)
                Spacer(minLength: 0)
                Button(expanded ? "小さく戻す" : "拡大") { table.table.finishEditing(); expanded.toggle() }
                Button { table.table.finishEditing(); showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("整形の設定")
                    .popover(isPresented: $showsSettings) { settings }
            }
            Picker("整形モード", selection: modeBinding) {
                Text("表の整形").tag(false); Text("リスト変換").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            if listMode {
                let layout = expanded ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
                layout {
                    textArea("リスト入力", text: $list.input)
                    textArea("変換結果", text: $list.output, editable: false)
                }.frame(maxHeight: .infinity)
            } else {
                textArea("元の入力", text: $table.input).frame(height: expanded ? 140 : 80)
                if !table.table.rows.isEmpty {
                    HStack {
                        Text(table.detected).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("セルはダブルクリックで編集").font(.caption2).foregroundStyle(.secondary)
                    }
                    CSVGrid(model: table.table).frame(height: expanded ? 260 : 120).classicBevel(sunken: true)
                }
                textArea("変換結果", text: $table.output, editable: false).frame(maxHeight: .infinity)
            }
            Text(listMode ? (list.busy ? "処理中…" : list.status.isEmpty ? list.summary : list.status) : (table.busy ? "処理中…" : table.status))
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    let text = NSPasteboard.general.string(forType: .string) ?? ""
                    if listMode { list.input = text } else { table.input = text }
                } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { table.table.finishEditing(); if listMode { list.input = "" } else { table.input = "" } } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア")
                Spacer(minLength: 0)
                Button {
                    if listMode { list.update() } else { table.table.finishEditing(); table.updateOutput() }
                } label: { Text("整形").frame(minHeight: 28) }
                    .disabled(listMode ? list.busy : table.busy)
                Button { if listMode { list.copy() } else { table.copy() } } label: {
                    Text("コピー").frame(minHeight: 28)
                }.buttonStyle(.borderedProminent)
                    .disabled(listMode ? list.busy || list.output.isEmpty : table.busy || table.output.isEmpty)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: expanded ? 800 : 340, idealWidth: expanded ? 1100 : 360,
                   minHeight: expanded ? 600 : 480, idealHeight: expanded ? 850 : 520)
            .background(ExpandableToolWindowSizing(expanded: expanded))
            .onChange(of: table.input) { _, _ in table.parse() }
            .onChange(of: table.options) { _, _ in table.updateOutput() }
            .onChange(of: table.columns) { _, _ in table.updateOutput() }
            .onChange(of: list.input) { _, _ in list.update() }
            .onChange(of: list.options) { _, _ in list.update() }
            .onDisappear { table.stop(); list.stop() }
    }
    private func textArea(_ title: String, text: Binding<String>, editable: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ToolTextEditor(text: text, editable: editable, label: title).frame(minHeight: 40, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Button(listMode ? "表の入力を引き継ぐ" : "リストの入力を引き継ぐ") {
                    if listMode { list.input = table.input } else { table.input = list.input }
                }.disabled(listMode ? table.input.isEmpty : list.input.isEmpty)
                if listMode {
                    Picker("入力の区切り", selection: $list.options.input) {
                        ForEach(ListConverter.Input.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("変換形式", selection: $list.options.format) {
                        ForEach(ListConverter.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("順序", selection: $list.options.order) {
                        ForEach(ListConverter.Order.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if list.options.input == .custom { settingField("区切り", text: $list.options.separator) }
                    settingField("前の文字", text: $list.options.prefix)
                    settingField("後の文字", text: $list.options.suffix)
                    Toggle("前後の空白を削除", isOn: $list.options.trim)
                    Toggle("空項目を削除", isOn: $list.options.removeEmpty)
                    Toggle("重複を削除", isOn: $list.options.deduplicate)
                    Text("自動判定は改行→タブ→カンマ→セミコロン。空白は残します。JSONは文字列配列、ダブルクォートはJSON式です。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Picker("出力形式", selection: $table.options.format) {
                        ForEach(ClipboardTable.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("囲み文字", selection: $table.options.quote) {
                        ForEach(ClipboardTable.Quote.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.disabled([.markdown, .sqlIn, .sqlValues].contains(table.options.format))
                    Toggle("前後の空白を削除", isOn: $table.options.trim)
                    Toggle("空行を削除", isOn: $table.options.removeEmpty)
                    Toggle("重複行を削除", isOn: $table.options.removeDuplicates)
                    Toggle("連続スペースを1つに", isOn: $table.options.collapseSpaces)
                    if table.table.width > 0 {
                        Text("出力する列").font(.caption)
                        ForEach(0..<table.table.width, id: \.self) { column in
                            Toggle("列 \(column + 1)", isOn: Binding(get: { table.columns.contains(column) }, set: {
                                if $0 { table.columns.insert(column) } else { table.columns.remove(column) }
                            }))
                        }
                    }
                    Text("タブ→カンマ→スペース→1列で自動判定。SQLは文字列生成のみ。囲みなしのカンマはCSVの自動エスケープなし。入力は最大1MiB。列は元の順を維持します。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ThemeMenu()
            }.padding(12)
        }.frame(width: 320, height: 420)
    }
    private func settingField(_ title: String, text: Binding<String>) -> some View {
        HStack { Text(title).font(.caption); TextField(title, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(title) }
    }
}
