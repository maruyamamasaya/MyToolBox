import SwiftUI
import UniformTypeIdentifiers

struct TableBuilderView: View {
    @StateObject private var table: CSVModel
    @StateObject private var fileWindow = TableFileWindowHandle()
    @State private var filePanelActive = false
    @State private var input = ""
    @State private var tabSeparated = false
    @State private var header = true
    @State private var format: SmallDataTools.Format = .markdown
    @State private var alignment: SmallDataTools.Alignment = .left
    @State private var status = ""
    private var output: String { SmallDataTools.export(table.rows, format: format, header: header, alignment: alignment) }
    @State private var expanded: Bool
    @State private var showsSettings = false
    @State private var showsImport = false
    init(model: CSVModel? = nil, initiallyExpanded: Bool = false, initialFormat: SmallDataTools.Format = .markdown) {
        let actual = model ?? CSVModel(editable: true)
        if model == nil { actual.rows = [["項目", "数量", "メモ"], ["りんご", "3", "青森"], ["みかん", "5", "愛媛"]] }
        _table = StateObject(wrappedValue: actual)
        _expanded = State(initialValue: initiallyExpanded); _format = State(initialValue: initialFormat)
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("表ビルダー", systemImage: "tablecells").font(.headline)
                Spacer()
                Button { table.finishEditing(); expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }.disabled(filePanelActive)
                ThemeMenu()
            }
            HStack(spacing: 8) {
                Button(action: openCSV) { Image(systemName: "folder").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("CSVファイルを開く").disabled(filePanelActive)
                Button { table.finishEditing(); showsImport.toggle() } label: {
                    Image(systemName: "square.and.arrow.down").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("テキストを取り込む").popover(isPresented: $showsImport) { importPanel }
                Menu {
                    Button("サンプル") { replace(sample) }
                    Button("クリア") { replace([["", ""], ["", ""]]) }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24).contentShape(Rectangle()) }
                    .accessibilityLabel("表のサンプル・クリア")
                Spacer(minLength: 0)
                Text("\(table.rows.count)行 × \(table.width)列").font(.caption).foregroundStyle(.secondary)
                Button { table.finishEditing(); showsSettings.toggle() } label: {
                    Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24).contentShape(Rectangle())
                }.accessibilityLabel("表の設定・行列削除").popover(isPresented: $showsSettings) { settings }
            }
            Text("セルをダブルクリックして編集").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            CSVGrid(model: table).frame(minHeight: 150, maxHeight: .infinity)
            HStack {
                Button("行を追加", systemImage: "plus") {
                    table.finishEditing(); table.rows.append(Array(repeating: "", count: max(1, table.width))); table.dirty = true
                }.disabled(table.rows.count >= 100)
                Button("列を追加", systemImage: "plus") {
                    table.finishEditing(); for index in table.rows.indices { table.rows[index].append("") }; table.dirty = true
                }.disabled(table.width >= 30 || table.rows.isEmpty)
                Spacer(minLength: 0)
            }
            Picker("出力形式", selection: $format) {
                ForEach(SmallDataTools.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).onChange(of: format) { _, _ in table.finishEditing() }
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Text(output).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(8)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }.frame(height: expanded ? 220 : 110).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("コピー", systemImage: "doc.on.doc") {
                    table.finishEditing(); NSPasteboard.general.clearContents()
                    status = NSPasteboard.general.setString(output, forType: .string) ? "コピーしました" : "コピーできませんでした"
                }
                Button("保存…", systemImage: "square.and.arrow.down", action: save).disabled(filePanelActive)
                Spacer(minLength: 0)
            }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading) }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: expanded ? 800 : 400, idealWidth: expanded ? 1100 : 420,
                   minHeight: expanded ? 600 : 540, idealHeight: expanded ? 850 : 600)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 420, height: 600)))
            .background(TableFileWindowBridge(handle: fileWindow).frame(width: 0, height: 0))
    }
    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("テキストを取り込む").font(.headline)
            TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(height: 140).accessibilityLabel("表の取り込み")
            HStack {
                Toggle("タブ区切り", isOn: $tabSeparated)
                Spacer()
                Button("取り込む") { load() }
            }
            Text("CSV・TSV、512KiB・100行・30列まで。取り込みは現在の表を置き換えます。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(width: 330)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("表の設定").font(.headline)
            Toggle("1行目を見出しにする", isOn: $header)
            Picker("文字揃え", selection: $alignment) {
                ForEach(SmallDataTools.Alignment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Divider()
            HStack {
                Picker("行", selection: $table.selectedRow) {
                    Text("選択").tag(-1)
                    ForEach(table.rows.indices, id: \.self) { Text("\($0 + 1)").tag($0) }
                }
                Button("行を削除") {
                    table.finishEditing(); guard table.rows.indices.contains(table.selectedRow) else { return }
                    table.rows.remove(at: table.selectedRow); table.selectedRow = -1; table.dirty = true
                }.disabled(table.rows.count <= 1 || !table.rows.indices.contains(table.selectedRow))
            }
            HStack {
                Picker("列", selection: $table.selectedColumn) {
                    ForEach(0..<table.width, id: \.self) { Text("\($0 + 1)").tag($0) }
                }
                Button("列を削除") {
                    table.finishEditing(); guard (0..<table.width).contains(table.selectedColumn) else { return }
                    for index in table.rows.indices { table.rows[index].remove(at: table.selectedColumn) }
                    table.selectedColumn = 0; table.dirty = true
                }.disabled(table.width <= 1)
            }
            Text("最大100行・30列。再編集にはCSVで保存してください。自動保存はしません。見出し・文字揃えはCSV出力には影響しません。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(width: 310)
    }
    private var sample: [[String]] { [["項目", "数量", "メモ"], ["りんご", "3", "青森"], ["みかん", "5", "愛媛"]] }
    @discardableResult private func replace(_ rows: [[String]]) -> Bool {
        table.finishEditing()
        guard !table.dirty || table.confirmReplace() else { return false }
        table.rows = rows; table.selectedRow = -1; table.selectedColumn = 0; table.dirty = true; status = ""
        return true
    }
    private func load() {
        do {
            let rows = try SmallDataTools.parse(input, delimiter: tabSeparated ? "\t" : ",")
            guard rows.count <= 100 else { throw ToolFailure.message("表ビルダーは100行までです。") }
            if replace(rows) { showsImport = false }
        } catch { status = error.localizedDescription }
    }
    private func openCSV() {
        guard !filePanelActive else { return }
        guard let window = fileWindow.window else { status = "表のウィンドウが見つかりません。開き直してください。"; return }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nil)
        let panel = NSOpenPanel()
        panel.title = "表のCSVを開く"
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        filePanelActive = true
        panel.beginSheetModal(for: window) { response in
            filePanelActive = false
            guard response == .OK, let url = panel.url else { status = "読み込みをキャンセルしました"; return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                guard size <= 524_288 else { throw ToolFailure.message("512KiB以下のCSVを選んでください。") }
                let rows = try SmallDataTools.tableCSV(Data(contentsOf: url))
                if replace(rows) {
                    table.dirty = false; status = "読み込みました：" + url.lastPathComponent
                }
            } catch { status = error.localizedDescription }
        }
    }
    private func save() {
        guard !filePanelActive else { return }
        guard let window = fileWindow.window else { status = "表のウィンドウが見つかりません。開き直してください。"; return }
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(nil)
        table.finishEditing()
        let contents = output
        guard format != .csv || contents.utf8.count <= 524_288 else {
            status = "CSVは再読み込み可能な512KiB以内にしてください。"; return
        }
        let panel = NSSavePanel()
        let ext = format == .markdown ? "md" : format == .html ? "html" : "csv"
        panel.title = "表を保存"
        panel.nameFieldStringValue = "table." + ext
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .plainText]
        filePanelActive = true
        panel.beginSheetModal(for: window) { response in
            filePanelActive = false
            guard response == .OK, let url = panel.url else { status = "保存をキャンセルしました"; return }
            do {
                try contents.write(to: url, atomically: true, encoding: .utf8)
                table.dirty = false; status = "保存しました：" + url.lastPathComponent
            } catch { status = error.localizedDescription }
        }
    }
}

