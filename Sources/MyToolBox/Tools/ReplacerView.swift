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
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: ReplacerModel
    private let tint = Color(red: 0.89, green: 0.23, blue: 0.27)
    var body: some View {
        ToolPage("検索・置換", subtitle: "探す、書き換える、まとめて整える。", symbol: "text.magnifyingglass", tint: tint) {
            ScrollView {
                VStack(spacing: 16) {
                    ThemePicker("処理モード", selection: $model.options.mode, options: StringReplacer.Mode.allCases.map { ($0, $0.rawValue) }, tabs: true)
                    ToolCard {
                        VStack(alignment: .leading, spacing: 14) {
                            if model.options.mode == .rules {
                                ToolSectionLabel(title: "1行に1ルール（検索 => 置換）", symbol: "list.bullet.rectangle")
                                ToolTextEditor(text: $model.options.rules, label: "置換ルール").frame(height: 95)
                            } else if model.options.mode == .delete && model.options.multipleDelete {
                                ToolSectionLabel(title: "削除する文字列（1行に1件）", symbol: "trash")
                                ToolTextEditor(text: $model.options.deletionList, label: "複数削除する文字列").frame(height: 85)
                            } else {
                                HStack(spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) { ToolSectionLabel(title: "検索する文字列", symbol: "magnifyingglass"); ToolTextEditor(text: $model.options.query, label: "検索する文字列").frame(height: 65).background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8)) }
                                    if model.options.mode == .replace { VStack(alignment: .leading, spacing: 6) { ToolSectionLabel(title: "置換後（空欄も可）", symbol: "arrow.right"); ToolTextEditor(text: $model.options.replacement, label: "置換後の文字列").frame(height: 65).background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8)) } }
                                }
                            }
                            HStack(spacing: 20) {
                                Toggle("大小文字を区別", isOn: $model.options.caseSensitive)
                                Toggle("行全体の完全一致", isOn: $model.options.wholeLine)
                                Toggle("正規表現", isOn: $model.options.regex)
                                Toggle(". が改行にも一致", isOn: $model.options.dotAll)
                                if model.options.mode == .delete { Toggle("複数削除", isOn: $model.options.multipleDelete) }
                                Spacer()
                            }.toggleStyle(ThemeToggleStyle())
                            HStack {
                                Button { model.run() } label: { Label(model.options.mode.rawValue + "を実行", systemImage: "play.fill") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.busy)
                                if model.busy { ProgressView().controlSize(.small); Button("キャンセル") { model.cancel() } }
                                Text(model.valid ? "該当：\(model.count) 件" : model.status).font(theme.font(11)).foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    HStack(spacing: 16) {
                        TextPane(title: "入力テキスト", symbol: "text.alignleft", text: $model.input, tint: tint)
                        TextPane(title: "処理結果", symbol: "text.badge.checkmark", text: $model.output, editable: false, tint: tint)
                    }.frame(height: 280)
                    if model.valid, !model.matches.isEmpty {
                        TextPane(title: "一致箇所（先頭1,000件まで）", symbol: "highlighter", text: .constant(TextToolLimits.normalized(model.input)), editable: false, tint: tint, highlights: model.matches).frame(height: 150)
                    }
                    HStack(spacing: 12) {
                        Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: { Label("貼り付け", systemImage: "doc.on.clipboard") }
                        Button("クリア") { model.input = ""; model.output = ""; model.invalidate() }
                        Button("結果を入力へ") { model.input = model.output }.disabled(!model.valid)
                        Text(model.status).font(theme.font(11)).foregroundStyle(.secondary)
                        Spacer()
                        Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(!model.valid || model.busy)
                    }
                    ToolFootnote(text: "複数ルールは上から順に適用します。正規表現はICU形式、置換は$1〜$99・$&・$$などに対応。入力256KiB、1ルール0.25秒、100ルール上限（通常文字列は1MiB）。変更後は実行ボタンで再計算します。")
                }.padding(24)
            }
        }.frame(minWidth: 1040, minHeight: 860)
        .onChange(of: model.input) { _, _ in model.invalidate() }.onChange(of: model.options) { _, _ in model.invalidate() }.onDisappear { model.stop() }
    }
}
struct ClipboardWorkspaceView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var table: ClipboardFormatterModel
    @ObservedObject var list: ListConverterModel
    @State private var listMode = false
    init(table: ClipboardFormatterModel, list: ListConverterModel, listMode: Bool = false) {
        self.table = table; self.list = list; _listMode = State(initialValue: listMode)
    }
    var body: some View {
        ToolPage("クリップボード整形", subtitle: "表もリストも、必要な形にまとめる。", symbol: "clipboard", tint: .teal) {
            VStack(spacing: 0) {
                HStack {
                    ThemePicker("整形モード", selection: $listMode, options: [(false, "表の整形"), (true, "リスト変換")], tabs: true).frame(width: 340)
                    Spacer()
                    Button(listMode ? "表の入力を引き継ぐ" : "リストの入力を引き継ぐ") {
                        if listMode { list.input = table.input; list.update() } else { table.input = list.input; table.parse() }
                    }.disabled(listMode ? table.input.isEmpty : list.input.isEmpty)
                }.padding(.horizontal, 24).padding(.top, 18)
                if listMode { ListConverterView(model: list) }
                else { ClipboardFormatterView(model: table, embedded: true) }
            }
        }.frame(minWidth: 1040, minHeight: 900)
    }
}
