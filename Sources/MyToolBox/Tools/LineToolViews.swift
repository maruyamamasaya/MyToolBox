import SwiftUI

extension TextProcessor {
    func sortLines(_ input: String, options: LineTools.SortOptions) throws -> [String] { try Task.checkCancellation(); return try LineTools.sort(input, options: options) }
    func filterLines(_ input: String, options: LineTools.FilterOptions) throws -> LineTools.FilterResult { try Task.checkCancellation(); return try LineTools.filter(input, options: options) }
    func duplicates(_ input: String, options: LineTools.DuplicateOptions) throws -> LineTools.DuplicateResult { try Task.checkCancellation(); return try LineTools.duplicates(input, options: options) }
    func replace(_ input: String, options: StringReplacer.Options) throws -> StringReplacer.Result { try Task.checkCancellation(); return try StringReplacer.run(input, options: options) }
    func list(_ input: String, options: ListConverter.Options) throws -> ListConverter.Result { try Task.checkCancellation(); return try ListConverter.convert(input, options: options) }
}
@MainActor final class LineToolModel: ObservableObject {
    enum Mode: String, CaseIterable { case sort = "並べ替え", filter = "行抽出", duplicates = "重複確認" }
    @Published var mode: Mode = .sort
    @Published var input = ""
    @Published var output = ""
    @Published var status = ""
    @Published var summary = ""
    @Published var busy = false
    @Published var sort = LineTools.SortOptions()
    @Published var filter = LineTools.FilterOptions()
    @Published var duplicates = LineTools.DuplicateOptions()
    @Published var groups: [LineTools.DuplicateGroup] = []
    private var task: Task<Void, Never>?
    func update() {
        task?.cancel(); busy = true; status = ""
        let mode = mode, source = input, sort = sort, filter = filter, duplicates = duplicates
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                switch mode {
                case .sort:
                    let result = try await TextProcessor.shared.sortLines(source, options: sort)
                    try Task.checkCancellation(); output = result.joined(separator: "\n"); summary = "\(result.count) 行"; groups = []
                case .filter:
                    let result = try await TextProcessor.shared.filterLines(source, options: filter)
                    try Task.checkCancellation(); output = result.output; summary = "\(result.total) 行中 \(result.count) 行が一致"; groups = []
                case .duplicates:
                    let result = try await TextProcessor.shared.duplicates(source, options: duplicates)
                    try Task.checkCancellation(); output = result.output; groups = result.groups
                    summary = "対象 \(result.total) / ユニーク \(result.unique) / 重複 \(result.groups.count) 種 / 余分 \(result.extra) 行"
                }
                busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; busy = false; output = ""; groups = []; summary = ""; status = error.localizedDescription }
        }
    }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); status = "コピーしました" }
    func stop() { task?.cancel() }
}
struct LineToolsView: View {
    @ObservedObject var model: LineToolModel
    @State private var showsSettings = false
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("行ツール").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("行の処理条件")
                    .popover(isPresented: $showsSettings) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                settings
                                ThemeMenu()
                                Text("3操作で入力を共有します。最大1MiB・20,000行。抽出の行番号と重複位置は元の入力が基準です。入力・条件の変更で自動処理します。")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(12)
                        }.frame(width: 320, height: model.mode == .filter ? 420 : 300)
                    }
            }
            Picker("操作", selection: $model.mode) {
                ForEach(LineToolModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            TextEditor(text: $model.input).font(.system(.body, design: .monospaced))
                .frame(minHeight: 55, maxHeight: .infinity).accessibilityLabel("入力テキスト")
            ScrollView {
                if model.mode == .duplicates && !model.busy {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if model.groups.isEmpty {
                            Text(model.input.isEmpty ? "確認したいテキストを入力してください" : "現在の条件では重複がありません")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(model.groups) { group in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .top) {
                                    Text(group.value.isEmpty ? "（空行）" : group.value)
                                        .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                    Text("\(group.lineNumbers.count)回").font(.caption).foregroundStyle(.secondary)
                                }
                                Text("元の行：" + group.lineNumbers.map(String.init).joined(separator: ", "))
                                    .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                                Divider()
                            }
                        }
                    }.padding(8)
                } else {
                    Text(model.busy ? "処理中…" : model.output.isEmpty ? "処理結果" : model.output)
                        .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }.frame(maxWidth: .infinity, minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("処理結果")
            Text(model.busy ? "処理中…" : model.status.isEmpty ? model.summary : model.status)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { model.input = "" } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア").disabled(model.input.isEmpty)
                Button { model.input = model.output } label: {
                    Image(systemName: "arrow.up").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("結果を入力へ").disabled(model.output.isEmpty || model.busy)
                Spacer(minLength: 0)
                Button { model.update() } label: { Text("実行").frame(minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .accessibilityLabel(model.mode == .duplicates ? "重複行をコピー" : "結果をコピー")
                    .disabled(model.output.isEmpty || model.busy)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 340, idealWidth: 360, minHeight: 360, idealHeight: 400)
        .onChange(of: model.input) { _, _ in model.sort.originalOrder = false; model.update() }.onChange(of: model.mode) { _, _ in model.update() }
        .onChange(of: model.sort) { old, new in
            if old.mode != new.mode || old.descending != new.descending || old.emptyLast != new.emptyLast || old.removeDuplicates != new.removeDuplicates { model.sort.originalOrder = false }
            model.update()
        }.onChange(of: model.filter) { _, _ in model.update() }.onChange(of: model.duplicates) { _, _ in model.update() }.onDisappear { model.stop() }
    }
    @ViewBuilder private var settings: some View {
        switch model.mode {
        case .sort:
            VStack(alignment: .leading, spacing: 10) {
                Picker("並び順", selection: $model.sort.mode) {
                    ForEach(LineTools.SortMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("降順", isOn: $model.sort.descending)
                Toggle("空行を末尾へ", isOn: $model.sort.emptyLast)
                Toggle("重複行を削除", isOn: $model.sort.removeDuplicates)
                Button("元の順番") { model.sort.originalOrder = true }.disabled(model.input.isEmpty)
                if model.sort.originalOrder { Button("並べ替えを再開") { model.sort.originalOrder = false } }
            }
        case .filter:
            VStack(alignment: .leading, spacing: 10) {
                Picker("結合", selection: $model.filter.any) {
                    Text("AND（すべて一致）").tag(false); Text("OR（いずれか一致）").tag(true)
                }
                Toggle("大小文字を無視", isOn: $model.filter.ignoreCase)
                Toggle("空行を除外", isOn: $model.filter.ignoreEmpty)
                Toggle("元の行番号", isOn: $model.filter.showNumbers)
                Button("条件を追加", systemImage: "plus") { model.filter.conditions.append(.init()) }
                    .disabled(model.filter.conditions.count >= 100)
                ForEach($model.filter.conditions) { $condition in
                    VStack(spacing: 6) {
                        HStack {
                            Picker("条件", selection: $condition.type) {
                                ForEach(LineTools.ConditionType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                            }.labelsHidden()
                            Button { model.filter.conditions.removeAll { $0.id == condition.id } } label: {
                                Image(systemName: "minus.circle").frame(width: 28, height: 28)
                            }.disabled(model.filter.conditions.count == 1).accessibilityLabel("この条件を削除")
                        }
                        TextField("検索文字列", text: $condition.value).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("検索文字列")
                    }
                }
            }
        case .duplicates:
            VStack(alignment: .leading, spacing: 10) {
                Toggle("空行を除外", isOn: $model.duplicates.ignoreEmpty)
                Toggle("前後の空白を無視", isOn: $model.duplicates.trim)
                Toggle("大文字・小文字を無視", isOn: $model.duplicates.ignoreCase)
            }
        }
    }
}

@MainActor final class ListConverterModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var status = ""
    @Published var summary = ""
    @Published var options = ListConverter.Options()
    @Published var busy = false
    private var task: Task<Void, Never>?
    func update() {
        task?.cancel(); busy = true; status = ""
        let input = input, options = options
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                let result = try await TextProcessor.shared.list(input, options: options)
                try Task.checkCancellation(); output = result.output; summary = "\(result.inputCount) → \(result.count) 件"; busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; busy = false; output = ""; status = error.localizedDescription }
        }
    }
    func stop() { task?.cancel() }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); status = "コピーしました" }
}
struct ListConverterView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: ListConverterModel
    private let tint = Color.teal
    var body: some View {
        VStack(spacing: 16) {
            ToolCard {
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        ThemePicker("入力の区切り", selection: $model.options.input, options: ListConverter.Input.allCases.map { ($0, $0.rawValue) })
                        ThemePicker("変換形式", selection: $model.options.format, options: ListConverter.Format.allCases.map { ($0, $0.rawValue) })
                        ThemePicker("順序", selection: $model.options.order, options: ListConverter.Order.allCases.map { ($0, $0.rawValue) })
                    }
                    HStack { if model.options.input == .custom { TextField("カスタム区切り", text: $model.options.separator) }; TextField("前に付ける文字", text: $model.options.prefix); TextField("後ろに付ける文字", text: $model.options.suffix) }.textFieldStyle(ThemeTextFieldStyle())
                    HStack(spacing: 22) { Toggle("前後の空白を削除", isOn: $model.options.trim); Toggle("空項目を削除", isOn: $model.options.removeEmpty); Toggle("重複を削除", isOn: $model.options.deduplicate); Spacer() }.toggleStyle(ThemeToggleStyle())
                }
            }
            HStack(spacing: 16) { TextPane(title: "リストの入力", symbol: "list.bullet", text: $model.input, tint: tint); TextPane(title: "変換結果", symbol: "text.badge.checkmark", text: $model.output, editable: false, tint: tint) }
            HStack {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: { Label("貼り付け", systemImage: "doc.on.clipboard") }
                Button("クリア") { model.input = "" }.disabled(model.input.isEmpty)
                if model.busy { ProgressView().controlSize(.small) }
                Text(model.status.isEmpty ? model.summary : model.status).font(theme.font(11)).foregroundStyle(.secondary)
                Spacer()
                Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.busy || model.output.isEmpty)
            }
            ToolFootnote(text: "自動判定は改行→タブ→カンマ→セミコロン。文章中の空白は残します。JSON配列は文字列のみ。ダブルクォートはJSON式で、CSVの引用形式とは異なります。")
        }.padding(24).onChange(of: model.input) { _, _ in model.update() }.onChange(of: model.options) { _, _ in model.update() }.onAppear { model.update() }.onDisappear { model.stop() }
    }
}
