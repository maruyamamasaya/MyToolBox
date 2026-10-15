import SwiftUI
import UniformTypeIdentifiers

@MainActor final class LocalMemoModel: ObservableObject {
    @Published private(set) var archive = LocalMemoArchive()
    @Published var selectedID: String?
    @Published var status = ""
    @Published private(set) var writable = false
    private var file: URL?
    private var dirty = false
    var notes: [LocalMemoNote] { archive.notes.sorted { (LocalMemoArchive.date($0.updatedAt) ?? .distantPast) > (LocalMemoArchive.date($1.updatedAt) ?? .distantPast) } }
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
    @ObservedObject var model: LocalMemoModel
    @State private var showsHistory = false
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack {
                    Button("新しいメモ", systemImage: "plus") { model.add() }.disabled(!model.writable)
                    Text("\(model.notes.count)件").foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("履歴") { showsHistory = true }
                        Button("JSONを書き出す") { model.exportJSON() }
                        Button("JSONから復元") { model.importJSON() }.disabled(!model.writable)
                        Divider()
                        Button("このメモを削除", role: .destructive) { model.delete() }.disabled(model.selected == nil || !model.writable)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("メモの操作")
                }
                HStack(alignment: .top, spacing: 16) {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(model.notes) { note in
                                Button { model.selectedID = note.id } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(note.displayTitle).lineLimit(2)
                                        Text(LocalMemoArchive.date(note.updatedAt)?.formatted(date: .abbreviated, time: .shortened) ?? note.updatedAt).font(.caption).foregroundStyle(.secondary)
                                    }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(model.selectedID == note.id ? Color.yellow.opacity(0.18) : Color.clear)
                                }.buttonStyle(.plain).accessibilityValue(model.selectedID == note.id ? "選択中" : "未選択")
                            }
                        }
                    }.frame(width: 180)
                    ToolCard {
                        if model.selected != nil {
                            VStack(spacing: 12) {
                                TextEditor(text: Binding(get: { model.selected?.content ?? "" }, set: { model.update(content: $0) }))
                                    .font(.body).accessibilityLabel("メモ本文")
                            }.disabled(!model.writable)
                        } else {
                            Text("メモがありません。「新しいメモ」から作成してください。").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                HStack {
                    Text(model.status).font(.caption).textSelection(.enabled)
                    Spacer()
                    if !model.writable { Button("再読み込み") { model.load() } }
                    if model.writable && model.status.contains("保存できません") {
                        Button("保存を再試行") { model.save() }
                    }
                }
            }.padding(14)
        }.frame(minWidth: 600, minHeight: 420)
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
