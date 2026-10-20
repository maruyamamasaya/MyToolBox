import SwiftUI
import UniformTypeIdentifiers

@MainActor final class LocalMemoModel: ObservableObject {
    @Published private(set) var archive = LocalMemoArchive()
    @Published var selectedID: String?
    @Published var status = ""
    @Published private(set) var writable = false
    private var file: URL?
    private var dirty = false
    var notes: [LocalMemoNote] { archive.notes.sorted { (LocalMemoArchive.date($0.createdAt) ?? .distantPast) > (LocalMemoArchive.date($1.createdAt) ?? .distantPast) } }
    var selected: LocalMemoNote? { archive.notes.first { $0.id == selectedID } }
    private let storageDirectory: URL?
    init(storageDirectory: URL? = nil) { self.storageDirectory = storageDirectory; load() }
    func load() {
        do {
            let directory = try storageDirectory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("MyToolBox/LocalMemo", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("memo-v1.json")
            let exists = FileManager.default.fileExists(atPath: url.path)
            var loaded = LocalMemoArchive()
            if exists {
                loaded = try JSONDecoder().decode(LocalMemoArchive.self, from: Data(contentsOf: url))
                guard loaded.version == 1 else { throw LocalMemoArchive.MemoError.version }
                try LocalMemoArchive.validate(loaded.notes)
                for snapshot in loaded.history { try LocalMemoArchive.validate(snapshot.notes) }
                loaded.history = Array(loaded.history.prefix(5))
            }
            archive = loaded; file = url; writable = true; dirty = false
            selectedID = notes.first?.id; status = "このMacに保存済み"
            if !exists { add() }
        } catch { writable = false; status = "保存データを読み込めません。元ファイルは保持しています: \(error.localizedDescription)" }
    }
    func add() {
        guard writable else { return }
        let note = LocalMemoNote(); archive.notes.insert(note, at: 0); selectedID = note.id; dirty = true; save(forceSnapshot: true)
    }
    func update(title: String? = nil, content: String? = nil) {
        guard writable, let index = archive.notes.firstIndex(where: { $0.id == selectedID }) else { return }
        guard title.map({ String($0.prefix(120)) != archive.notes[index].title }) == true || content.map({ $0 != archive.notes[index].content }) == true else { return }
        if let title { archive.notes[index].title = String(title.prefix(120)) }
        if let content { archive.notes[index].content = content }
        archive.notes[index].updatedAt = LocalMemoArchive.timestamp(Date()); dirty = true; save()
    }
    @discardableResult func save(forceSnapshot: Bool = false) -> Bool {
        guard writable, let file else { return false }
        var next = archive
        let last = next.history.first.flatMap { LocalMemoArchive.date($0.createdAt) } ?? .distantPast
        if forceSnapshot || dirty && Date().timeIntervalSince(last) >= 60 { next.snapshot() }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(next).write(to: file, options: .atomic)
            archive = next; dirty = false; status = "このMacに保存済み · \(Date().formatted(date: .omitted, time: .shortened))"; return true
        } catch { status = "保存できませんでした。JSON書き出しで退避できます: \(error.localizedDescription)"; return false }
    }
    func confirm(_ message: String) -> Bool {
        let alert = NSAlert(); alert.messageText = message; alert.informativeText = "実行前のメモは履歴に保存します。"
        alert.addButton(withTitle: "実行"); alert.addButton(withTitle: "キャンセル")
        return alert.runModal() == .alertFirstButtonReturn
    }
    func replace(_ notes: [LocalMemoNote]) {
        guard writable, save(forceSnapshot: true) else { return }
        // Preserve the pre-operation snapshot; the next edit creates the next generation.
        archive.notes = notes; selectedID = self.notes.first?.id; dirty = true; save()
    }
    func delete() {
        guard let selected, confirm("「\(selected.displayTitle)」を削除しますか？") else { return }
        replace(archive.notes.filter { $0.id != selected.id })
    }
    func restore(_ snapshot: LocalMemoSnapshot) {
        guard confirm("現在のメモを選択した履歴で置き換えますか？") else { return }
        replace(snapshot.notes)
    }
    func openText() {
        guard writable else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 20 * 1024 * 1024 else { throw LocalMemoArchive.MemoError.tooLarge }
            guard let text = String(data: data, encoding: .utf8) else { throw ToolFailure.message("UTF-8のテキストを選んでください") }
            add(); update(content: text.hasPrefix("\u{feff}") ? String(text.dropFirst()) : text)
        } catch { status = "開けませんでした: \(error.localizedDescription)" }
    }
    func exportText() {
        guard let selected else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]; panel.nameFieldStringValue = "memo.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try selected.content.write(to: url, atomically: true, encoding: .utf8); status = "テキストを書き出しました" }
        catch { status = "書き出せませんでした: \(error.localizedDescription)" }
    }
    func exportJSON() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "notes-backup-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try LocalMemoArchive.backup(notes).write(to: url, options: .atomic); status = "JSONを書き出しました" }
        catch { status = "書き出せませんでした: \(error.localizedDescription)" }
    }
    func importJSON() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 20 * 1024 * 1024 else { throw LocalMemoArchive.MemoError.tooLarge }
            let notes = try LocalMemoArchive.importNotes(Data(contentsOf: url))
            guard confirm("現在のメモをJSONの\(notes.count)件で置き換えますか？") else { return }
            replace(notes)
        } catch { status = "復元できませんでした: \(error.localizedDescription)" }
    }
    func canClose() -> Bool { !dirty || save() }
}

