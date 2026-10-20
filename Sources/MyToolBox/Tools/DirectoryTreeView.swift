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
    init(defaults: UserDefaults = IndependentTools.defaults) {
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
            undoStack.append(nodes); undoStack = Array(undoStack.suffix(60)); redoStack = []
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
        if child && parent == nil { error = "子を追加する項目を選択してください。"; return }
        if child, let parent { next[parent].folder = true; next[parent].open = true }
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
    var visibleNodes: [DirectoryTree.Node] {
        var hiddenBelow: Int?
        return nodes.filter { node in
            if let depth = hiddenBelow {
                if node.depth > depth { return false }
                hiddenBelow = nil
            }
            if node.folder && !node.open { hiddenBelow = node.depth }
            return true
        }
    }
    func toggle(_ id: UUID) {
        guard let i = nodes.firstIndex(where: { $0.id == id }) else { return }
        var next = nodes; next[i].open.toggle(); persistDisclosure(next)
    }
    func discloseAll(_ open: Bool) {
        var next = nodes; for i in next.indices where next[i].folder { next[i].open = open }; persistDisclosure(next)
    }
    private func persistDisclosure(_ next: [DirectoryTree.Node]) {
        do { let text = try DirectoryTree.encode(next); nodes = next; defaults.set(text, forKey: key); error = nil }
        catch { self.error = error.localizedDescription }
    }
    func hasChildren(_ id: UUID) -> Bool { guard let i = nodes.firstIndex(where: { $0.id == id }) else { return false }; return end(i) > i + 1 }
    enum Placement { case before, inside, after }
    func canDrop(source: UUID, target: UUID, placement: Placement) -> Bool {
        guard let i = nodes.firstIndex(where: { $0.id == source }), let j = nodes.firstIndex(where: { $0.id == target }), !(i..<end(i)).contains(j) else { return false }
        return placement != .inside || nodes[j].folder
    }
    func drop(source: UUID, target: UUID, placement: Placement) {
        guard canDrop(source: source, target: target, placement: placement), let i = nodes.firstIndex(where: { $0.id == source }) else { return }
        let stop = end(i); var next = nodes; var block = Array(next[i..<stop]); next.removeSubrange(i..<stop)
        guard let j = next.firstIndex(where: { $0.id == target }) else { return }
        let targetEnd = (j + 1..<next.count).first { next[$0].depth <= next[j].depth } ?? next.count
        let newDepth = next[j].depth + (placement == .inside ? 1 : 0), shift = newDepth - block[0].depth
        for k in block.indices { block[k].depth += shift }
        if placement == .inside { next[j].open = true }
        next.insert(contentsOf: block, at: placement == .before ? j : targetEnd)
        commit(next); if error == nil { selected = source }
    }
    func importText(_ text: String, json: Bool) { do { let next = try (json ? DirectoryTree.decode(text) : DirectoryTree.parse(text)); commit(next) } catch { self.error = error.localizedDescription } }
    func exportJSON() {
        do {
            let text = try DirectoryTree.encodeReference(nodes), panel = NSSavePanel()
            panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "directory-tree.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try text.write(to: url, atomically: true, encoding: .utf8); error = nil
        } catch { self.error = error.localizedDescription }
    }
}
struct DirectoryTreeView: View {
    @StateObject private var model: DirectoryTreeModel
    init(defaults: UserDefaults = IndependentTools.defaults) { _model = StateObject(wrappedValue: DirectoryTreeModel(defaults: defaults)) }
    @State private var name = "new-folder"
    @State private var folder = true
    @State private var format = DirectoryTree.Format.tree
    @State private var style = DirectoryTree.Style()
    @State private var importText = ""
    @State private var importJSON = false
    @State private var importing = false
    @State private var confirmClear = false
    @State private var deleting: UUID?
    @State private var confirmDelete = false
    @State private var dragged: UUID?
    @State private var dropTarget: UUID?
    @State private var placement = DirectoryTreeModel.Placement.inside
    private var preview: Result<[(String, String)], Error> { Result { [("プレビュー", try DirectoryTree.render(model.nodes, format: format, style: style))] } }
    var body: some View {
        ToolPage("ディレクトリツリー作成", subtitle: "構成を編集・複数形式へ出力・JSON保存", symbol: "folder.badge.gearshape", tint: .cyan) {
            ScrollView { VStack(alignment: .leading, spacing: 16) {
                ToolCard { VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("元に戻す") { model.history(redo: false) }.disabled(model.undoStack.isEmpty)
                        Button("やり直す") { model.history(redo: true) }.disabled(model.redoStack.isEmpty)
                        Button("全展開") { model.discloseAll(true) }; Button("全折りたたみ") { model.discloseAll(false) }
                        Spacer(); Button("サンプルに置換") { model.commit(DirectoryTree.sample) }; Button("全削除") { confirmClear = true }
                    }
                    UtilityField(title: "名前", text: $name); Toggle("フォルダ", isOn: $folder)
                    HStack {
                        Button("ルートへ追加") { model.add(child: false, name: name, folder: folder) }
                        Button("選択フォルダへ追加") { model.add(child: true, name: name, folder: folder) }
                        Button("選択項目を更新") { model.rename(name, folder: folder) }.disabled(model.index == nil)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(model.visibleNodes) { node in
                            DirectoryTreeRow(model: model, node: node, select: { name = node.name; folder = node.folder; model.selected = node.id }, remove: { requestRemove(node.id) })
                                .background(dropTarget == node.id && placement == .inside ? Color.cyan.opacity(0.15) : Color.clear)
                                .overlay(alignment: .top) { if dropTarget == node.id && placement == .before { Rectangle().fill(Color.cyan).frame(height: 2) } }
                                .overlay(alignment: .bottom) { if dropTarget == node.id && placement == .after { Rectangle().fill(Color.cyan).frame(height: 2) } }
                                .onDrag {
                                    dragged = node.id
                                    let provider = NSItemProvider()
                                    provider.registerDataRepresentation(forTypeIdentifier: UTType.directoryTreeNode.identifier, visibility: .ownProcess) { complete in
                                        complete(Data(node.id.uuidString.utf8), nil); return nil
                                    }
                                    return provider
                                }
                                .onDrop(of: [.directoryTreeNode], delegate: DirectoryTreeDrop(model: model, target: node.id, folder: node.folder, dragged: $dragged, highlighted: $dropTarget, placement: $placement))
                        }
                    }
                    HStack {
                        Button("上へ") { model.move(false) }; Button("下へ") { model.move(true) }
                        Button("階層を下げる") { model.indent(1) }; Button("階層を上げる") { model.indent(-1) }
                        Button("選択項目と子を削除") { if let id = model.selected { requestRemove(id) } }
                    }.disabled(model.index == nil)
                } }
                if let error = model.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                ThemePicker("出力形式", selection: $format, options: DirectoryTree.Format.allCases.map { ($0, $0.rawValue) })
                if format == .custom {
                    ToolCard { VStack(alignment: .leading, spacing: 10) {
                        UtilityField(title: "フォルダ記号", text: $style.folder); UtilityField(title: "ファイル記号", text: $style.file)
                        UtilityField(title: "階層記号", text: $style.branch); UtilityField(title: "矢印記号", text: $style.arrow); UtilityField(title: "箇条書き記号", text: $style.bullet)
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
                        Text(importJSON ? "参照Web版またはこのツールのJSONを貼り付け" : "標準Tree/ASCII、2スペース字下げ、箇条書き・Markdown・矢印に対応。フォルダ末尾は/。")
                        TextEditor(text: $importText).font(.system(.body, design: .monospaced)).frame(height: 160)
                        HStack { Button("現在の構成を置換して読込") { model.importText(importText, json: importJSON); if model.error == nil { importing = false } }; Button("キャンセル") { importing = false } }
                    } }
                }
                ToolFootnote(text: "構成はローカル自動保存。最大1,000項目・深さ50、Undo/Redoは60世代。ドラッグは行の上/中央/下で前/フォルダ内/後ろへ移動。実際のファイル操作は行いません。参照Web版の入れ子JSONと旧ローカルJSONを読み込めます。")
            }.padding(24) }
        }.frame(minWidth: 950, minHeight: 800)
            .confirmationDialog("構成をすべて削除しますか？", isPresented: $confirmClear) { Button("削除", role: .destructive) { model.commit([]) } }
            .confirmationDialog("選択項目とその中身を削除しますか？", isPresented: $confirmDelete) {
                Button("子を含めて削除", role: .destructive) { if let deleting { model.selected = deleting; model.remove() } }
            }
    }
    private func requestRemove(_ id: UUID) {
        if model.hasChildren(id) { deleting = id; confirmDelete = true }
        else { model.selected = id; model.remove() }
    }
}

