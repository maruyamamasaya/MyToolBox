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
        let newDepth = nodes[j].depth + (placement == .inside ? 1 : 0)
        let deepest = nodes[i..<end(i)].map(\.depth).max() ?? nodes[i].depth
        return (placement != .inside || nodes[j].folder) && newDepth + deepest - nodes[i].depth <= 50
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
    func dropToRoot(source: UUID) {
        guard let i = nodes.firstIndex(where: { $0.id == source }) else { return }
        let stop = end(i); var next = nodes; var block = Array(next[i..<stop])
        let depth = block[0].depth
        for index in block.indices { block[index].depth -= depth }
        next.removeSubrange(i..<stop); next.append(contentsOf: block)
        if next != nodes { commit(next) }
        if error == nil { selected = source }
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
    init(defaults: UserDefaults = IndependentTools.defaults, model: DirectoryTreeModel? = nil, initiallyExpanded: Bool = false, initialTab: Int = 0) {
        _model = StateObject(wrappedValue: model ?? DirectoryTreeModel(defaults: defaults))
        _expanded = State(initialValue: initiallyExpanded); _tab = State(initialValue: initialTab)
    }
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
    @State private var expanded: Bool
    @State private var tab: Int
    @State private var settings = false
    @State private var rootTargeted = false
    @State private var status = ""
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Label("ディレクトリツリー", systemImage: "folder").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            HStack {
                Button { model.history(redo: false) } label: { Image(systemName: "arrow.uturn.backward").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("元に戻す").disabled(model.undoStack.isEmpty)
                Button { model.history(redo: true) } label: { Image(systemName: "arrow.uturn.forward").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("やり直す").disabled(model.redoStack.isEmpty)
                Picker("表示", selection: $tab) { Text("編集").tag(0); Text("出力").tag(1) }.pickerStyle(.segmented)
                Menu {
                    Button("全展開") { model.discloseAll(true) }; Button("全折りたたみ") { model.discloseAll(false) }
                    Divider()
                    Button("テキスト読込") { importJSON = false; importing = true }
                    Button("JSON読込") { importJSON = true; importing = true }
                    Button("JSONをファイル保存") { model.exportJSON() }
                    Divider()
                    Button("サンプルに置換") { model.commit(DirectoryTree.sample) }
                    Button("全削除", role: .destructive) { confirmClear = true }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("ツリーの操作")
            }
            if tab == 0 { editor } else { outputPanel }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).lineLimit(3) }
            if !status.isEmpty { Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 440, height: 640)))
            .frame(minWidth: expanded ? 800 : 420, idealWidth: expanded ? 1100 : 440,
                   minHeight: expanded ? 600 : 560, idealHeight: expanded ? 850 : 640)
            .onAppear { syncSelection() }
            .onChange(of: model.selected) { _, _ in syncSelection() }
            .onChange(of: selectedName) { _, _ in syncSelection() }
            .popover(isPresented: $importing) { importPanel }
            .confirmationDialog("構成をすべて削除しますか？", isPresented: $confirmClear) { Button("削除", role: .destructive) { model.commit([]) } }
            .confirmationDialog("選択項目とその中身を削除しますか？", isPresented: $confirmDelete) {
                Button("子を含めて削除", role: .destructive) { if let deleting { model.selected = deleting; model.remove() } }
            }
    }
    private var editor: some View {
        VStack(spacing: 8) {
            HStack {
                TextField("名前", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("追加・更新する名前")
                Toggle("フォルダ", isOn: $folder).font(.caption)
                Button("更新") { model.rename(name, folder: folder) }.disabled(model.index == nil)
            }
            HStack {
                Button("ルートに追加", systemImage: "plus") { model.add(child: false, name: name, folder: folder) }
                Button("子を追加", systemImage: "plus") { model.add(child: true, name: name, folder: folder) }.disabled(model.index == nil)
                Spacer(minLength: 0)
                Text("\(model.nodes.count)件").font(.caption).foregroundStyle(.secondary)
            }
            Text("ドラッグ：上端＝前へ／中央＝フォルダ内／下端＝後ろへ").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.visibleNodes) { node in
                            DirectoryTreeRow(model: model, node: node, select: { name = node.name; folder = node.folder; model.selected = node.id }, remove: { requestRemove(node.id) })
                                .background(model.selected == node.id ? Color.cyan.opacity(0.08) : .clear)
                                .background(dropTarget == node.id && placement == .inside ? Color.cyan.opacity(0.2) : .clear)
                                .overlay(alignment: .top) { if dropTarget == node.id && placement == .before { Rectangle().fill(Color.cyan).frame(height: 3) } }
                                .overlay(alignment: .bottom) { if dropTarget == node.id && placement == .after { Rectangle().fill(Color.cyan).frame(height: 3) } }
                                .overlay(alignment: .trailing) {
                                    if dropTarget == node.id && placement == .inside { Text("中へ移動").font(.caption.bold()).padding(4).background(.regularMaterial) }
                                }
                                .onDrag {
                                    dragged = node.id; model.selected = node.id; name = node.name; folder = node.folder
                                    let provider = NSItemProvider()
                                    provider.registerDataRepresentation(forTypeIdentifier: UTType.directoryTreeNode.identifier, visibility: .ownProcess) { complete in
                                        complete(Data(node.id.uuidString.utf8), nil); return nil
                                    }
                                    return provider
                                }
                                .onDrop(of: [.directoryTreeNode], delegate: DirectoryTreeDrop(model: model, target: node.id, folder: node.folder, dragged: $dragged, highlighted: $dropTarget, placement: $placement))
                        }
                        if model.nodes.isEmpty { Text("名前を入力してルートに追加してください。").font(.caption).foregroundStyle(.secondary).padding(8) }
                        Label("ルートの末尾へ移動", systemImage: "arrow.turn.up.left")
                            .font(.caption).frame(maxWidth: .infinity, minHeight: 36)
                            .background(rootTargeted ? Color.cyan.opacity(0.25) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                            .onDrop(of: [.directoryTreeNode], delegate: DirectoryTreeRootDrop(model: model, dragged: $dragged, highlighted: $rootTargeted, rowTarget: $dropTarget))
                    }.padding(2)
                        .frame(width: max(geometry.size.width, CGFloat((model.visibleNodes.map(\.depth).max() ?? 0) * 14 + 320)), alignment: .leading)
                        .frame(minHeight: geometry.size.height, alignment: .topLeading)
                }
            }.background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                moveButton("上へ", "arrow.up") { model.move(false) }
                moveButton("下へ", "arrow.down") { model.move(true) }
                moveButton("階層を上げる", "decrease.indent") { model.indent(-1) }
                moveButton("階層を下げる", "increase.indent") { model.indent(1) }
                Spacer(minLength: 0)
                moveButton("選択項目を削除", "trash") { if let id = model.selected { requestRemove(id) } }
            }.disabled(model.index == nil)
        }
    }
    private func moveButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel(title).help(title)
    }
    private var outputPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("出力形式", selection: $format) { ForEach(DirectoryTree.Format.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                Button { settings.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 24, height: 24).contentShape(Rectangle()) }.accessibilityLabel("出力設定").popover(isPresented: $settings) { outputSettings }
            }
            GeometryReader { geometry in
                ScrollView([.vertical, .horizontal]) {
                    switch preview {
                    case .failure(let error): Text(error.localizedDescription).foregroundStyle(.red)
                    case .success(let rows):
                        Text(rows.first?.1 ?? "").font(.system(.body, design: .monospaced)).textSelection(.enabled).padding(8)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                    }
                }
            }.background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Button("コピー", systemImage: "doc.on.doc") {
                    if case .success(let rows) = preview { NSPasteboard.general.clearContents(); status = NSPasteboard.general.setString(rows.first?.1 ?? "", forType: .string) ? "コピーしました" : "コピーできませんでした" }
                }
                Button("JSON保存…") { model.exportJSON() }
                Spacer()
            }
        }
    }
    private var outputSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("フォルダ末尾に/を付ける", isOn: $style.slash)
                if format == .custom {
                    ForEach([("フォルダ記号", $style.folder), ("ファイル記号", $style.file), ("階層記号", $style.branch), ("矢印記号", $style.arrow), ("箇条書き記号", $style.bullet)], id: \.0) { title, binding in
                        TextField(title, text: binding).textFieldStyle(.roundedBorder).accessibilityLabel(title)
                    }
                    Stepper("インデント幅: \(style.width)", value: $style.width, in: 1...8)
                    Toggle("アイコンを表示", isOn: $style.emoji)
                }
                Text("構成はローカル自動保存。最大1,000項目・深さ50。Undo/Redoは60世代。ドラッグは子項目ごと移動します。実際のファイル操作は行いません。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }.frame(width: 320, height: format == .custom ? 340 : 170)
    }
    private var importPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(importJSON ? "JSONを貼り付けて読込" : "テキストを貼り付けて読込").font(.headline)
            Text(importJSON ? "参照Web版とこのツールのJSONに対応" : "Tree/ASCII・2スペース字下げ・箇条書き・Markdown・矢印に対応。フォルダ末尾は/。")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $importText).font(.system(.body, design: .monospaced)).frame(height: 160)
            HStack {
                Button("置換して読込") { model.importText(importText, json: importJSON); if model.error == nil { importing = false } }
                Button("キャンセル") { importing = false }
            }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.padding(16).frame(width: 340)
    }
    private var selectedName: String? { model.index.map { model.nodes[$0].name } }
    private func syncSelection() {
        guard let index = model.index else { return }
        name = model.nodes[index].name; folder = model.nodes[index].folder
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
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary).help("ドラッグして移動")
            Button { model.toggle(node.id) } label: { Image(systemName: node.open ? "chevron.down" : "chevron.right").frame(width: 24, height: 28) }.buttonStyle(.plain).disabled(!node.folder).opacity(node.folder ? 1 : 0)
            Image(systemName: node.folder ? (node.open ? "folder.fill" : "folder") : "doc").foregroundStyle(node.folder ? .cyan : .secondary)
            if editing {
                TextField("名前", text: $draft).focused($nameFocused).onSubmit { finish() }.onExitCommand { editing = false }
                    .onChange(of: nameFocused) { _, focused in if !focused && editing { finish() } }
            } else {
                Button { select() } label: { Text(node.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).frame(height: 36).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
            if model.selected == node.id {
                Button { select(); draft = node.name; editing = true; nameFocused = true } label: { Image(systemName: "pencil").frame(width: 24, height: 24) }.accessibilityLabel("名前を編集")
            }
        }.padding(.leading, CGFloat(node.depth * 14)).padding(.horizontal, 4).frame(height: 40).contentShape(Rectangle())
            .contextMenu {
                Button("子フォルダを追加") { select(); model.add(child: true, name: "new-folder", folder: true) }
                Button("子ファイルを追加") { select(); model.add(child: true, name: "new-file.txt", folder: false) }
                Button("名前を編集") { select(); draft = node.name; editing = true; nameFocused = true }
                Button("削除", role: .destructive, action: remove)
            }
    }
    private func finish() { model.selected = node.id; model.rename(draft, folder: node.folder); editing = false }
}

