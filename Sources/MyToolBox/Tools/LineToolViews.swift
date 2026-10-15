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
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: LineToolModel
    private let tint = Color(red: 0.77, green: 0.48, blue: 0.09)
    var body: some View {
        ToolPage("行ツール", subtitle: "並べる、絞る、重なりを見つける。", symbol: "arrow.up.arrow.down", tint: tint) {
            VStack(spacing: 16) {
                ThemePicker("操作", selection: $model.mode, options: LineToolModel.Mode.allCases.map { ($0, $0.rawValue) }, tabs: true)
                ToolCard { settings }
                HStack(alignment: .top, spacing: 16) {
                    TextPane(title: "入力テキスト", symbol: "text.alignleft", text: $model.input, tint: tint)
                    if model.mode == .duplicates {
                        VStack(alignment: .leading, spacing: 12) {
                            ToolSectionLabel(title: "重複している行", symbol: "doc.on.doc")
                            if model.busy { ProgressView() }
                            else if model.groups.isEmpty { ContentUnavailableView("重複なし", systemImage: "checkmark.circle", description: Text(model.input.isEmpty ? "確認したいテキストを入力してください" : "現在の条件では重複がありません")) }
                            else {
                                ScrollView {
                                    LazyVStack(spacing: 10) {
                                        ForEach(model.groups) { group in
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack(alignment: .top) { Text(group.value.isEmpty ? "（空行）" : group.value).font(theme.font( 12, design: .monospaced)).textSelection(.enabled); Spacer(); Text("\(group.lineNumbers.count) 回").font(theme.font(11, weight: .bold)).foregroundStyle(theme.classic ? theme.accent : tint) }
                                                Text("元の行：" + group.lineNumbers.map(String.init).joined(separator: ", ")).font(theme.font(11)).foregroundStyle(.secondary).textSelection(.enabled)
                                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 10))
                                        }
                                    }
                                }
                            }
                        }.padding(14).frame(maxWidth: .infinity, minHeight: 300, maxHeight: .infinity).background(theme.surfaceHigh.opacity(0.5), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 14))
                    } else { TextPane(title: "処理結果", symbol: "text.badge.checkmark", text: $model.output, editable: false, tint: tint) }
                }.frame(maxHeight: .infinity)
                HStack(spacing: 12) {
                    Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: { Label("貼り付け", systemImage: "doc.on.clipboard") }
                    Button("クリア") { model.input = "" }.disabled(model.input.isEmpty)
                    Button("結果を入力へ") { model.input = model.output }.disabled(model.output.isEmpty || model.busy)
                    if model.busy { ProgressView().controlSize(.small) }
                    Text(model.status.isEmpty ? model.summary : model.status).font(theme.font(11)).foregroundStyle(.secondary)
                    Spacer()
                    Button { model.copy() } label: { Label(model.mode == .duplicates ? "重複行をコピー" : "結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.output.isEmpty || model.busy)
                }
                ToolFootnote(text: "3つの操作で入力を共有します。元の行は変更しません。最大1MiB・20,000行。抽出の行番号と重複位置は元の入力を基準にします。")
            }.padding(24)
        }.frame(minWidth: 1020, minHeight: 780)
        .onChange(of: model.input) { _, _ in model.sort.originalOrder = false; model.update() }.onChange(of: model.mode) { _, _ in model.update() }
        .onChange(of: model.sort) { old, new in
            if old.mode != new.mode || old.descending != new.descending || old.emptyLast != new.emptyLast || old.removeDuplicates != new.removeDuplicates { model.sort.originalOrder = false }
            model.update()
        }.onChange(of: model.filter) { _, _ in model.update() }.onChange(of: model.duplicates) { _, _ in model.update() }.onDisappear { model.stop() }
    }
    @ViewBuilder private var settings: some View {
        switch model.mode {
        case .sort:
            HStack(spacing: 18) {
                ThemePicker("並び順", selection: $model.sort.mode, options: LineTools.SortMode.allCases.map { ($0, $0.rawValue) }).frame(width: 180)
                Toggle("降順", isOn: $model.sort.descending)
                Toggle("空行を末尾へ", isOn: $model.sort.emptyLast)
                Toggle("重複行を削除", isOn: $model.sort.removeDuplicates)
                Spacer()
                Button("元の順番") { model.sort.originalOrder = true }.disabled(model.input.isEmpty)
                if model.sort.originalOrder { Button("並べ替えを再開") { model.sort.originalOrder = false } }
            }.toggleStyle(ThemeToggleStyle())
        case .filter:
            VStack(spacing: 12) {
                HStack { ThemePicker("結合", selection: $model.filter.any, options: [(false, "AND（すべて一致）"), (true, "OR（いずれか一致）")]).frame(width: 245); Toggle("大小文字を無視", isOn: $model.filter.ignoreCase); Toggle("空行を除外", isOn: $model.filter.ignoreEmpty); Toggle("元の行番号", isOn: $model.filter.showNumbers); Spacer(); Button { model.filter.conditions.append(.init()) } label: { Image(systemName: "plus") }.disabled(model.filter.conditions.count >= 100).help("抽出条件を追加") }
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($model.filter.conditions) { $condition in
                            HStack {
                                ThemePicker("条件", selection: $condition.type, options: LineTools.ConditionType.allCases.map { ($0, $0.rawValue) }).labelsHidden().frame(width: 150)
                                TextField("検索文字列", text: $condition.value).textFieldStyle(ThemeTextFieldStyle())
                                Button { model.filter.conditions.removeAll { $0.id == condition.id } } label: { Image(systemName: "minus.circle") }.disabled(model.filter.conditions.count == 1).accessibilityLabel("この条件を削除")
                            }
                        }
                    }
                }.frame(height: min(125, CGFloat(model.filter.conditions.count) * 32))
            }.toggleStyle(ThemeToggleStyle())
        case .duplicates:
            HStack(spacing: 24) { Toggle("空行を除外", isOn: $model.duplicates.ignoreEmpty); Toggle("前後の空白を無視", isOn: $model.duplicates.trim); Toggle("大文字・小文字を無視", isOn: $model.duplicates.ignoreCase); Spacer() }.toggleStyle(ThemeToggleStyle())
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
