import SwiftUI

private actor JSONWorkspaceWorker {
    func parse(_ text: String) throws -> JSONValue { try JSONWorkspace.parse(text) }
}

@MainActor final class JSONWorkspaceModel: ObservableObject {
    @Published var text = ""
    @Published var root: JSONValue?
    @Published var error: String?
    @Published var selection: [Int] = []
    @Published var pending = false
    private let worker = JSONWorkspaceWorker()
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
                HSplitView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("共有JSON入力").font(.headline)
                            Spacer()
                            Button("貼り付け") { if let s = NSPasteboard.general.string(forType: .string) { model.text = s } }
                            Button("コピー") { copy(model.text) }.disabled(model.text.isEmpty)
                        }
                        TextEditor(text: $model.text).font(.system(size: 12, design: .monospaced)).accessibilityLabel("共有JSON入力")
                            .overlay(Rectangle().stroke(theme.edge.opacity(0.25)))
                        Text("256 KiB・48階層・4,000要素まで。入力は保存・送信しません。")
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
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                else if model.root != nil { Text("有効なJSONです").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(20)
        }.frame(minWidth: 840, idealWidth: 1000, minHeight: 650, idealHeight: 740)
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
