import SwiftUI
import UniformTypeIdentifiers

@MainActor final class DirectoryTreeModel: ObservableObject {
    @Published private(set) var nodes: [DirectoryTree.Node] = []
    @Published var selected: UUID?
    @Published var error: String?
    @Published private(set) var undoStack: [[DirectoryTree.Node]] = []
    @Published private(set) var redoStack: [[DirectoryTree.Node]] = []
    private let defaults: UserDefaults
    private let key = "tools.directoryTree.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let text = defaults.string(forKey: key) {
            do { nodes = try DirectoryTree.decode(text) } catch { self.error = "保存データを読み込めませんでした。元データは保持しています: " + error.localizedDescription }
        }
    }
    var index: Int? { nodes.firstIndex { $0.id == selected } }
    func commit(_ next: [DirectoryTree.Node]) {
        do {
            try DirectoryTree.validate(next)
            let encoded = try DirectoryTree.encode(next)
            undoStack.append(nodes); undoStack = Array(undoStack.suffix(50)); redoStack = []
            nodes = next; defaults.set(encoded, forKey: key); error = nil
            if !nodes.contains(where: { $0.id == selected }) { selected = nodes.last?.id }
        } catch { self.error = error.localizedDescription }
    }
    func history(redo: Bool) {
        let stack = redo ? redoStack : undoStack
        guard let next = stack.last else { return }
        do {
            let encoded = try DirectoryTree.encode(next)
            if redo { redoStack.removeLast(); undoStack.append(nodes) } else { undoStack.removeLast(); redoStack.append(nodes) }
            nodes = next; defaults.set(encoded, forKey: key); selected = nil; error = nil
        } catch { self.error = error.localizedDescription }
    }
    private func end(_ i: Int) -> Int { (i + 1..<nodes.count).first { nodes[$0].depth <= nodes[i].depth } ?? nodes.count }
    func add(child: Bool, name: String, folder: Bool) {
        var next = nodes
        let parent = index
        if child && (parent == nil || !nodes[parent!].folder) { error = "子を追加するフォルダを選択してください。"; return }
        let node = DirectoryTree.Node(name: name, folder: folder, depth: child ? nodes[parent!].depth + 1 : 0)
        next.insert(node, at: child ? end(parent!) : next.count); commit(next)
        if error == nil { selected = node.id }
    }
    func rename(_ name: String, folder: Bool) {
        guard let i = index else { return }; var next = nodes
        if !folder && end(i) > i + 1 { error = "子があるフォルダはファイルに変更できません。"; return }
        next[i].name = name; next[i].folder = folder; commit(next)
    }
    func remove() { guard let i = index else { return }; var next = nodes; next.removeSubrange(i..<end(i)); commit(next) }
    func indent(_ delta: Int) {
        guard let i = index else { return }; var next = nodes
        if delta > 0 {
            guard i > 0, let sibling = nodes[..<i].lastIndex(where: { $0.depth <= nodes[i].depth }), nodes[sibling].depth == nodes[i].depth, nodes[sibling].folder else { error = "直前に同じ階層のフォルダが必要です。"; return }
        } else if nodes[i].depth == 0 { return }
        let stop = end(i)
        if delta < 0 {
            // Outdenting also moves the subtree after its former parent's remaining children.
            guard let parent = nodes[..<i].lastIndex(where: { $0.depth == nodes[i].depth - 1 }) else { return }
            let parentEnd = end(parent)
            var block = Array(next[i..<stop]); for j in block.indices { block[j].depth -= 1 }
            next.removeSubrange(i..<stop); next.insert(contentsOf: block, at: parentEnd - block.count)
        } else { for j in i..<stop { next[j].depth += 1 } }
        commit(next)
    }
    func move(_ down: Bool) {
        guard let i = index else { return }; let stop = end(i); var next = nodes
        let block = Array(nodes[i..<stop])
        if down {
            guard stop < nodes.count, nodes[stop].depth == nodes[i].depth else { return }
            let after = end(stop); next.removeSubrange(i..<stop); next.insert(contentsOf: block, at: after - block.count)
        } else {
            guard let previous = nodes[..<i].lastIndex(where: { $0.depth <= nodes[i].depth }), nodes[previous].depth == nodes[i].depth else { return }
            next.removeSubrange(i..<stop); next.insert(contentsOf: block, at: previous)
        }; commit(next)
    }
    func importText(_ text: String, json: Bool) { do { let next = try (json ? DirectoryTree.decode(text) : DirectoryTree.parse(text)); commit(next) } catch { self.error = error.localizedDescription } }
    func exportJSON() {
        do {
            let text = try DirectoryTree.encode(nodes), panel = NSSavePanel()
            panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "directory-tree.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try text.write(to: url, atomically: true, encoding: .utf8); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct DirectoryTreeView: View {
    @StateObject private var model = DirectoryTreeModel()
    @State private var name = "new-folder", folder = true
    @State private var format = DirectoryTree.Format.tree
    @State private var style = DirectoryTree.Style()
    @State private var importText = "", importJSON = false, importing = false
    @State private var confirmClear = false
    private var preview: Result<[(String, String)], Error> { Result { [("プレビュー", try DirectoryTree.render(model.nodes, format: format, style: style))] } }
    var body: some View {
        ToolPage("ディレクトリツリー作成", subtitle: "構成を編集・複数形式へ出力・JSON保存", symbol: "folder.badge.gearshape", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 16) {
                ToolCard { VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("元に戻す") { model.history(redo: false) }.disabled(model.undoStack.isEmpty)
                        Button("やり直す") { model.history(redo: true) }.disabled(model.redoStack.isEmpty)
                        Spacer(); Button("サンプルに置換") { model.commit(DirectoryTree.sample) }; Button("全削除") { confirmClear = true }
                    }
                    UtilityField(title: "名前", text: $name); Toggle("フォルダ", isOn: $folder)
                    HStack {
                        Button("ルートへ追加") { model.add(child: false, name: name, folder: folder) }
                        Button("選択フォルダへ追加") { model.add(child: true, name: name, folder: folder) }
                        Button("選択項目を更新") { model.rename(name, folder: folder) }.disabled(model.index == nil)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.nodes) { node in
                            Button {
                                model.selected = node.id; name = node.name; folder = node.folder
                            } label: {
                                HStack { Text(String(repeating: "  ", count: node.depth) + (node.folder ? "📁 " : "📄 ") + node.name); Spacer(); if model.selected == node.id { Image(systemName: "checkmark.circle.fill") } }.frame(maxWidth: .infinity, alignment: .leading).padding(5)
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Button("上へ") { model.move(false) }; Button("下へ") { model.move(true) }
                        Button("階層を下げる") { model.indent(1) }; Button("階層を上げる") { model.indent(-1) }
                        Button("選択項目と子を削除") { model.remove() }
                    }.disabled(model.index == nil)
                } }
                if let error = model.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                ThemePicker("出力形式", selection: $format, options: DirectoryTree.Format.allCases.map { ($0, $0.rawValue) })
                if format == .custom {
                    ToolCard { VStack(alignment: .leading, spacing: 10) {
                        UtilityField(title: "フォルダ記号", text: $style.folder); UtilityField(title: "ファイル記号", text: $style.file)
                        UtilityField(title: "階層記号", text: $style.branch); UtilityField(title: "箇条書き記号", text: $style.bullet)
                        Stepper("インデント幅: \(style.width)", value: $style.width, in: 1...8)
                        Toggle("アイコンを表示", isOn: $style.emoji)
                    } }
                }
                Toggle("フォルダ末尾に/を付ける", isOn: $style.slash)
                UtilityResult(result: preview)
                HStack {
                    Button("テキスト読込") { importJSON = false; importing = true }
                    Button("JSON読込") { importJSON = true; importing = true }
                    Button("JSONをファイル保存") { model.exportJSON() }
                }
                if importing {
                    ToolCard { VStack(alignment: .leading, spacing: 12) {
                        Text(importJSON ? "このツールで保存したJSONを貼り付け" : "2スペース字下げ、または標準Tree/ASCIIを貼り付け。フォルダ末尾は/。")
                        TextEditor(text: $importText).font(.system(.body, design: .monospaced)).frame(height: 160)
                        HStack { Button("現在の構成を置換して読込") { model.importText(importText, json: importJSON); if model.error == nil { importing = false } }; Button("キャンセル") { importing = false } }
                    } }
                }
                ToolFootnote(text: "構成はローカル自動保存。最大1,000項目・深さ20、Undo/Redoは50世代。移動ボタンは子を含めて並べ替えます。実際のファイル操作は行いません。JSONは本ツール固有形式です。")
            }.padding(24) }
        }.frame(minWidth: 950, minHeight: 800)
            .confirmationDialog("構成をすべて削除しますか？", isPresented: $confirmClear) { Button("削除", role: .destructive) { model.commit([]) } }
    }
}