private struct DirectoryTreeRow: View {
    @ObservedObject var model: DirectoryTreeModel
    let node: DirectoryTree.Node
    let select: () -> Void
    let remove: () -> Void
    @State private var editing = false
    @State private var draft = ""
    @FocusState private var nameFocused: Bool
    var body: some View {
        HStack(spacing: 6) {
            Text("⠿").foregroundStyle(.secondary)
            Button { model.toggle(node.id) } label: { Image(systemName: node.open ? "chevron.down" : "chevron.right").frame(width: 14) }.buttonStyle(.plain).disabled(!node.folder).opacity(node.folder ? 1 : 0)
            Text(node.folder ? (node.open ? "📂" : "📁") : "📄")
            if editing {
                TextField("名前", text: $draft).focused($nameFocused).onSubmit { finish() }.onExitCommand { editing = false }
                    .onChange(of: nameFocused) { _, focused in if !focused && editing { finish() } }
            } else {
                Button { select() } label: { Text(node.name).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain)
            }
            if model.selected == node.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(.cyan) }
            Button("＋📁") { select(); model.add(child: true, name: "new-folder", folder: true) }.help("子フォルダを追加")
            Button("＋📄") { select(); model.add(child: true, name: "new-file.txt", folder: false) }.help("子ファイルを追加")
            Button("✎") { select(); draft = node.name; editing = true; nameFocused = true }.help("名前を編集")
            Button("×", action: remove).help("削除")
        }.padding(.leading, CGFloat(node.depth * 16)).frame(height: 32).contentShape(Rectangle())
    }
    private func finish() { model.selected = node.id; model.rename(draft, folder: node.folder); editing = false }
}

