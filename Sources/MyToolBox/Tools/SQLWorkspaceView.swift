import SwiftUI

@MainActor final class SQLWorkspaceModel: ObservableObject {
    enum Mode: String, CaseIterable { case format = "整形", explain = "説明", playground = "実行" }
    @Published var mode = Mode.format
    @Published var input = SQLMemoryDatabase.sampleQuery
    @Published var uppercase = true
    @Published var output = ""
    @Published var explanations: [SQLText.Explanation] = []
    @Published var results: [SQLResult] = []
    @Published var schema: [SQLResult] = []
    @Published var error = ""
    @Published var status = ""
    @Published var busy = false
    private let worker = SQLPlaygroundWorker()
    private var task: Task<Void, Never>?
    private var revision = 0

    func run() {
        guard !busy else { return }
        busy = true; error = ""; status = ""
        let source = input, operation = mode, upper = uppercase, generation = revision
        task = Task {
            do {
                switch operation {
                case .format:
                    let value = try await Task.detached { try SQLText.format(source, uppercase: upper) }.value
                    guard !Task.isCancelled, generation == revision else { return }
                    output = value; status = "整形しました"
                case .explain:
                    let value = try await Task.detached { try SQLText.explain(source) }.value
                    guard !Task.isCancelled, generation == revision else { return }
                    explanations = value; status = "句ごとの説明を表示しました"
                case .playground:
                    let value = try await worker.execute(source)
                    guard !Task.isCancelled, generation == revision else { return }
                    results = value.results; schema = value.schema; status = "\(results.count)文を実行しました"
                }
            } catch {
                guard !Task.isCancelled, generation == revision else { return }
                self.error = error.localizedDescription
                if operation == .format { output = "" }
                if operation == .explain { explanations = [] }
                if operation == .playground { results = [] }
            }
            if generation == revision { busy = false }
        }
    }
    func invalidate() {
        revision += 1; task?.cancel(); task = nil; busy = false
        output = ""; explanations = []; results = []; error = ""; status = ""
    }
    func reset() {
        guard !busy else { return }
        busy = true; error = ""
        let generation = revision
        task = Task {
            do {
                let value = try await worker.reset()
                guard !Task.isCancelled, generation == revision else { return }
                schema = value; results = []; status = "一時DBをサンプルに戻しました"
            } catch { if generation == revision { self.error = error.localizedDescription } }
            if generation == revision { busy = false }
        }
    }
    func stop() { invalidate(); Task { await worker.close() } }
    var copyText: String {
        switch mode {
        case .format: return output
        case .explain: return explanations.map { "\($0.title)\n\($0.source)\n\($0.meaning)" }.joined(separator: "\n\n")
        case .playground:
            return results.filter { !$0.columns.isEmpty }.map { result in
                CSVDocument.serialize( [result.columns] + result.rows.map { $0.map { $0 ?? "NULL" } })
            }.joined(separator: "\n\n")
        }
    }
    func copy() {
        NSPasteboard.general.clearContents()
        status = NSPasteboard.general.setString(copyText, forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
}

struct SQLWorkspaceView: View {
    @ObservedObject var model: SQLWorkspaceModel
    @State private var confirmingReset = false
    @State private var expanded: Bool
    @State private var showsSettings = false
    init(model: SQLWorkspaceModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("SQLツール", systemImage: "cylinder.split.1x2").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            Picker("操作", selection: $model.mode) {
                ForEach(SQLWorkspaceModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).disabled(model.busy)
            HStack {
                Text("SQL入力").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { model.input = SQLMemoryDatabase.sampleQuery } label: {
                    Image(systemName: "doc.text").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("サンプル入力").disabled(model.busy)
                Button { model.input = "" } label: {
                    Image(systemName: "trash").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア").disabled(model.busy)
                Button { showsSettings.toggle() } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("SQLの設定・テーブル構成").popover(isPresented: $showsSettings) { settings }
            }
            TextEditor(text: $model.input).font(.system(.body, design: .monospaced)).frame(height: expanded ? 240 : 150)
                .accessibilityLabel("SQL入力").disabled(model.busy)
            HStack {
                Text(model.busy ? "処理中…" : model.status.isEmpty ? "結果" : model.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            if !model.error.isEmpty { Text(model.error).font(.caption).foregroundStyle(.red).textSelection(.enabled).lineLimit(4) }
            results.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button(model.mode == .format ? "整形する" : model.mode == .explain ? "説明する" : "SQLを実行") { model.run() }
                    .keyboardShortcut(.return, modifiers: .command).disabled(model.busy)
                Spacer()
                Button(model.mode == .playground ? "CSVコピー" : "コピー", systemImage: "doc.on.doc") { model.copy() }
                    .disabled(model.busy || model.copyText.isEmpty)
            }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 400, height: 600)))
            .frame(minWidth: expanded ? 800 : 380, idealWidth: expanded ? 1100 : 400,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
        .onAppear { if model.schema.isEmpty { model.reset() } }
        .onChange(of: model.mode) { _, _ in model.error = ""; model.status = "" }
        .onChange(of: model.input) { _, _ in model.invalidate() }
        .onChange(of: model.uppercase) { _, _ in model.invalidate() }
        .confirmationDialog("一時DBの変更を破棄してサンプルに戻しますか？", isPresented: $confirmingReset) {
            Button("初期化", role: .destructive) { model.reset() }
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("SQLの設定・使い方").font(.headline)
                if model.mode == .format {
                    Picker("キーワード", selection: $model.uppercase) {
                        Text("大文字").tag(true); Text("小文字").tag(false)
                    }.disabled(model.busy)
                }
                Text(note).font(.caption).foregroundStyle(.secondary)
                if model.mode == .playground {
                    Divider()
                    Text("テーブル構成").font(.headline)
                    ForEach(Array(model.schema.enumerated()), id: \.offset) { _, result in
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { _, row in
                            Text(row.compactMap { $0 }.joined(separator: "\n")).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    Button("DBを初期化") { showsSettings = false; confirmingReset = true }.disabled(model.busy)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }.frame(width: 330, height: model.mode == .playground ? 400 : 200)
    }
    @ViewBuilder private var results: some View {
        switch model.mode {
        case .format:
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    Text(model.output.isEmpty ? "整形結果がここに表示されます。" : model.output)
                        .font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(8)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        case .explain:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(model.explanations.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title).font(.headline)
                            Text(section.source).font(.system(.body, design: .monospaced))
                            Text(section.meaning).font(.callout).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6)).textSelection(.enabled)
                    }
                    if model.explanations.isEmpty { Text("基本的なSELECT文を句ごとに説明します。").foregroundStyle(.secondary) }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
        case .playground:
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(model.results.enumerated()), id: \.offset) { index, result in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(index + 1)文目 · \(result.columns.isEmpty ? "変更 \(result.changes)行" : "表示 \(result.rows.count)行")").font(.headline)
                                if result.truncated { Text("先頭500行のみ表示しています。LIMITで絞り込めます。").foregroundStyle(.orange) }
                                if !result.columns.isEmpty {
                                    HStack(alignment: .top, spacing: 1) {
                                        ForEach(result.columns.indices, id: \.self) { column in
                                            VStack(alignment: .leading, spacing: 0) {
                                                Text(result.columns[column]).fontWeight(.bold).padding(7)
                                                    .frame(width: expanded ? 175 : 145, alignment: .leading).background(.quaternary)
                                                ForEach(result.rows.indices, id: \.self) { row in
                                                    Text(result.rows[row][column] ?? "NULL")
                                                        .foregroundStyle(result.rows[row][column] == nil ? .secondary : .primary)
                                                        .lineLimit(1).help(result.rows[row][column] ?? "NULL")
                                                        .padding(7).frame(width: expanded ? 175 : 145, height: 32, alignment: .leading)
                                                        .background(row.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear)
                                                }
                                            }
                                        }
                                    }.font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                }
                            }
                        }
                        if model.results.isEmpty { Text("SQLでテーブル作成・追加・更新・検索を試せます。").foregroundStyle(.secondary) }
                    }.padding(8).frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
    }
    private var note: String {
        switch model.mode {
        case .format: return "基本的なSQLの簡易整形です。引用符・コメントを保持します。構文検証や全方言への対応は行いません。最大200 KB。"
        case .explain: return "単一SELECTの構造に基づく定型説明です。構文検証・実行計画・AIによる解析ではありません。WITH・サブクエリ・集合演算・ウィンドウ関数は未対応。"
        case .playground: return "SQLite専用・メモリ内のみ。画面を閉じると破棄します。最大20文／2秒、各結果は先頭500行。エラー時は今回の変更を取り消します。外部DB接続・ファイル操作・明示トランザクションは非対応。"
        }
    }
}
