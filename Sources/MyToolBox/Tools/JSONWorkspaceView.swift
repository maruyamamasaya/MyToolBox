import SwiftUI
import UniformTypeIdentifiers

private actor JSONWorkspaceWorker {
    func read(_ url: URL) throws -> (String, JSONValue) {
        let text = try JSONWorkspaceFile.read(url)
        return (text, try JSONWorkspace.parse(text))
    }
    func save(_ text: String, to url: URL) throws { try JSONWorkspaceFile.save(text, to: url) }
    func parse(_ text: String) throws -> JSONValue { try JSONWorkspace.parse(text) }
}

@MainActor final class JSONWorkspaceModel: ObservableObject {
    @Published var text = ""
    @Published var root: JSONValue?
    @Published var error: String?
    @Published var selection: [Int] = []
    @Published var pending = false
    @Published var fileBusy = false
    @Published var fileStatus: String?
    @Published var fileError: String?
    @Published private(set) var fileURL: URL?
    private var savedText = ""
    var isDirty: Bool { text != savedText }
    private let worker = JSONWorkspaceWorker()

    func confirmClose(decideDiscard: (() -> Bool)? = nil) -> Bool {
        guard !fileBusy else { return false }
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard isDirty else { return true }
        if let decideDiscard { return decideDiscard() }
        let alert = NSAlert()
        alert.messageText = "未保存のJSONを破棄しますか？"
        alert.informativeText = "編集内容を残す場合はキャンセルして「JSONを保存…」を選んでください。"
        alert.addButton(withTitle: "キャンセル")
        alert.addButton(withTitle: "破棄する")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func open() {
        guard !fileBusy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }
    func load(_ url: URL) {
        guard !fileBusy, url.isFileURL, confirmClose() else { return }
        fileBusy = true; fileError = nil; fileStatus = "読み込み中…"
        Task {
            do {
                let (loaded, parsed) = try await worker.read(url)
                text = loaded; savedText = loaded; fileURL = url; selection = []
                root = parsed; error = nil; pending = false; fileStatus = "読み込みました：" + url.lastPathComponent
            } catch { fileError = error.localizedDescription; fileStatus = nil }
            fileBusy = false
        }
    }
    func save() {
        guard !fileBusy else { return }
        NSApp.keyWindow?.makeFirstResponder(nil)
        // Validate the actual current input, even if debounced analysis is pending.
        do { _ = try JSONWorkspace.parse(text) }
        catch { fileError = error.localizedDescription; return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "document.json"
        if let fileURL { panel.directoryURL = fileURL.deletingLastPathComponent() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        save(to: url)
    }
    func save(to url: URL) {
        guard !fileBusy else { return }
        let snapshot = text
        fileBusy = true; fileError = nil; fileStatus = "保存中…"
        Task {
            do {
                try await worker.save(snapshot, to: url)
                savedText = snapshot; fileURL = url; fileStatus = "保存しました：" + url.lastPathComponent
            } catch { fileError = error.localizedDescription; fileStatus = nil }
            fileBusy = false
        }
    }
    func refresh() async {
        let input = text
        root = nil; pending = true; error = nil
        do {
            try await Task.sleep(for: .milliseconds(180))
            let parsed = try await worker.parse(input)
            guard !Task.isCancelled, text == input else { return }
            root = parsed; pending = false
            if parsed.value(at: selection) == nil { selection = [] }
        } catch {
            guard !Task.isCancelled, text == input else { return }
            self.error = error.localizedDescription; pending = false
        }
    }
    func commit(_ value: JSONValue) {
        do {
            let next = value.encoded()
            _ = try JSONWorkspace.parse(next)
            text = next; root = value; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func edit(key: String, kind: String, value: String, add: Bool) {
        guard var root, let selected = root.value(at: selection) else { return }
        do {
            let new: JSONValue
            switch kind {
            case "string": new = .string(value)
            case "object": new = .object([])
            case "array": new = .array([])
            case "null": new = .null
            default:
                new = try JSONWorkspace.parse(value)
                guard new.typeName == kind else { throw JSONWorkspace.Failure(message: "\(kind)の値を入力してください。", line: 1, column: 1) }
            }
            if add {
                switch selected {
                case .object(var members):
                    guard !members.contains(where: { $0.key == key }) else { throw JSONWorkspace.Failure(message: "キーが重複しています。", line: 1, column: 1) }
                    members.append(.init(key, new)); root.replace(at: selection, with: .object(members))
                case .array(var values): values.append(new); root.replace(at: selection, with: .array(values))
                default: return
                }
            } else { root.replace(at: selection, with: new) }
            commit(root)
        } catch { self.error = error.localizedDescription }
    }
    func remove() {
        guard var root, !selection.isEmpty else { return }
        root.replace(at: selection, with: nil); selection.removeLast(); commit(root)
    }
    var pointer: String {
        guard let root else { return "" }
        var cursor = root; var parts: [String] = []
        for i in selection {
            switch cursor {
            case .object(let m) where m.indices.contains(i):
                parts.append(m[i].key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")); cursor = m[i].value
            case .array(let a) where a.indices.contains(i): parts.append(String(i)); cursor = a[i]
            default: return ""
            }
        }
        return parts.isEmpty ? "" : "/" + parts.joined(separator: "/")
    }
}

struct JSONWorkspaceView: View {
    @StateObject var model = JSONWorkspaceModel()
    @State var mode = "構造ビュー"
    @State private var targeted = false
    @State private var indent = 2
    @State private var key = ""
    @State private var kind = "string"
    @State private var value = ""
    @Environment(\.appTheme) private var theme
    private var selected: JSONValue? { model.root?.value(at: model.selection) }
    private func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    var body: some View {
        ToolPage("JSONツール", subtitle: "入力を共有して構造確認・整形・組み立て", symbol: "curlybraces", tint: .orange) {
            VStack(spacing: 12) {
                HStack {
                    Picker("モード", selection: $mode) { ForEach(["構造ビュー", "整形", "ビルダー"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                    Button("サンプル") { model.text = #"{"name":"MyToolBox","enabled":true,"items":[1,2,{"message":"こんにちは"}],"empty":null}"# }
                }
                HStack {
                    Button("JSONを開く…") { model.open() }
                    Button("JSONを保存…") { model.save() }.disabled(model.text.isEmpty)
                    Text(model.fileURL?.lastPathComponent ?? "新規JSON").lineLimit(1).truncationMode(.middle)
                    if model.isDirty { Text("未保存").foregroundStyle(.secondary) }
                    Spacer()
                    if model.fileBusy { ProgressView().controlSize(.small) }
                    Text("JSONファイルをここへドロップ").font(.caption).foregroundStyle(.secondary)
                }
                HSplitView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("共有JSON入力").font(.headline)
                            Spacer()
                            Button("貼り付け") { if let s = NSPasteboard.general.string(forType: .string) { model.text = s } }
                            Button("コピー") { copy(model.text) }.disabled(model.text.isEmpty)
                        }
                        JSONInputEditor(text: $model.text) { urls in
                            guard urls.count == 1, let url = urls.first, !model.fileBusy else { return false }
                            model.load(url); return true
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(Rectangle().stroke(theme.edge.opacity(0.25)))
                        Text("256 KiB・48階層・4,000要素まで。UTF-8・明示保存のみ。外部送信しません。")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(minWidth: 280).padding(.trailing, 8)
                    VStack(alignment: .leading, spacing: 10) {
                        if model.pending { ProgressView("解析中…") }
                        if mode == "整形" { formatter }
                        else {
                            HStack {
                                Text("構造").font(.headline)
                                Spacer()
                                Button("値をコピー") { if let selected { copy(selected.encoded()) } }.disabled(selected == nil)
                                Button("パスをコピー") { copy(model.pointer) }.disabled(selected == nil).help("JSON Pointer。ルートは空文字です。")
                            }
                            GeometryReader { geometry in
                                ScrollView([.vertical, .horizontal]) {
                                    VStack(alignment: .leading) {
                                        if let root = model.root {
                                            JSONBranch(value: root, name: "$", path: [], selection: $model.selection)
                                        } else { Text("JSONを入力してください").foregroundStyle(.secondary) }
                                    }.frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                                }
                            }
                            if let selected {
                                Text("選択: \(model.pointer.isEmpty ? "ルート" : model.pointer) · \(selected.typeName)").font(.caption).textSelection(.enabled)
                            }
                            if mode == "ビルダー" { builder }
                        }
                    }.frame(minWidth: 340).padding(.leading, 8)
                }
                if let fileError = model.fileError {
                    Text(fileError).font(.caption).foregroundStyle(.red).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                } else if let status = model.fileStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                else if model.root != nil { Text("有効なJSONです").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(20).disabled(model.fileBusy)
                .overlay(Rectangle().stroke(targeted ? Color.orange : .clear, lineWidth: 3))
        }.frame(minWidth: 840, idealWidth: 1000, minHeight: 650, idealHeight: 740)
            .contentShape(Rectangle())
            .dropDestination(for: URL.self) { urls, _ in
                guard urls.count == 1, let url = urls.first, url.isFileURL, !model.fileBusy else { return false }
                model.load(url); return true
            } isTargeted: { targeted = $0 }
            .task(id: model.text) { await model.refresh() }
            .onChange(of: model.selection) { _, _ in loadSelection() }
            .onChange(of: mode) { _, _ in loadSelection() }
    }
    private var formatter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("インデント", selection: $indent) { Text("2スペース").tag(2); Text("4スペース").tag(4); Text("圧縮").tag(0) }
            HStack {
                Button("入力に適用") { if let root = model.root { model.text = root.encoded(indent: indent == 0 ? nil : indent) } }.disabled(model.root == nil)
                Button("結果をコピー") { if let root = model.root { copy(root.encoded(indent: indent == 0 ? nil : indent)) } }.disabled(model.root == nil)
            }
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Text(model.root?.encoded(indent: indent == 0 ? nil : indent) ?? "")
                        .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
    }
    private var builder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Button("空のobjectから開始") { model.commit(.object([])); model.selection = [] }.disabled(!model.text.isEmpty)
                Button("空のarrayから開始") { model.commit(.array([])); model.selection = [] }.disabled(!model.text.isEmpty)
            }
            Text("ツリーで編集先を選択。子追加はobject／arrayに対して使えます。").font(.caption).foregroundStyle(.secondary)
            TextField("追加するキー（object用）", text: $key)
            Picker("型", selection: $kind) { ForEach(["string", "number", "boolean", "null", "object", "array"], id: \.self) { Text($0) } }
            TextField(kind == "boolean" ? "true または false" : "値（stringは引用符不要）", text: $value)
                .disabled(["object", "array", "null"].contains(kind))
            HStack {
                Button("子を追加") { model.edit(key: key, kind: kind, value: value, add: true) }.disabled(selected?.count == nil)
                Button("選択値を変更") { model.edit(key: key, kind: kind, value: value, add: false) }.disabled(selected == nil || selected?.count != nil)
                Button("削除") { model.remove() }.disabled(model.selection.isEmpty || selected == nil)
            }
            Text("コンテナ全体の置換・キー名変更は共有JSON入力で行えます。").font(.caption).foregroundStyle(.secondary)
        }.textFieldStyle(.roundedBorder)
    }
    private func loadSelection() {
        guard let selected else { return }; kind = selected.typeName
        if case .string(let s) = selected { value = s } else { value = selected.encoded(indent: nil) }
    }
}

private struct JSONBranch: View {
    let value: JSONValue
    let name: String
    let path: [Int]
    @Binding var selection: [Int]
    @State private var expanded = true
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if value.count != nil {
                    Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.down" : "chevron.right") }.buttonStyle(.plain).accessibilityLabel(expanded ? "折りたたむ" : "展開")
                }
                Button { selection = path } label: {
                    HStack {
                        Text(name).fontWeight(.semibold)
                        Text(value.typeName).foregroundStyle(.secondary)
                        if let count = value.count { Text("\(count)要素").foregroundStyle(.secondary) }
                        else { Text(String(value.encoded(indent: nil).prefix(100))).lineLimit(1) }
                    }.padding(4).background(selection == path ? Color.accentColor.opacity(0.18) : .clear)
                }.buttonStyle(.plain)
            }
            if expanded {
                switch value {
                case .object(let members):
                    ForEach(members.indices, id: \.self) { i in
                        JSONBranch(value: members[i].value, name: members[i].key, path: path + [i], selection: $selection).padding(.leading, 16)
                    }
                case .array(let values):
                    ForEach(values.indices, id: \.self) { i in
                        JSONBranch(value: values[i], name: "[\(i)]", path: path + [i], selection: $selection).padding(.leading, 16)
                    }
                default: EmptyView()
                }
            }
        }.font(.system(size: 12, design: .monospaced))
    }
}

/// NSTextView normally inserts a dropped file's path. Route file URLs to the
/// workspace instead, while preserving ordinary text editing and text drops.
private struct JSONInputEditor: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.isEnabled) private var enabled
    let onFiles: ([URL]) -> Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = JSONEditorScrollView()
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.drawsBackground = true; scroll.backgroundColor = .textBackgroundColor
        let editor = FileInputTextView()
        editor.isRichText = false; editor.allowsUndo = true
        editor.drawsBackground = true; editor.backgroundColor = .textBackgroundColor; editor.textColor = .textColor
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.textContainerInset = NSSize(width: 5, height: 5)
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.setAccessibilityLabel("共有JSON入力")
        editor.delegate = context.coordinator; editor.onFiles = onFiles
        editor.registerForDraggedTypes(editor.registeredDraggedTypes + [.fileURL])
        scroll.documentView = editor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? FileInputTextView else { return }
        editor.onFiles = onFiles; editor.isEditable = enabled
        if editor.string != text {
            let range = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(range.location, text.utf16.count), length: 0))
            editor.undoManager?.removeAllActions()
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONInputEditor
        init(_ parent: JSONInputEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}
private final class FileInputTextView: NSTextView {
    var onFiles: ([URL]) -> Bool = { _ in false }
    private func files(_ sender: NSDraggingInfo) -> [URL] {
        (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = files(sender)
        if !urls.isEmpty { return urls.count == 1 ? .copy : [] }
        return super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = files(sender)
        if !urls.isEmpty { return urls.count == 1 ? .copy : [] }
        return super.draggingUpdated(sender)
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = files(sender)
        if !urls.isEmpty { return urls.count == 1 }
        return super.prepareForDragOperation(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = files(sender)
        if !urls.isEmpty { return urls.count == 1 && onFiles(urls) }
        return super.performDragOperation(sender)
    }
}

private final class JSONEditorScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let editor = documentView as? NSTextView else { return }
        let size = contentSize
        editor.minSize = NSSize(width: 0, height: size.height)
        if editor.frame.width != size.width || editor.frame.height < size.height {
            editor.setFrameSize(NSSize(width: size.width, height: max(size.height, editor.frame.height)))
        }
    }
}