@MainActor private struct DirectoryTreeDrop: @preconcurrency DropDelegate {
    let model: DirectoryTreeModel
    let target: UUID
    let folder: Bool
    @Binding var dragged: UUID?
    @Binding var highlighted: UUID?
    @Binding var placement: DirectoryTreeModel.Placement
    private func position(_ info: DropInfo) -> DirectoryTreeModel.Placement {
        if folder && info.location.y > 8 && info.location.y < 24 { return .inside }
        return info.location.y < 16 ? .before : .after
    }
    func validateDrop(info: DropInfo) -> Bool { guard let dragged else { return false }; return model.canDrop(source: dragged, target: target, placement: position(info)) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard validateDrop(info: info) else { highlighted = nil; return DropProposal(operation: .forbidden) }
        highlighted = target; placement = position(info); return DropProposal(operation: .move)
    }
    func dropExited(info: DropInfo) { if highlighted == target { highlighted = nil } }
    func performDrop(info: DropInfo) -> Bool {
        guard let source = dragged, validateDrop(info: info) else { return false }
        model.drop(source: source, target: target, placement: position(info)); dragged = nil; highlighted = nil
        return model.error == nil
    }
}

private extension UTType {
    static let directoryTreeNode = UTType(exportedAs: "local.MyToolBox.directoryTreeNode", conformingTo: .data)
}
