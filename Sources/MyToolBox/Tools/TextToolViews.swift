import SwiftUI
import Combine

/// Bounded text work is serial and kept off MainActor. Cancelled queued work is skipped.
actor TextProcessor {
    static let shared = TextProcessor()
    func sequence(_ input: String, options: SequentialText.Options) throws -> SequentialText.Result { try Task.checkCancellation(); return try SequentialText.generate(input, options: options) }
    func clean(_ input: String) throws -> String { try Task.checkCancellation(); return try TextCleaner.clean(input) }
    func parse(_ input: String) throws -> ClipboardTable.Parsed { try Task.checkCancellation(); return try ClipboardTable.parse(input) }
    func format(_ rows: [[String]], columns: Set<Int>, options: ClipboardTable.Options) throws -> String { try Task.checkCancellation(); return try ClipboardTable.format(rows, columns: columns, options: options) }
}
@MainActor final class TextTransformModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var status = ""
    @Published var busy = false
    @Published var count = ""
    @Published var cleanerMode = "クリーニング"
    @Published var start = "1"
    @Published var increment = "1"
    @Published var options = SequentialText.Options()
    private var task: Task<Void, Never>?
    let cleaner: Bool
    init(cleaner: Bool = false) { self.cleaner = cleaner }
    func update() {
        task?.cancel(); status = ""; output = ""; busy = true
        let input = input, cleanerMode = cleanerMode; var settings = options
        let start = Int64(start), increment = Int64(increment)
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                if cleaner {
                    let result: String
                    if cleanerMode == "クリーニング" { result = try await TextProcessor.shared.clean(input) }
                    else { result = try await TextCodecWorker.shared.run(input, mode: cleanerMode == "文字チェック" ? .inspect : .visualize).text }
                    try Task.checkCancellation(); output = result; count = "\(input.count) → \(result.count) 文字"
                } else {
                    guard let start, let increment else { throw ToolFailure.message("開始番号と増加数は64ビット整数で入力してください") }
                    settings.start = start; settings.increment = increment
                    let result = try await TextProcessor.shared.sequence(input, options: settings)
                    try Task.checkCancellation(); output = result.output; count = "\(result.lines) 行 / \(result.numbered) 行に連番"
                }
                busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; output = ""; status = error.localizedDescription; busy = false }
        }
    }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(output, forType: .string); status = "コピーしました" }
    func paste() { input = NSPasteboard.general.string(forType: .string) ?? ""; update() }
    func stop() { task?.cancel() }
}
@MainActor final class ClipboardFormatterModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var status = "テキストや表を貼り付けると、自動で区切りを判定します"
    @Published var busy = false
    @Published var columns: Set<Int> = []
    @Published var options = ClipboardTable.Options()
    @Published var detected = ""
    let table = CSVModel(editable: true)
    private var parseTask: Task<Void, Never>?
    private var formatTask: Task<Void, Never>?
    private var copyTask: Task<Void, Never>?
    private var rowsObserver: AnyCancellable?
    private var parsing = false
    init() {
        rowsObserver = table.$rows.dropFirst().sink { [weak self] _ in
            Task { @MainActor in guard let self, !self.parsing else { return }; self.updateOutput() }
        }
    }
    func parse() {
        parseTask?.cancel(); formatTask?.cancel(); copyTask?.cancel(); busy = true; output = ""; status = ""
        parsing = true
        let source = input
        parseTask = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                let result = try await TextProcessor.shared.parse(source)
                try Task.checkCancellation()
                table.rows = result.rows; table.dirty = false; table.selectedRow = -1; table.selectedColumn = 0; table.sortColumn = -1
                columns = Set(0..<table.width); detected = "\(result.delimiter.rawValue) · \(table.rows.count) 行 × \(table.width) 列"
                parsing = false; updateOutput()
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; table.rows = []; columns = []; detected = ""; parsing = false; busy = false; status = error.localizedDescription }
        }
    }
    func updateOutput() {
        guard !parsing else { return }
        formatTask?.cancel(); busy = true; status = ""
        let rows = table.rows, columns = columns, options = options
        formatTask = Task {
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
                let result = try await TextProcessor.shared.format(rows, columns: columns, options: options)
                try Task.checkCancellation(); output = result; busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; output = ""; status = error.localizedDescription; busy = false }
        }
    }
    func copy() {
        // Commit an active table editor before taking the snapshot to copy.
        table.finishEditing(); copyTask?.cancel(); busy = true
        let rows = table.rows, columns = columns, options = options
        copyTask = Task {
            do {
                let result = try await TextProcessor.shared.format(rows, columns: columns, options: options)
                try Task.checkCancellation()
                output = result; NSPasteboard.general.clearContents(); NSPasteboard.general.setString(result, forType: .string)
                status = "コピーしました"; busy = false
            } catch is CancellationError { }
            catch { guard !Task.isCancelled else { return }; status = error.localizedDescription; busy = false }
        }
    }
    func stop() { parseTask?.cancel(); formatTask?.cancel(); copyTask?.cancel() }
}

