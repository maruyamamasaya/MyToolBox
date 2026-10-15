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
    @Published var start = "1"
    @Published var increment = "1"
    @Published var options = SequentialText.Options()
    private var task: Task<Void, Never>?
    let cleaner: Bool
    init(cleaner: Bool = false) { self.cleaner = cleaner }
    func update() {
        task?.cancel(); status = ""; busy = true
        let input = input; var settings = options
        let start = Int64(start), increment = Int64(increment)
        task = Task {
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                if cleaner {
                    let result = try await TextProcessor.shared.clean(input)
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
    @Binding var text: String
    var editable = true
    var label: String
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
    var title: String
    var symbol: String
    @Binding var text: String
    var editable = true
    var tint: Color
    var highlights: [NSRange] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { ToolSectionLabel(title: title, symbol: symbol); Spacer(); Text("\(text.count) 文字").font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary) }.padding(13)
            Divider().opacity(0.5)
            ToolTextEditor(text: $text, editable: editable, label: title, highlights: highlights).frame(minHeight: 120, maxHeight: .infinity)
        }.background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.18)))
    }
}
struct SequentialTextView: View {
    @ObservedObject var model: TextTransformModel
    private let tint = Color.indigo
    var body: some View {
        ToolPage("連番テキスト生成", subtitle: "行に番号を添えて、使いやすいリストへ。", symbol: "list.number", tint: tint) {
            VStack(spacing: 16) {
                ToolCard {
                    VStack(alignment: .leading, spacing: 14) {
                        ToolSectionLabel(title: "連番のルール", symbol: "slider.horizontal.3")
                        HStack(spacing: 18) {
                            LabeledContent("開始") { TextField("1", text: $model.start).frame(width: 80).accessibilityLabel("開始番号") }
                            LabeledContent("増加数") { TextField("1", text: $model.increment).frame(width: 80) }
                            Picker("桁数", selection: $model.options.digits) { ForEach(1..<9) { Text(String(repeating: "0", count: $0 - 1) + "1").tag($0) } }.frame(width: 140)
                            Picker("位置", selection: $model.options.atEnd) { Text("行の先頭").tag(false); Text("行の末尾").tag(true) }.frame(width: 160)
                        }
                        HStack(spacing: 18) {
                            TextField("前に付ける文字（item- など）", text: $model.options.prefix)
                            TextField("区切り文字", text: $model.options.separator).frame(width: 130).accessibilityLabel("区切り文字")
                            TextField("後ろに付ける文字", text: $model.options.suffix)
                            Toggle("空行も連番対象", isOn: $model.options.numberEmptyLines).toggleStyle(.checkbox)
                        }.textFieldStyle(.roundedBorder)
                    }
                }
                HStack(spacing: 16) {
                    TextPane(title: "入力テキスト", symbol: "text.alignleft", text: $model.input, tint: tint)
                    TextPane(title: "生成結果", symbol: "list.number", text: $model.output, editable: false, tint: tint)
                }
                TextToolActions(model: model, tint: tint)
                ToolFootnote(text: "開始番号・増加数は負の整数や0も指定できます。空行を無視する場合は番号を消費しません。入力は最大1MiB・20,000行。")
            }.padding(24)
        }.frame(minWidth: 940, minHeight: 710)
        .onChange(of: model.input) { _, _ in model.update() }.onChange(of: model.start) { _, _ in model.update() }.onChange(of: model.increment) { _, _ in model.update() }.onChange(of: model.options) { _, _ in model.update() }
        .onDisappear { model.stop() }
    }
}
struct TextCleanerView: View {
    @ObservedObject var model: TextTransformModel
    private let tint = Color.pink
    var body: some View {
        ToolPage("テキストクリーナー", subtitle: "貼り付けた文章を、すっきり整える。", symbol: "sparkles", tint: tint) {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    ForEach(["プレーンテキスト", "不可視文字を除去", "連続空行を整理", "箇条書きの改行を結合"], id: \.self) { Text($0).font(.system(size: 11, weight: .medium)).padding(.horizontal, 11).padding(.vertical, 8).background(tint.opacity(0.09), in: Capsule()) }
                    Spacer()
                }
                HStack(spacing: 16) {
                    TextPane(title: "元のテキスト", symbol: "text.alignleft", text: $model.input, tint: tint)
                    TextPane(title: "クリーンなテキスト", symbol: "sparkles", text: $model.output, editable: false, tint: tint)
                }
                TextToolActions(model: model, tint: tint)
                ToolCard {
                    ToolFootnote(text: "通常の空白と1つの改行は残します。改行コードを統一し、ノーブレークスペース・ゼロ幅スペース・BOMを整理。単独の「・」は次の本文とつなぎます。元の文章を左側で確認できます。")
                }
            }.padding(24)
        }.frame(minWidth: 940, minHeight: 670).onChange(of: model.input) { _, _ in model.update() }.onDisappear { model.stop() }
    }
}
struct TextToolActions: View {
    @ObservedObject var model: TextTransformModel
    var tint: Color
    var body: some View {
        HStack(spacing: 12) {
            Button { model.paste() } label: { Label("クリップボードから貼り付け", systemImage: "doc.on.clipboard") }
            Button("クリア") { model.input = ""; model.update() }.disabled(model.input.isEmpty)
            if model.busy { ProgressView().controlSize(.small) }
            Text(model.status.isEmpty ? model.count : model.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.output.isEmpty || model.busy)
        }
    }
}
struct ClipboardFormatterView: View {
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
                            }.toggleStyle(.checkbox)
                        }.frame(width: 235)
                    }
                    if !model.table.rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { ToolSectionLabel(title: "出力する列", symbol: "tablecells"); Text(model.detected).font(.caption).foregroundStyle(.secondary); Spacer() }
                            ScrollView(.horizontal) {
                                HStack { ForEach(0..<model.table.width, id: \.self) { column in
                                    Toggle("列 \(column + 1)", isOn: Binding(get: { model.columns.contains(column) }, set: { if $0 { model.columns.insert(column) } else { model.columns.remove(column) } })).toggleStyle(.button)
                                } }
                            }
                            CSVGrid(model: model.table).frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("セルをダブルクリックで編集。列の順序は元の順を維持します。").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    HStack(spacing: 20) {
                        Picker("出力形式", selection: $model.options.format) { ForEach(ClipboardTable.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 290)
                        Picker("囲み文字", selection: $model.options.quote) { ForEach(ClipboardTable.Quote.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 220).disabled([.markdown, .sqlIn, .sqlValues].contains(model.options.format))
                        Spacer()
                        Button { model.copy() } label: { Label("結果をコピー", systemImage: "doc.on.doc") }.buttonStyle(.borderedProminent).disabled(model.output.isEmpty || model.busy)
                    }
                    TextPane(title: "変換結果", symbol: "text.badge.checkmark", text: $model.output, editable: false, tint: tint).frame(height: 220)
                    HStack { if model.busy { ProgressView().controlSize(.small) }; Text(model.status).font(.caption).foregroundStyle(.secondary); Spacer(); Text("\(model.output.count) 文字").font(.caption.monospacedDigit()).foregroundStyle(.tertiary) }
                    ToolFootnote(text: "タブ→カンマ→スペース→1列の順で自動判定。SQLは文字列を生成するだけです。囲みなしのカンマ区切りはCSVの自動エスケープを行いません。入力は最大1MiB。")
                }.padding(24)
            }
    }
}