struct LocalMemoView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var model: LocalMemoModel
    @ObservedObject private var shortcut = ToolShortcutModel.memo
    @StateObject private var editor = QuickMemoEditorActions()
    @State private var showsHistory = false
    @State private var showsSettings = false
    @State private var showsList = false
    @State private var query = ""
    @AppStorage("tools.localMemo.fontSize.v1") private var fontSize = 15.0
    @AppStorage("tools.localMemo.wrap.v1") private var wraps = true
    private var visibleNotes: [LocalMemoNote] {
        model.notes.filter { query.isEmpty || $0.displayTitle.localizedStandardContains(query) || $0.content.localizedStandardContains(query) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { showsList.toggle() } label: { Image(systemName: "sidebar.left") }.help("メモ一覧を表示／非表示")
                    .accessibilityLabel("メモ一覧を表示／非表示")
                Button("新規", systemImage: "square.and.pencil") { model.add(); editor.focus() }
                    .keyboardShortcut("n").disabled(!model.writable)
                Spacer()
                Text(model.selected?.displayTitle ?? "クイックメモ").lineLimit(1).font(.headline)
                Spacer()
                Button { editor.find() } label: { Image(systemName: "magnifyingglass") }
                    .keyboardShortcut("f").help("本文を検索（⌘F）").accessibilityLabel("本文を検索")
                Button { showsSettings.toggle() } label: { Image(systemName: "textformat.size") }
                    .help("表示・ショートカット設定").accessibilityLabel("表示・ショートカット設定")
                    .popover(isPresented: $showsSettings) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("表示とショートカット").font(.headline)
                            HStack {
                                Text("文字サイズ")
                                Stepper("\(Int(fontSize))", value: $fontSize, in: 11...28)
                            }
                            Toggle("右端で折り返す", isOn: $wraps)
                            Toggle("ショートカットで開く", isOn: Binding(get: { shortcut.enabled }, set: { shortcut.setEnabled($0) }))
                            HStack {
                                Text("⌃⌥⌘")
                                Picker("キー", selection: Binding(get: { shortcut.key }, set: { shortcut.setKey($0) })) {
                                    ForEach(ToolShortcutModel.keys, id: \.name) { Text($0.name).tag($0.name) }
                                }
                            }
                            if !shortcut.error.isEmpty { Text(shortcut.error).foregroundStyle(.red) }
                        }.padding(20).frame(width: 300)
                    }
                Menu {
                    Button("テキストを開く…") { model.openText(); editor.focus() }.keyboardShortcut("o").disabled(!model.writable)
                    Button("テキストを書き出す…") { model.exportText() }.keyboardShortcut("s", modifiers: [.command, .shift]).disabled(model.selected == nil)
                    Divider()
                    Button("履歴") { showsHistory = true }
                    Button("JSONを書き出す") { model.exportJSON() }
                    Button("JSONから復元") { model.importJSON() }.disabled(!model.writable)
                    Divider()
                    Button("このメモを削除", role: .destructive) { model.delete() }.disabled(model.selected == nil || !model.writable)
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("メモの操作")
            }.buttonStyle(.plain).padding(12).background(theme.surface)
            Divider()
            HStack(spacing: 0) {
                if showsList {
                    VStack(spacing: 8) {
                        TextField("メモを検索", text: $query).textFieldStyle(ThemeTextFieldStyle()).padding(10)
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(visibleNotes) { note in
                                    Button { model.selectedID = note.id; editor.focus() } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(note.displayTitle).lineLimit(2)
                                            Text(LocalMemoArchive.date(note.updatedAt)?.formatted(date: .abbreviated, time: .shortened) ?? note.updatedAt).font(.caption).foregroundStyle(.secondary)
                                        }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                            .background(model.selectedID == note.id ? theme.accent.opacity(0.2) : Color.clear)
                                    }.buttonStyle(.plain).accessibilityValue(model.selectedID == note.id ? "選択中" : "未選択")
                                }
                                if visibleNotes.isEmpty { Text("該当するメモはありません").font(.caption).padding(10) }
                            }
                        }
                        Text("\(model.notes.count)件のメモ").font(.caption).foregroundStyle(.secondary).padding(8)
                    }.frame(width: 200).background(theme.surface)
                    Divider()
                }
                if let selected = model.selected {
                    QuickMemoTextEditor(noteID: selected.id, text: selected.content, writable: model.writable,
                        fontSize: fontSize, wraps: wraps, foreground: NSColor(theme.text), background: NSColor(theme.surfaceHigh),
                        actions: editor, onChange: { model.update(content: $0) })
                } else {
                    VStack(spacing: 12) {
                        Text(model.writable ? "メモがありません" : "メモを読み込めません")
                        Button("新しいメモ") { model.add(); editor.focus() }.disabled(!model.writable)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            HStack {
                Text(model.status).lineLimit(2).textSelection(.enabled)
                Spacer()
                Text("\(model.selected?.content.count ?? 0)文字")
                if !model.writable { Button("再読み込み") { model.load() } }
                if model.writable && model.status.contains("保存できません") { Button("保存を再試行") { model.save() } }
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.vertical, 7)
        }.frame(minWidth: 520, minHeight: 380)
            .onAppear { editor.focus() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
                if let window = note.object as? NSWindow, window.title == "クイックメモ" { editor.focus() }
            }
            .sheet(isPresented: $showsHistory) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("バックアップ履歴").font(.title2)
                    Text("最新5世代。編集中は最短1分ごと、追加・削除／復元前にも記録します。").font(.caption)
                    if model.archive.history.isEmpty { Text("履歴はまだありません") }
                    ForEach(model.archive.history) { snapshot in
                        HStack {
                            Text(LocalMemoArchive.date(snapshot.createdAt)?.formatted() ?? snapshot.createdAt)
                            Text("\(snapshot.notes.count)件"); Spacer()
                            Button("復元") { model.restore(snapshot); showsHistory = false }.disabled(!model.writable)
                        }
                    }
                    HStack { Spacer(); Button("閉じる") { showsHistory = false } }
                }.padding(24).frame(width: 620)
            }
    }
}