/// Plain-text native editor; both input and selectable read-only output scale to bounded text.
struct ToolTextEditor: NSViewRepresentable {
    @Environment(\.appTheme) private var theme
    @Binding var text: String
    var editable = true
    var label: String = "テキスト"
    var highlights: [NSRange] = []
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let view = NSTextView()
        view.isRichText = false; view.importsGraphics = false; view.allowsUndo = true
        view.isEditable = editable; view.isSelectable = true; view.drawsBackground = false
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular); view.textColor = .labelColor; view.insertionPointColor = .labelColor
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.isVerticallyResizable = true; view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]; view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.delegate = context.coordinator; view.setAccessibilityLabel(label)
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.drawsBackground = false; scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let view = scroll.documentView as? NSTextView else { return }
        view.isEditable = editable; view.setAccessibilityLabel(label)
        view.textColor = NSColor(theme.text); view.insertionPointColor = NSColor(theme.text)
        view.drawsBackground = theme.classic; view.backgroundColor = NSColor(theme.surfaceHigh)
        view.selectedTextAttributes = [.backgroundColor: NSColor(theme.accent), .foregroundColor: NSColor.white]
        scroll.borderType = theme.classic ? .bezelBorder : .noBorder
        scroll.scrollerStyle = theme.classic ? .legacy : .overlay
        let changed = view.string != text
        if changed {
            let selection = view.selectedRange(); view.string = text
            view.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
        if changed || context.coordinator.highlights != highlights {
            context.coordinator.highlights = highlights
            let length = (text as NSString).length
            view.textStorage?.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: length))
            for range in highlights.prefix(1000) where range.location >= 0 && range.length > 0 && range.location <= length && range.length <= length - range.location {
                view.textStorage?.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.35), range: range)
            }
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var highlights: [NSRange] = []
        var parent: ToolTextEditor
        init(_ parent: ToolTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) { guard let view = notification.object as? NSTextView, parent.editable else { return }; parent.text = view.string }
    }
}
struct TextPane: View {
    @Environment(\.appTheme) private var theme
    var title: String
    var symbol: String
    @Binding var text: String
    var editable = true
    var tint: Color
    var highlights: [NSRange] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { ToolSectionLabel(title: title, symbol: symbol); Spacer(); Text("\(text.count) 文字").font(theme.font( 10, design: .monospaced)).foregroundStyle(.tertiary) }.padding(13)
            Divider().opacity(0.5)
            ToolTextEditor(text: $text, editable: editable, label: title, highlights: highlights).frame(minHeight: 120, maxHeight: .infinity)
        }.background(theme.classic ? theme.surfaceHigh : theme.surfaceHigh.opacity(0.5), in: RoundedRectangle(cornerRadius: theme.classic ? 0 : 14))
            .overlay(RoundedRectangle(cornerRadius: theme.classic ? 0 : 14).strokeBorder(tint.opacity(0.18)))
            .classicBevel(sunken: true)
    }
}
struct SequentialTextView: View {
    @ObservedObject var model: TextTransformModel
    @State private var showsSettings = false
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("連番テキスト生成").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("連番の設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            settingField("開始番号", text: $model.start)
                            settingField("増加数", text: $model.increment)
                            Picker("桁数", selection: $model.options.digits) {
                                ForEach(1..<9, id: \.self) { Text("\($0)桁").tag($0) }
                            }
                            Picker("位置", selection: $model.options.atEnd) {
                                Text("行の先頭").tag(false); Text("行の末尾").tag(true)
                            }
                            settingField("前の文字", text: $model.options.prefix)
                            settingField("区切り", text: $model.options.separator)
                            settingField("後の文字", text: $model.options.suffix)
                            Toggle("空行も連番対象", isOn: $model.options.numberEmptyLines)
                            ThemeMenu()
                            Text("入力すると自動生成します。開始・増加数は負数や0にも対応。空行を対象外にすると番号を消費しません。入力は最大1MiB・20,000行。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 280)
                    }
            }
            TextEditor(text: $model.input).font(.system(.body, design: .monospaced))
                .frame(minHeight: 55, maxHeight: .infinity).accessibilityLabel("元のテキスト")
                .overlay(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text("元のテキスト").font(.caption).foregroundStyle(.secondary).padding(6).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            ScrollView {
                Text(model.output.isEmpty ? (model.busy ? "処理中…" : "処理結果") : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? Color.secondary : Color.primary)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }.frame(minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("処理結果")
            Text(model.busy ? "処理中…" : model.status.isEmpty ? model.count : model.status)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { model.input = "" } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア").disabled(model.input.isEmpty)
                Spacer(minLength: 0)
                Button { model.update() } label: { Text("生成").frame(minWidth: 28, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(model.busy || model.output.isEmpty)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 320, idealWidth: 340, minHeight: 340, idealHeight: 360)
            .onChange(of: model.start) { _, _ in model.update() }
            .onChange(of: model.increment) { _, _ in model.update() }
            .onChange(of: model.options) { _, _ in model.update() }
            .onChange(of: model.input) { _, _ in model.update() }
            .onDisappear { model.stop() }
    }
    private func settingField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title).font(.caption).frame(width: 56, alignment: .leading)
            TextField(title, text: text).textFieldStyle(.roundedBorder).accessibilityLabel(title)
        }
    }

}
struct TextCleanerView: View {
    @ObservedObject var model: TextTransformModel
    @State private var showsSettings = false
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("テキストクリーナー").font(.headline)
                Spacer()
                Button { showsSettings = true } label: {
                    Image(systemName: "gearshape").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("クリーナーの設定と説明")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 12) {
                            ThemeMenu()
                            Text("入力すると自動処理します。クリーニングは通常の空白と1つの改行を残し、改行コード・不可視文字・連続空行・箇条書きの改行を整理します。文字チェックは文字コードの自動判定ではありません。可視化は空白・改行・タブを記号で表示します。入力は最大1MiB。")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(12).frame(width: 280)
                    }
            }
            Picker("モード", selection: $model.cleanerMode) {
                ForEach(["クリーニング", "可視化", "文字チェック"], id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            TextEditor(text: $model.input).font(.system(.body, design: .monospaced))
                .frame(minHeight: 55, maxHeight: .infinity).accessibilityLabel("元のテキスト")
                .overlay(alignment: .topLeading) {
                    if model.input.isEmpty {
                        Text("元のテキスト").font(.caption).foregroundStyle(.secondary).padding(6).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
            ScrollView {
                Text(model.output.isEmpty ? (model.busy ? "処理中…" : "処理結果") : model.output)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(model.output.isEmpty ? Color.secondary : Color.primary)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }.frame(minHeight: 60, maxHeight: .infinity)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityLabel("処理結果")
            Text(model.busy ? "処理中…" : model.status.isEmpty ? model.count : model.status)
                .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Button { model.input = NSPasteboard.general.string(forType: .string) ?? "" } label: {
                    Image(systemName: "doc.on.clipboard").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("貼り付け")
                Button { model.input = "" } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28).contentShape(Rectangle())
                }.accessibilityLabel("入力をクリア").disabled(model.input.isEmpty)
                Spacer(minLength: 0)
                Button { model.update() } label: { Text("実行").frame(minWidth: 28, minHeight: 28) }
                    .buttonStyle(.borderedProminent).disabled(model.busy)
                Button { model.copy() } label: { Text("コピー").frame(minHeight: 28) }
                    .disabled(model.busy || model.output.isEmpty)
            }
        }.padding(10).controlSize(.regular)
            .frame(minWidth: 320, idealWidth: 340, minHeight: 340, idealHeight: 360)
            .onChange(of: model.cleanerMode) { _, _ in model.update() }
            .onChange(of: model.input) { _, _ in model.update() }
            .onDisappear { model.stop() }
    }
}
struct TextToolActions: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: TextTransformModel
    var tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Button { model.paste() } label: { Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard") }
            Button("クリア") { model.input = ""; model.update() }.disabled(model.input.isEmpty)
            if model.busy { ProgressView().controlSize(.small) }
            Text(model.status.isEmpty ? model.count : model.status).font(theme.font(11)).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(ThemeButtonStyle(prominent: true)).controlSize(.large).disabled(model.output.isEmpty || model.busy)
        }
    }
}
struct ClipboardFormatterView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: ClipboardFormatterModel
    var embedded = false
    private let tint = Color.teal
    var body: some View {
        Group {
            if embedded { content }
            else { ToolPage("クリップボード整形", subtitle: "表から必要な列を選んで、次の作業に合う形式へ。", symbol: "clipboard", tint: tint) { content } }
        }.frame(minWidth: 1000, minHeight: embedded ? 0 : 850)
        .onChange(of: model.input) { _, _ in model.parse() }.onChange(of: model.options) { _, _ in model.updateOutput() }.onChange(of: model.columns) { _, _ in model.updateOutput() }.onDisappear { if !embedded { model.stop() } }
    }
    private var content: some View {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 16) {
                        TextPane(title: "貼り付けるテキスト・表", symbol: "doc.on.clipboard", text: $model.input, tint: tint).frame(height: 220)
                        ToolCard {
                            VStack(alignment: .leading, spacing: 12) {
                                ToolSectionLabel(title: "整える", symbol: "wand.and.stars")
                                Toggle("前後の空白を削除", isOn: $model.options.trim)
                                Toggle("空行を削除", isOn: $model.options.removeEmpty)
                                Toggle("重複行を削除", isOn: $model.options.removeDuplicates)
                                Toggle("連続スペースを1つに", isOn: $model.options.collapseSpaces)
                                Button { model.input = NSPasteboard.general.string(forType: .string) ?? ""; model.parse() } label: { Label("貼り付け", systemImage: "doc.on.clipboard") }
                            }.toggleStyle(ThemeToggleStyle())
                        }.frame(width: 235)
                    }
                    if !model.table.rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { ToolSectionLabel(title: "出力する列", symbol: "tablecells"); Text(model.detected).font(theme.font(11)).foregroundStyle(.secondary); Spacer() }
                            ScrollView(.horizontal) {
                                HStack { ForEach(0..<model.table.width, id: \.self) { column in
                                    Toggle("列 \(column + 1)", isOn: Binding(get: { model.columns.contains(column) }, set: { if $0 { model.columns.insert(column) } else { model.columns.remove(column) } })).toggleStyle(ThemeToggleStyle(asButton: true))
                                } }
                            }
                            CSVGrid(model: model.table).frame(height: 180).classicBevel(sunken: true)
                            Text("セルをダブルクリックで編集。列の順序は元の順を維持します。").font(theme.font(10)).foregroundStyle(.tertiary)
                        }
                    }
                    HStack(spacing: 20) {
                        ThemePicker("出力形式", selection: $model.options.format, options: ClipboardTable.Format.allCases.map { ($0, $0.rawValue) }).frame(width: 290)
                        ThemePicker("囲み文字", selection: $model.options.quote, options: ClipboardTable.Quote.allCases.map { ($0, $0.rawValue) }).frame(width: 220).disabled([.markdown, .sqlIn, .sqlValues].contains(model.options.format))
                        Spacer()
                        Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(ThemeButtonStyle(prominent: true)).disabled(model.output.isEmpty || model.busy)
                    }
                    TextPane(title: "変換結果", symbol: "text.badge.checkmark", text: $model.output, editable: false, tint: tint).frame(height: 220)
                    HStack { if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(theme.font(11)).foregroundStyle(.secondary); Spacer(); Text("\(model.output.count) 文字").font(.caption.monospacedDigit()).foregroundStyle(.tertiary) }
                    ToolFootnote(text: "タブ→カンマ→スペース→1列の順で自動判定。SQLは文字列を生成するだけです。囲みなしのカンマ区切りはCSVの自動エスケープを行いません。入力は最大1MiB。")
                }.padding(24)
            }
    }
}