@MainActor struct DirectoryTreeDrop: @preconcurrency DropDelegate {
    let model: DirectoryTreeModel
    let target: UUID
    let folder: Bool
    @Binding var dragged: UUID?
    @Binding var highlighted: UUID?
    @Binding var placement: DirectoryTreeModel.Placement
    private func position(_ info: DropInfo) -> DirectoryTreeModel.Placement {
        Self.position(y: info.location.y, folder: folder)
    }
    static func position(y: CGFloat, folder: Bool) -> DirectoryTreeModel.Placement {
        if folder && y > 10 && y < 30 { return .inside }
        return y < 20 ? .before : .after
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

@MainActor private struct DirectoryTreeRootDrop: @preconcurrency DropDelegate {
    let model: DirectoryTreeModel
    @Binding var dragged: UUID?
    @Binding var highlighted: Bool
    @Binding var rowTarget: UUID?
    func validateDrop(info: DropInfo) -> Bool { dragged.map { id in model.nodes.contains { $0.id == id } } ?? false }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        highlighted = validateDrop(info: info); rowTarget = nil
        return DropProposal(operation: highlighted ? .move : .forbidden)
    }
    func dropExited(info: DropInfo) { highlighted = false }
    func performDrop(info: DropInfo) -> Bool {
        guard let dragged, validateDrop(info: info) else { return false }
        model.dropToRoot(source: dragged); self.dragged = nil; highlighted = false; rowTarget = nil
        return model.error == nil
    }
}

private extension UTType {
    static let directoryTreeNode = UTType(exportedAs: "local.MyToolBox.directoryTreeNode", conformingTo: .data)
}