@MainActor final class QuickMemoEditorActions: ObservableObject {
    weak var textView: NSTextView?
    func focus() {
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.textView, view.isEditable else { return }
            view.window?.makeFirstResponder(view)
        }
    }
    func find() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        let item = NSMenuItem(); item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView.performFindPanelAction(item)
    }
}

/// Native plain-text editing keeps selection, undo and marked Japanese text in AppKit.
struct QuickMemoTextEditor: NSViewRepresentable {
    var noteID: String
    var text: String
    var writable: Bool
    var fontSize: Double
    var wraps: Bool
    var foreground: NSColor
    var background: NSColor
    var actions: QuickMemoEditorActions
    var onChange: (String) -> Void
    final class Coordinator: NSObject, NSTextViewDelegate {
        var owner: QuickMemoTextEditor
        var noteID: String
        var undoObservers: [NSObjectProtocol] = []
        deinit { undoObservers.forEach { NotificationCenter.default.removeObserver($0) } }
        init(_ owner: QuickMemoTextEditor) { self.owner = owner; noteID = owner.noteID }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            owner.onChange(view.string)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let view = NSTextView(frame: .zero)
        view.isRichText = false; view.allowsUndo = true
        view.usesFindBar = true; view.isIncrementalSearchingEnabled = true
        view.isAutomaticQuoteSubstitutionEnabled = false; view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isVerticallyResizable = true; view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainerInset = NSSize(width: 16, height: 14)
        view.delegate = context.coordinator
        for name in [Notification.Name.NSUndoManagerDidUndoChange, Notification.Name.NSUndoManagerDidRedoChange] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak coordinator = context.coordinator, weak view] note in
                guard let coordinator, let view, let manager = note.object as? UndoManager,
                      manager === view.undoManager else { return }
                coordinator.owner.onChange(view.string)
            }
            context.coordinator.undoObservers.append(observer)
        }
        view.setAccessibilityLabel("メモ本文")
        view.string = text
        scroll.documentView = view
        actions.textView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.owner = self
        actions.textView = view
        if context.coordinator.noteID != noteID {
            context.coordinator.noteID = noteID
            view.string = text; view.undoManager?.removeAllActions()
            view.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            actions.focus()
        } else if view.string != text && !view.hasMarkedText() {
            let selection = view.selectedRange()
            view.string = text
            view.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
            view.undoManager?.removeAllActions()
        }
        view.isEditable = writable; view.isSelectable = true
        let font = NSFont.monospacedSystemFont(ofSize: min(28, max(11, fontSize)), weight: .regular)
        if view.font != font || view.textColor != foreground {
            view.font = font; view.textColor = foreground
            view.typingAttributes = [.font: font, .foregroundColor: foreground]
        }
        view.insertionPointColor = foreground
        view.backgroundColor = background; scroll.backgroundColor = background
        view.minSize = scroll.contentSize
        if view.frame.width < scroll.contentSize.width || view.frame.height < scroll.contentSize.height {
            view.setFrameSize(NSSize(width: max(view.frame.width, scroll.contentSize.width), height: max(view.frame.height, scroll.contentSize.height)))
        }
        scroll.hasHorizontalScroller = !wraps
        view.isHorizontallyResizable = !wraps
        view.autoresizingMask = wraps ? [.width] : []
        view.textContainer?.widthTracksTextView = wraps
        view.textContainer?.containerSize = NSSize(width: wraps ? max(1, scroll.contentSize.width) : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if wraps { view.setFrameSize(NSSize(width: scroll.contentSize.width, height: max(scroll.contentSize.height, view.frame.height))) }
    }
}
