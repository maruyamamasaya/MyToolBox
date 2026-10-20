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
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: ComparisonModel
    @State private var expanded: Bool
    @State private var showsSettings = false
    init(model: ComparisonModel, initiallyExpanded: Bool = false) {
        self.model = model; _expanded = State(initialValue: initiallyExpanded)
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("比較ツール").font(.headline)
                Spacer(minLength: 0)
                Button(expanded ? "小さく戻す" : "拡大") { expanded.toggle() }
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("比較の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            if model.mode == .diff { Toggle("行を折り返す", isOn: $model.wrap) }
                            else {
                                Toggle("前後の空白を無視", isOn: $model.options.trim)
                                Toggle("大文字・小文字を無視", isOn: $model.options.ignoreCase)
                                Toggle("空行を除外", isOn: $model.options.ignoreEmpty)
                            }
                            ThemeMenu()
                            Text(model.mode == .diff ? "改行を統一して行単位で比較。空行・末尾改行を区別。左右各256KiB・1,000行。変更行の対応は近さによる推定です。" : "1行1項目で重複を集約。共通とAのみはA、BのみはBの最初の表記・順序を保持。左右各1MiB・20,000行。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 280)
                    }
            }
            Picker("比較モード", selection: $model.mode) {
                ForEach(ComparisonModel.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            HStack(spacing: 8) {
                input("A", text: $model.left)
                input("B", text: $model.right)
            }.frame(height: expanded ? 200 : 150)
            HStack(spacing: 6) {
                Button { model.swap() } label: {
                    Image(systemName: "arrow.left.arrow.right").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("AとBを入れ替え")
                Button { model.clear() } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア").disabled(model.left.isEmpty && model.right.isEmpty)
                Text(model.busy ? "比較中…" : model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer(minLength: 0)
                Button { model.compare() } label: { Text("比較").frame(minWidth: 28, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
            }
            if model.mode == .diff { diffResults } else { listResults }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: expanded ? 800 : 340, idealWidth: expanded ? 1100 : 360,
                   minHeight: expanded ? 600 : 480, idealHeight: expanded ? 850 : 520)
            .background(ExpandableToolWindowSizing(expanded: expanded))
            .onChange(of: model.left) { _, _ in model.changed() }.onChange(of: model.right) { _, _ in model.changed() }
            .onChange(of: model.mode) { _, _ in model.modeChanged() }
            .onChange(of: model.options) { _, _ in if model.mode == .lists { model.compare() } }
            .onDisappear { model.stop() }
    }
    private func input(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title == "A" ? "A（左）" : "B（右）").font(.caption.weight(.semibold)).foregroundStyle(title == "A" ? Color.orange : Color.teal)
            ToolTextEditor(text: text, label: title + "の入力").frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
        }
    }
    @ViewBuilder private var diffResults: some View {
        if let result = model.diff {
            HStack(spacing: 6) {
                Text("同一 \(result.same) · 変更 \(result.changed) · −\(result.removed) · ＋\(result.added)")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { model.copy(result.plainText) } label: {
                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("比較結果をコピー").disabled(result.rows.isEmpty || model.busy)
            }
            DiffGrid(rows: result.rows, wrap: model.wrap, compact: !expanded).frame(maxHeight: .infinity)
        } else {
            Text("AとBを入力して「比較」を押してください")
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    private var listResults: some View {
        VStack(spacing: 6) {
            if let result = model.lists {
                Text("A \(result.leftCount)件 / B \(result.rightCount)件").font(.caption).foregroundStyle(.secondary)
            }
            if expanded {
                HStack(spacing: 8) { listCards }.frame(maxHeight: .infinity)
            } else {
                ScrollView { VStack(spacing: 8) { listCards } }
            }
        }
    }
    @ViewBuilder private var listCards: some View {
        listCard("共通", values: model.lists?.common ?? [], symbol: "link", color: .green).frame(minHeight: 120)
        listCard("Aのみ", values: model.lists?.onlyLeft ?? [], symbol: "a.square", color: .orange).frame(minHeight: 120)
        listCard("Bのみ", values: model.lists?.onlyRight ?? [], symbol: "b.square", color: .blue).frame(minHeight: 120)
    }
    private func listCard(_ title: String, values: [String], symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: symbol).font(theme.font( 13, weight: .semibold)).foregroundStyle(color)
                Text("\(values.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button { model.copy(values.joined(separator: "\n")) } label: { Image(systemName: "doc.on.doc") }.disabled(values.isEmpty || model.busy).accessibilityLabel(title + "をコピー")
            }.padding(13)
            Divider().opacity(0.5)
            ToolTextEditor(text: .constant(values.joined(separator: "\n")), editable: false, label: title + "の項目")
        }.background(color.opacity(0.04), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 14)).overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 14).strokeBorder(color.opacity(0.2)))
    }
    private func badge(_ title: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 7) { Circle().fill(color).frame(width: 6,height: 6); Text(title); Text("\(count)").bold().monospacedDigit() }.font(theme.font(11)).padding(.horizontal, 11).padding(.vertical, 8).background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 50))
    }
}
private struct DiffGrid: View {
    @Environment(\.appTheme) private var theme
    let rows: [TextComparison.Row]
    let wrap: Bool
    var compact = false
    private var gutter: CGFloat { compact ? 20 : 32 }
    private var inset: CGFloat { compact ? 5 : 10 }
    var body: some View {
        GeometryReader { geometry in
            let available = max(1, (geometry.size.width - 2) / 2)
            let longest = CGFloat(rows.map { max(($0.left ?? "").utf16.count, ($0.right ?? "").utf16.count) }.max() ?? 1)
            let column = wrap ? available : max(available, longest * 8 + gutter + inset * 2)
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 2) {
                        columnHeader("A（左）", color: .orange, width: column)
                        columnHeader("B（右）", color: .teal, width: column)
                    }
                    if rows.isEmpty {
                        Text("入力が空です").font(.caption).foregroundStyle(.secondary).padding(12)
                    }
                    ForEach(rows) { row in
                        VStack(spacing: 0) {
                            HStack {
                                Text(row.kind.rawValue).font(theme.font(10, weight: .semibold)).foregroundStyle(color(row.kind))
                                Spacer()
                            }.padding(.horizontal, 6).padding(.vertical, compact ? 2 : 4)
                                .background(color(row.kind).opacity(row.kind == .same ? 0.03 : 0.1))
                            HStack(alignment: .top, spacing: 0) {
                                cell(row.left, number: row.leftNumber, span: row.leftSpan, column: column, color: row.kind == .same ? .clear : .red)
                                Rectangle().fill(theme.edge.opacity(0.45)).frame(width: 2)
                                cell(row.right, number: row.rightNumber, span: row.rightSpan, column: column, color: row.kind == .same ? .clear : .green)
                            }.fixedSize(horizontal: false, vertical: true)
                            Divider().opacity(0.5)
                        }.background(row.id.isMultiple(of: 2) ? Color.primary.opacity(0.025) : .clear)
                    }
                }.frame(width: column * 2 + 2, alignment: .topLeading)
                    .frame(minHeight: geometry.size.height, alignment: .topLeading)
            }
        }.background(theme.surfaceHigh.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: theme.classic ? 0 : 8))
            .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 8).strokeBorder(theme.edge.opacity(0.25)))
            .classicBevel(sunken: true)
    }
    private func columnHeader(_ title: String, color: Color, width: CGFloat) -> some View {
        Text(title).font(theme.font(compact ? 12 : 14, weight: .bold))
            .foregroundStyle(color).frame(width: width, alignment: .leading)
            .padding(.vertical, compact ? 7 : 10).background(color.opacity(0.14))
    }
    private func color(_ kind: TextComparison.Kind) -> Color {
        switch kind { case .same: return .secondary; case .changed: return .orange; case .removed: return .red; case .added: return .green }
    }
    private func cell(_ text: String?, number: Int?, span: TextComparison.Span?, column: CGFloat, color: Color) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(number.map(String.init) ?? "—").font(theme.font(10, design: .monospaced))
                .foregroundStyle(.secondary).frame(width: gutter, alignment: .trailing)
            Group {
                if let text, !text.isEmpty { Text(highlighted(text, span: span, color: color)).textSelection(.enabled) }
                else { Text(text == nil ? "—" : "空行").foregroundStyle(.secondary) }
            }.font(theme.font(12, design: .monospaced)).lineLimit(wrap ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: max(1, column - gutter - inset * 2), alignment: .leading)
                .padding(.horizontal, inset)
        }.padding(.vertical, compact ? 6 : 10).frame(width: column, alignment: .topLeading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(text == nil ? Color.primary.opacity(0.04) : color.opacity(0.055))
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
