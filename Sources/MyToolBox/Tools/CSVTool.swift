import SwiftUI
import UniformTypeIdentifiers

@MainActor final class CSVModel: ObservableObject {
    @Published var rows: [[String]] = []
    @Published var input = ""
    @Published var search = ""
    @Published var status = "CSVを開くか、テキストを貼り付けてください"
    @Published var dirty = false
    @Published var busy = false
    @Published var selectedRow = -1
    @Published var selectedColumn = 0
    @Published var sortColumn = -1
    @Published var descending = false
    @Published var fitRevision = 0
    @Published var ellipsis = true
    private var loadedInput = ""
    let editable: Bool
    init(editable: Bool) { self.editable = editable }
    var width: Int { rows.first?.count ?? 0 }
    var indices: [Int] {
        let base = Array(rows.indices.dropFirst(editable ? 0 : 1)).filter { i in search.isEmpty || rows[i].contains { $0.localizedCaseInsensitiveContains(search) } }
        guard sortColumn >= 0, sortColumn < width else { return base }
        return base.sorted { a,b in
            let order = rows[a][sortColumn].localizedStandardCompare(rows[b][sortColumn])
            if order == .orderedSame { return a < b }
            return descending ? order == .orderedDescending : order == .orderedAscending
        }
    }
    func confirmClose() -> Bool {
        guard dirty || input != loadedInput else { return true }
        let alert = NSAlert(); alert.messageText = "未保存のCSV編集を破棄して閉じますか？"
        alert.informativeText = "保存する場合はキャンセルして、CSVで保存を選んでください。"
        alert.addButton(withTitle: "キャンセル"); alert.addButton(withTitle: "破棄して閉じる")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func confirmReplace() -> Bool {
        finishEditing()
        guard dirty else { return true }
        let alert = NSAlert(); alert.messageText = "未保存の編集を置き換えますか？"; alert.addButton(withTitle: "キャンセル"); alert.addButton(withTitle: "置き換える")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func load(text: String, label: String, ask: Bool = true) {
        guard !busy, !ask || confirmReplace() else { return }
        busy = true
        Task {
            let result = await Task.detached { Result { try CSVDocument.parse(text) } }.value
            switch result {
            case .success(let data): rows = data; input = text; loadedInput = text; dirty = editable && label == "貼り付けデータ"; search = ""; sortColumn = -1; selectedRow = -1; selectedColumn = 0; status = label
            case .failure(let e): status = e.localizedDescription
            }
            busy = false
        }
    }
    func open() {
        guard !busy, confirmReplace() else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.commaSeparatedText, .plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        read(url)
    }
    func read(_ url: URL) {
        busy = true
        Task {
            let result = await Task.detached { Result { () throws -> (String,String) in
                let attrs = try url.resourceValues(forKeys: [.fileSizeKey])
                guard (attrs.fileSize ?? Int.max) <= 8 * 1024 * 1024 else { throw ToolFailure.message("8MiB以下のCSVを指定してください") }
                return try CSVDocument.decode(Data(contentsOf: url))
            } }.value
            busy = false
            switch result { case .success(let decoded): load(text: decoded.0, label: url.lastPathComponent + " · " + decoded.1, ask: false)
            case .failure(let e): status = e.localizedDescription }
        }
    }
    func edit(row: Int, column: Int, value: String) {
        guard editable, rows.indices.contains(row), rows[row].indices.contains(column) else { return }
        guard rows[row][column] != value else { return }
        rows[row][column] = value; dirty = true
    }
    func finishEditing() { NSApp.keyWindow?.makeFirstResponder(nil) }
    func sort(_ column: Int) {
        finishEditing()
        if sortColumn != column { sortColumn = column; descending = false }
        else if !descending { descending = true }
        else { sortColumn = -1 }
    }
    func save(txt: Bool) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        let panel = NSSavePanel(); panel.allowedContentTypes = [txt ? .plainText : .commaSeparatedText]; panel.nameFieldStringValue = txt ? "edited-data.txt" : "edited-data.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try CSVDocument.encoded(rows).write(to: url, options: .atomic); dirty = false; status = "保存しました：" + url.lastPathComponent }
        catch { status = error.localizedDescription }
    }
}
struct CSVToolView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: CSVModel
    @State private var showPaste = false
    private var accent: Color { model.editable ? .orange : .blue }
    var body: some View {
        ToolPage(model.editable ? "CSVエディター" : "CSVビューワー", subtitle: model.editable ? "表で編集して、そのまま書き出す。" : "データを見渡す。探す。並べ替える。", symbol: model.editable ? "square.and.pencil" : "tablecells", tint: accent) {
            ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Button { model.open() } label: { Label("CSVを開く", systemImage: "folder") }.controlSize(.large)
                    Button { withAnimation { showPaste.toggle() } } label: { Label("テキストを貼り付け", systemImage: "doc.on.clipboard") }.controlSize(.large)
                    Spacer()
                    if model.dirty { Label("未保存", systemImage: "circle.fill").font(theme.font(11)).foregroundStyle(.orange) }
                    if model.editable {
                        Button { model.save(txt: false) } label: { Label("CSVで保存", systemImage: "square.and.arrow.down") }.buttonStyle(ThemeButtonStyle(prominent: true)).controlSize(.large).disabled(model.rows.isEmpty || model.busy)
                        Menu { Button("TXTで保存…") { model.save(txt: true) } } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().disabled(model.rows.isEmpty)
                    }
                }.disabled(model.busy)
                if showPaste {
                    ToolCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { ToolSectionLabel(title: "CSVテキスト", symbol: "text.alignleft"); Spacer(); Button("閉じる") { showPaste = false }.buttonStyle(ThemeButtonStyle(plain: true)).font(theme.font(11)) }
                            ToolTextEditor(text: $model.input).font(theme.font( 12, design: .monospaced)).scrollContentBackground(.hidden).padding(8).frame(height: 95).background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                            HStack { Text("カンマ区切り・引用符・セル内改行に対応").font(theme.font(11)).foregroundStyle(.secondary); Spacer(); Button("表に反映") { model.load(text: model.input, label: "貼り付けデータ") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.busy) }
                        }
                    }
                }
                if model.rows.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tablecells.badge.ellipsis").font(theme.font( 54, weight: .ultraLight)).foregroundStyle(accent.opacity(0.75))
                        Text("CSVをここにドロップ").font(theme.font( 21, weight: .semibold, design: .rounded))
                        Text("ファイルを選ぶか、CSVテキストを貼り付けて始めましょう。\nデータはこのMacの中だけで処理します。").font(theme.font( 13)).foregroundStyle(.secondary).multilineTextAlignment(.center).lineSpacing(5)
                        Button("ファイルを選ぶ…") { model.open() }.buttonStyle(ThemeButtonStyle(prominent: true)).controlSize(.large).disabled(model.busy)
                        Text("UTF-8 / Shift_JIS  ·  最大8 MiB").font(theme.font(11)).foregroundStyle(.tertiary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity).frame(minHeight: 260)
                        .background(accent.opacity(0.035), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 16))
                        .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 16).strokeBorder(accent.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
                } else {
                    HStack(spacing: 12) {
                        HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("すべての列から検索", text: $model.search).textFieldStyle(.plain); if !model.search.isEmpty { Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(ThemeButtonStyle(plain: true)).foregroundStyle(.secondary) } }.padding(9).background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                        Button { model.fitRevision += 1 } label: { Label("列幅を合わせる", systemImage: "arrow.left.and.right") }
                        Toggle("省略記号", isOn: $model.ellipsis).toggleStyle(ThemeToggleStyle()).font(theme.font(11))
                    }
                    VStack(spacing: 0) {
                        HStack { ToolSectionLabel(title: "データ", symbol: "tablecells"); Text("\(model.indices.count) 行 × \(model.width) 列").font(theme.font( 11, design: .monospaced)).foregroundStyle(.secondary); Spacer(); Text("見出しで並べ替え / 境界で幅を調整").font(theme.font(10)).foregroundStyle(.tertiary) }.padding(12)
                        Divider()
                        CSVGrid(model: model).frame(height: 320)
                    }.background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 12)).overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 12).strokeBorder(.primary.opacity(0.08)))
                    if model.editable {
                        HStack(spacing: 10) {
                            Button { model.finishEditing(); model.rows.append(Array(repeating: "", count: model.width)); model.dirty = true } label: { Label("行を追加", systemImage: "plus") }.disabled(model.rows.count >= 20_000 || (model.rows.count + 1) * model.width > 200_000)
                            Button { model.finishEditing(); model.rows = model.rows.map { $0 + [""] }; model.dirty = true } label: { Label("列を追加", systemImage: "plus") }.disabled(model.width >= 200 || model.rows.count * (model.width + 1) > 200_000)
                            Divider().frame(height: 18)
                            Button("選択行を削除") { model.finishEditing(); model.rows.remove(at: model.selectedRow); model.selectedRow = -1; model.dirty = true }.disabled(!model.rows.indices.contains(model.selectedRow) || model.rows.count <= 1)
                            Spacer()
                            ThemePicker("編集列", selection: $model.selectedColumn, options: (0..<model.width).map { ($0, "列 \($0 + 1)") }).frame(width: 150)
                            Button("列を削除") { model.finishEditing(); model.sortColumn = -1; let c = model.selectedColumn; model.rows = model.rows.map { var row = $0; row.remove(at: c); return row }; model.selectedColumn = 0; model.dirty = true }.disabled(model.width <= 1)
                        }.controlSize(.small)
                        if model.rows.indices.contains(model.selectedRow), model.width > model.selectedColumn {
                            VStack(alignment: .leading, spacing: 6) {
                                ToolSectionLabel(title: "セルを編集 · \(model.selectedRow + 1)行 / \(model.selectedColumn + 1)列（改行可）", symbol: "pencil.line")
                                ToolTextEditor(text: Binding(get: { model.rows.indices.contains(model.selectedRow) && model.rows[model.selectedRow].indices.contains(model.selectedColumn) ? model.rows[model.selectedRow][model.selectedColumn] : "" }, set: { model.edit(row: model.selectedRow, column: model.selectedColumn, value: $0) })).font(theme.font( 12, design: .monospaced)).scrollContentBackground(.hidden).padding(8).frame(height: 64).background(theme.surfaceHigh, in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    if model.busy { ProgressView().controlSize(.small) } else { Image(systemName: "doc.text").foregroundStyle(.tertiary) }
                    Text(model.status).font(theme.font(11)).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                    Spacer()
                    Text(model.editable ? "保存形式 UTF-8 / BOM" : "先頭行は列見出し").font(theme.font(10)).foregroundStyle(.tertiary)
                }.frame(minHeight: 22)
            }.padding(22)
            }
        }.frame(minWidth: 940, minHeight: 780)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            guard !model.busy, let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                Task { @MainActor in
                    guard let url, url.isFileURL, !model.busy, model.confirmReplace() else { return }
                    model.read(url)
                }
            }
            return true
        }
    }
}
struct CSVGrid: NSViewRepresentable {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: CSVModel
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        let table = ThemeTableView(); table.delegate = context.coordinator; table.dataSource = context.coordinator
        table.target = context.coordinator; table.doubleAction = #selector(Coordinator.beginCellEdit(_:))
        table.usesAlternatingRowBackgroundColors = true; table.rowHeight = 26; table.columnAutoresizingStyle = .noColumnAutoresizing
        scroll.documentView = table; return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        if let themedTable = table as? ThemeTableView {
            themedTable.theme = theme
            themedTable.needsDisplay = true
        }
        scroll.backgroundColor = theme.classic ? .white : NSColor(theme.surfaceHigh)
        scroll.scrollerStyle = theme.classic ? .legacy : .overlay
        table.backgroundColor = theme.classic ? .white : NSColor(theme.surfaceHigh)
        table.usesAlternatingRowBackgroundColors = !theme.classic
        context.coordinator.theme = theme
        for column in table.tableColumns {
            if theme.classic, !(column.headerCell is ClassicHeaderCell) { column.headerCell = ClassicHeaderCell(textCell: column.title) }
            else if !theme.classic, column.headerCell is ClassicHeaderCell { column.headerCell = NSTableHeaderCell(textCell: column.title) }
        }
        context.coordinator.reloading = true
        defer { context.coordinator.reloading = false }
        let mapping = model.indices
        let needsReload = context.coordinator.lastRows != model.rows || context.coordinator.mapping != mapping || context.coordinator.lastEllipsis != model.ellipsis
        context.coordinator.lastRows = model.rows; context.coordinator.lastEllipsis = model.ellipsis
        context.coordinator.mapping = mapping
        if table.tableColumns.count != model.width {
            for c in table.tableColumns { table.removeTableColumn(c) }
            for index in 0..<model.width { let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(index))); if theme.classic { column.headerCell = ClassicHeaderCell(textCell: "") }; column.width = 150; column.minWidth = 48; table.addTableColumn(column) }
        }
        for (i, column) in table.tableColumns.enumerated() {
            let title = model.editable ? "列 \(i + 1)" : model.rows.first?[i] ?? ""
            column.title = title + (model.sortColumn == i ? (model.descending ? " ↓" : " ↑") : "")
        }
        if context.coordinator.fitRevision != model.fitRevision {
            context.coordinator.fitRevision = model.fitRevision
            let width = max(48, min(400, (scroll.contentSize.width - 18) / CGFloat(max(1, model.width))))
            for column in table.tableColumns { column.width = width }
        }
        if needsReload { table.reloadData() }
        context.coordinator.updateCellColors(table)
        if let row = context.coordinator.mapping.firstIndex(of: model.selectedRow) {
            if table.selectedRow != row { table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false) }
        } else if table.selectedRow != -1 { table.deselectAll(nil) }
    }
    final class Field: NSTextField { var row = 0; var column = 0 }
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        var theme = AppTheme()
        let model: CSVModel; var mapping: [Int] = []; var reloading = false; var fitRevision = 0
        var lastRows: [[String]] = []; var lastEllipsis = true
        init(_ model: CSVModel) { self.model = model }
        @MainActor @objc func beginCellEdit(_ table: NSTableView) {
            let row = table.clickedRow, column = table.clickedColumn
            guard model.editable, mapping.indices.contains(row), column >= 0 else { return }
            model.selectedRow = mapping[row]; model.selectedColumn = column
            DispatchQueue.main.async { [weak table] in
                guard let table, let field = table.view(atColumn: column, row: row, makeIfNecessary: true) as? Field else { return }
                table.window?.makeFirstResponder(field); field.selectText(nil)
            }
        }
        func numberOfRows(in tableView: NSTableView) -> Int { mapping.count }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let c = tableColumn.flatMap({ Int($0.identifier.rawValue) }), mapping.indices.contains(row) else { return nil }
            let index = mapping[row]
            guard model.rows.indices.contains(index), model.rows[index].indices.contains(c) else { return nil }
            let field = Field()
            field.setAccessibilityLabel("\(index + 1)行・\(c + 1)列")
            field.stringValue = model.rows[index][c]; field.row = index; field.column = c
            field.isEditable = model.editable; field.isSelectable = true; field.isBordered = false; field.backgroundColor = .clear; field.textColor = theme.classic && tableView.isRowSelected(row) ? .white : NSColor(theme.text); field.delegate = self
            field.lineBreakMode = model.ellipsis ? .byTruncatingTail : .byClipping; field.toolTip = field.stringValue
            return field
        }
        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? Field else { return }
            if model.selectedColumn != field.column { model.selectedColumn = field.column }
            if model.selectedRow != field.row { model.selectedRow = field.row }
        }
        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? Field else { return }
            model.edit(row: field.row, column: field.column, value: field.stringValue)
        }
        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) { if let c = Int(tableColumn.identifier.rawValue) { model.sort(c) } }
        func updateCellColors(_ table: NSTableView) {
            let visible = table.rows(in: table.visibleRect)
            guard visible.location != NSNotFound else { return }
            for row in visible.location..<min(table.numberOfRows, NSMaxRange(visible)) {
                for column in 0..<table.numberOfColumns {
                    (table.view(atColumn: column, row: row, makeIfNecessary: false) as? Field)?.textColor = theme.classic && table.isRowSelected(row) ? .white : NSColor(theme.text)
                }
            }
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let table = notification.object as? NSTableView else { return }
            updateCellColors(table)
            guard !reloading else { return }
            let value = mapping.indices.contains(table.selectedRow) ? mapping[table.selectedRow] : -1
            if model.selectedRow != value { model.selectedRow = value }
        }
    }
}
