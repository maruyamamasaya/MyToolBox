import SwiftUI
private actor ComparisonWorker {
    func diff(_ left: String, _ right: String) throws -> TextComparison.Result { try Task.checkCancellation(); return try TextComparison.compare(left,right) }
    func lists(_ left: String, _ right: String, options: ListComparison.Options) throws -> ListComparison.Result { try Task.checkCancellation(); return try ListComparison.compare(left,right,options: options) }
}
@MainActor final class ComparisonModel: ObservableObject {
    enum Mode: String, CaseIterable { case diff = "テキスト差分", lists = "リスト比較" }
    @Published var mode: Mode = .diff
    @Published var left = ""
    @Published var right = ""
    @Published var status = ""
    @Published var wrap = true
    @Published var busy = false
    @Published var options = ListComparison.Options()
    @Published var diff: TextComparison.Result?
    @Published var lists: ListComparison.Result?
    private let worker = ComparisonWorker()
    private var task: Task<Void, Never>?
    func changed() { task?.cancel(); diff = nil; lists = nil; status = ""; busy = false; if mode == .lists { compare() } }
    func compare() {
        task?.cancel(); status = ""; busy = true
        let left = left, right = right, mode = mode, options = options
        task = Task {
            do {
                if mode == .lists {
                    try await Task.sleep(nanoseconds: 150_000_000)
                    let result = try await worker.lists(left,right,options: options)
                    try Task.checkCancellation(); lists = result
                } else {
                    let result = try await worker.diff(left,right)
                    try Task.checkCancellation(); diff = result
                }
                busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; status = error.localizedDescription; diff = nil; lists = nil; busy = false }
        }
    }
    func modeChanged() { task?.cancel(); busy = false; status = ""; if mode == .lists { compare() } }
    func swap() { Swift.swap(&left,&right); changed() }
    func clear() { left = ""; right = ""; changed() }
    func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); status = "コピーしました" }
    func stop() { task?.cancel() }
}
struct ComparisonView: View {
    @ObservedObject var model: ComparisonModel
    private let tint = Color(red: 0.23, green: 0.43, blue: 0.94)
    var body: some View {
        ToolPage("比較ツール", subtitle: "文章の変更と、リストの違いをひと目で。", symbol: "rectangle.split.2x1", tint: tint) {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("比較モード", selection: $model.mode) { ForEach(ComparisonModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 360)
                    HStack(spacing: 16) {
                        TextPane(title: "左 / A", symbol: "a.square", text: $model.left, tint: .orange)
                        TextPane(title: "右 / B", symbol: "b.square", text: $model.right, tint: .teal)
                    }.frame(height: 220)
                    HStack(spacing: 12) {
                        if model.mode == .diff { Button { model.compare() } label: { Label("比較する", systemImage: "arrow.left.arrow.right") }.buttonStyle(.borderedProminent).disabled(model.busy) }
                        Button { model.swap() } label: { Label("左右を入れ替え", systemImage: "arrow.triangle.swap") }
                        Button("クリア") { model.clear() }.disabled(model.left.isEmpty && model.right.isEmpty)
                        if model.busy { ProgressView().controlSize(.small) }
                        Text(model.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        Spacer()
                    }
                    if model.mode == .diff { diffResults }
                    else { listResults }
                    ToolFootnote(text: model.mode == .diff ? "改行コードを統一して行単位で比較。空行と末尾改行は区別します。左右各256KiB・1,000行まで、省略はしません。変更行の対応付けは近さによる推定です。" : "1行を1項目として重複をまとめます。共通とAのみはA、BのみはBの最初の表記・出現順を保ちます。左右各1MiB・20,000行まで。")
                }.padding(24)
            }
        }.frame(minWidth: 1100, minHeight: 900)
        .onChange(of: model.left) { _, _ in model.changed() }.onChange(of: model.right) { _, _ in model.changed() }
        .onChange(of: model.mode) { _, _ in model.modeChanged() }.onChange(of: model.options) { _, _ in if model.mode == .lists { model.compare() } }
        .onDisappear { model.stop() }
    }
    @ViewBuilder private var diffResults: some View {
        if let result = model.diff {
            HStack(spacing: 12) {
                badge("同一", result.same, .secondary)
                badge("変更", result.changed, .orange)
                badge("削除", result.removed, .red)
                badge("追加", result.added, .green)
                Spacer()
                Toggle("行を折り返す", isOn: $model.wrap).toggleStyle(.checkbox)
                Button { model.copy(result.plainText) } label: { Label("比較結果をコピー", systemImage: "doc.on.doc") }.disabled(result.rows.isEmpty)
            }
            if result.rows.isEmpty { ContentUnavailableView("入力が空です", systemImage: "doc.text.magnifyingglass", description: Text("左右のテキストを入力してください")) }
            else { DiffGrid(rows: result.rows, wrap: model.wrap).frame(height: 420) }
        } else {
            ContentUnavailableView("左右のテキストを比較", systemImage: "rectangle.split.2x1", description: Text("テキストを貼り付けて「比較する」を押すと、追加・削除・変更を色分けします。"))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
        }
    }
    private var listResults: some View {
        VStack(spacing: 16) {
            ToolCard {
                HStack(spacing: 24) {
                    Toggle("前後の空白を無視", isOn: $model.options.trim)
                    Toggle("大文字・小文字を無視", isOn: $model.options.ignoreCase)
                    Toggle("空行を除外", isOn: $model.options.ignoreEmpty)
                    Spacer()
                    if let result = model.lists { Text("A \(result.leftCount) 件 / B \(result.rightCount) 件").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }.toggleStyle(.checkbox)
            }
            HStack(spacing: 16) {
                listCard("共通", values: model.lists?.common ?? [], symbol: "link", color: .green)
                listCard("A のみ", values: model.lists?.onlyLeft ?? [], symbol: "a.square", color: .orange)
                listCard("B のみ", values: model.lists?.onlyRight ?? [], symbol: "b.square", color: .blue)
            }.frame(height: 310)
        }
    }
    private func listCard(_ title: String, values: [String], symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                Text("\(values.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { model.copy(values.joined(separator: "\n")) } label: { Image(systemName: "doc.on.doc") }.disabled(values.isEmpty || model.busy).accessibilityLabel(title + "をコピー")
            }.padding(13)
            Divider().opacity(0.5)
            ToolTextEditor(text: .constant(values.joined(separator: "\n")), editable: false, label: title + "の項目")
        }.background(color.opacity(0.04), in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color.opacity(0.2)))
    }
    private func badge(_ title: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 7) { Circle().fill(color).frame(width: 6,height: 6); Text(title); Text("\(count)").bold().monospacedDigit() }.font(.caption).padding(.horizontal, 11).padding(.vertical, 8).background(color.opacity(0.08), in: Capsule())
    }
}
private struct DiffGrid: View {
    let rows: [TextComparison.Row]
    let wrap: Bool
    var body: some View {
        GeometryReader { geometry in
            let width = wrap ? max(160, (geometry.size.width - 170) / 2) : max((geometry.size.width - 170) / 2, CGFloat(rows.map { max(($0.left ?? "").utf16.count, ($0.right ?? "").utf16.count) }.max() ?? 1) * 14 + 18)
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) { Text("左 / A").frame(width: width + 52, alignment: .leading); Text("右 / B").frame(width: width + 52, alignment: .leading); Text("状態").frame(width: 64) }.font(.caption.bold()).padding(.vertical, 10).background(.primary.opacity(0.04))
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: 0) {
                            cell(row.left, number: row.leftNumber, span: row.leftSpan, width: width, color: row.kind == .same ? .clear : .red)
                            Divider()
                            cell(row.right, number: row.rightNumber, span: row.rightSpan, width: width, color: row.kind == .same ? .clear : .green)
                            Text(row.kind.rawValue).font(.system(size: 10, weight: .medium)).foregroundStyle(color(row.kind)).frame(width: 64, alignment: .center).padding(.top, 12)
                        }.background(row.id.isMultiple(of: 2) ? Color.primary.opacity(0.015) : .clear)
                        Divider().opacity(0.35)
                    }
                }.frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
            }
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)))
    }
    private func color(_ kind: TextComparison.Kind) -> Color {
        switch kind { case .same: return .secondary; case .changed: return .orange; case .removed: return .red; case .added: return .green }
    }
    private func cell(_ text: String?, number: Int?, span: TextComparison.Span?, width: CGFloat, color: Color) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(number.map(String.init) ?? "—").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 32, alignment: .trailing).padding(.top, 12)
            Group {
                if let text, !text.isEmpty { Text(highlighted(text, span: span, color: color)).textSelection(.enabled) }
                else { Text(text == nil ? "—" : "空行").foregroundStyle(.tertiary) }
            }.font(.system(size: 12, design: .monospaced)).lineLimit(wrap ? nil : 1).fixedSize(horizontal: false, vertical: true).frame(width: width, alignment: .leading).padding(.horizontal, 10).padding(.vertical, 10)
        }.frame(maxHeight: .infinity, alignment: .top).background(text == nil ? Color.primary.opacity(0.02) : color.opacity(0.055))
    }
    private func highlighted(_ text: String, span: TextComparison.Span?, color: Color) -> AttributedString {
        var value = AttributedString(text)
        if let span, span.length > 0, let range = Range(NSRange(location: span.location,length: span.length), in: text), let start = AttributedString.Index(range.lowerBound, within: value), let end = AttributedString.Index(range.upperBound, within: value) {
            value[start..<end].backgroundColor = color.opacity(0.2)
            value[start..<end].font = .system(size: 12, weight: .semibold, design: .monospaced)
        }
        return value
    }
}