@MainActor private final class TableFileWindowHandle: ObservableObject {
    weak var window: NSWindow?
}
private struct TableFileWindowBridge: NSViewRepresentable {
    let handle: TableFileWindowHandle
    final class Host: NSView {
        var attach: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); attach?(window) }
    }
    func makeNSView(context: Context) -> Host { Host() }
    func updateNSView(_ view: Host, context: Context) {
        view.attach = { handle.window = $0 }
        handle.window = view.window
    }
}

struct CSVStatisticsView: View {
    @State private var input = ""
    @State private var nullTokens = "NULL, N/A, NA"
    @State private var header = true
    @State private var tabSeparated = false
    @State private var result: SmallDataTools.Statistics?
    @State private var error = ""
    @State private var status = ""
    @State private var busy = false
    init(sample: Bool = false) {
        _input = State(initialValue: sample ? "名前,数量,金額\nりんご,3,450\nみかん,5,500\nぶどう,NULL,800\nみかん,5,500" : "")
    }
    private var request: StatisticsRequest { .init(input: input, nullTokens: nullTokens, header: header, tabSeparated: tabSeparated) }
    var body: some View {
        ToolPage("CSV統計", subtitle: "貼り付けて、欠損・重複・列の傾向をすばやく確認", symbol: "chart.bar.xaxis", tint: .cyan) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button("CSVファイルを開く…", action: open)
                        Button("サンプル") { input = "名前,数量,金額\nりんご,3,450\nみかん,5,500\nぶどう,NULL,800\nみかん,5,500" }
                        Button("クリア") { input = ""; status = "" }
                        Spacer()
                        Button("統計結果をコピー") { copy() }.disabled(result == nil)
                    }
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).frame(height: 150).accessibilityLabel("統計対象のCSV")
                    HStack {
                        Toggle("1行目は見出し", isOn: $header)
                        Toggle("タブ区切り", isOn: $tabSeparated)
                        TextField("NULL扱いの値（カンマ区切り）", text: $nullTokens).textFieldStyle(.roundedBorder).accessibilityLabel("NULL扱いの値")
                    }
                    Text("空欄は常にNULL扱い。前後の空白を除去し、NULL指定は大文字小文字を区別しません。").font(.caption).foregroundStyle(.secondary)
                    if busy { ProgressView("集計中…") }
                    if !error.isEmpty { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    if let result {
                        ToolCard {
                            HStack(spacing: 30) {
                                metric("データ行", result.rows); metric("列", result.columns.count); metric("NULLセル", result.nulls); metric("重複行", result.duplicates)
                            }
                        }
                        ForEach(result.columns.indices, id: \.self) { index in
                            let column = result.columns[index]
                            ToolCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack { Text(column.name.isEmpty ? "列\(index + 1)（見出し空欄）" : column.name).font(.headline); Text(column.type).font(.caption).foregroundStyle(.secondary) }
                                    Text("値 \(column.count)件 · NULL \(column.nulls)件（\(rate(column.nulls, result.rows))） · ユニーク \(column.unique)件（\(rate(column.unique, column.count))）")
                                    Text("最頻値：" + (column.mode ?? "—")).textSelection(.enabled)
                                    if column.mean != nil {
                                        Text("合計 \(number(column.sum))　平均 \(number(column.mean))　中央値 \(number(column.median))")
                                        Text("最小 \(number(column.minimum))　最大 \(number(column.maximum))")
                                    }
                                }.textSelection(.enabled)
                            }
                        }
                    }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                    ToolFootnote(text: "最大512KiB・1,000データ行・30列。数値集計はNULL以外がすべて有限の数値である列が対象。重複は先頭を除く完全一致行数。端末内で処理し保存しません。")
                }.padding(22)
            }
        }.frame(minWidth: 850, idealWidth: 950, minHeight: 720)
            .task(id: request) {
                let value = request
                result = nil; error = ""; busy = false
                guard !value.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                busy = true
                let calculated = await Task.detached(priority: .userInitiated) {
                    Result { try SmallDataTools.statistics(SmallDataTools.parse(value.input, delimiter: value.tabSeparated ? "\t" : ","), header: value.header, nullTokens: value.nullTokens) }
                }.value
                guard !Task.isCancelled else { return }
                busy = false
                switch calculated { case .success(let output): result = output; case .failure(let failure): error = failure.localizedDescription }
            }
    }
    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading) { Text(label).font(.caption).foregroundStyle(.secondary); Text(String(value)).font(.title2.bold()) }
    }
    private func number(_ value: Double?) -> String { value.map { String(format: "%.10g", $0) } ?? "—" }
    private func rate(_ count: Int, _ total: Int) -> String { total > 0 ? String(format: "%.1f%%", Double(count) / Double(total) * 100) : "—" }
    private func copy() {
        guard let result else { return }
        var rows = [["列", "型", "件数", "NULL", "NULL率", "ユニーク", "最頻値", "合計", "平均", "中央値", "最小", "最大"]]
        rows += result.columns.map { c in [c.name, c.type, String(c.count), String(c.nulls), rate(c.nulls, result.rows), String(c.unique), c.mode ?? "", number(c.sum), number(c.mean), number(c.median), number(c.minimum), number(c.maximum)] }
        let summary = "データ行：\(result.rows) · 列：\(result.columns.count) · NULL：\(result.nulls) · 重複行：\(result.duplicates)\n"
        NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(summary + CSVDocument.serialize(rows), forType: .string) ? "コピーしました" : "コピーできませんでした"
    }
    private func open() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.commaSeparatedText, .plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 524_288 else { throw ToolFailure.message("512KiB以下のファイルを選んでください。") }
            input = try CSVDocument.decode(Data(contentsOf: url)).0; status = url.lastPathComponent
        } catch { self.error = error.localizedDescription }
    }
}
private struct StatisticsRequest: Equatable, Sendable {
    let input: String, nullTokens: String
    let header: Bool, tabSeparated: Bool
}
